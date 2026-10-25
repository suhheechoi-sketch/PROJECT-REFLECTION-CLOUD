extends Node3D
class_name ReflectionLaser

const MAX_DISTANCE := 65.0
const MAX_INTERACTIONS := 8
const MAX_BRANCHES := 24
const EPSILON := 0.035

var segment_nodes: Array[MeshInstance3D] = []
var channel_materials: Dictionary = {}
var last_segment_count: int = 0
var ignore_rids: Array[RID] = []
# Observations are copies of the same physical trace used for rendering/receiver tests.
var _observed_segments: Array[Dictionary] = []
func observation_snapshot() -> Array[Dictionary]:
	return _observed_segments.duplicate(true)

func _record_segment(segments: Array[Dictionary], branch: Dictionary, origin: Vector3, end: Vector3, channel: String, energy: float, reflections: int, collider: Object = null) -> void:
	segments.append({"from":origin,"to":end,"channel":channel,"energy":energy,
		"source_id":branch.get("source_id","player"),"branch_id":branch.get("branch_id","0"),
		"segment_index":segments.size(),"reflection_count":reflections,"did_hit":collider != null,
		"collision_type":collider.kind if collider is OpticalDevice else ("wall" if collider != null else "range_limit"),
		"collider_id":collider.get_instance_id() if collider != null else 0,"terminal":false,
		"path_length":MAX_DISTANCE,"receiver_accepted":false,"receiver_active":false})

func _publish_observations(segments: Array[Dictionary]) -> void:
	var last := {}
	var parents := {}
	for segment in segments:
		var key: String = segment.source_id+":"+segment.branch_id
		last[key] = segment.segment_index
		var branch: String = segment.branch_id
		if branch.contains("/"): parents[segment.source_id+":"+branch.get_base_dir()] = true
		if segment.collision_type == "receiver":
			var receiver = instance_from_id(segment.collider_id)
			if is_instance_valid(receiver):
				segment.receiver_active = receiver.receiver_active
	for segment in segments:
		var key: String = segment.source_id+":"+segment.branch_id
		segment.terminal = not parents.has(key) and last[key] == segment.segment_index
	_observed_segments = segments



func _ready() -> void:
	for channel in ["white", "red", "green", "blue"]:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = OpticalDevice.CHANNEL_COLORS[channel]
		material.emission_enabled = true
		material.emission = OpticalDevice.CHANNEL_COLORS[channel]
		material.emission_energy_multiplier = 2.4
		channel_materials[channel] = material


func update_beam(start: Vector3, target: Vector3, firing: bool, delta: float, channel: String = "red", additional_sources: Array[Dictionary] = []) -> void:
	var devices: Array = get_tree().get_nodes_in_group("optical_devices")
	for device in devices:
		if device is OpticalDevice:
			device.begin_laser_frame()
	var segments: Array[Dictionary] = []
	if firing:
		var direction := target - start
		direction.y = 0.0
		if direction.length_squared() > 0.0001:
			_trace(start, direction.normalized(), channel, 1.0, segments, "player")
	for source_index in range(additional_sources.size()):
		var source: Dictionary = additional_sources[source_index]
		if not bool(source.get("active", false)):
			continue
		_trace(source["origin"], source["direction"], String(source.get("channel", "white")), float(source.get("energy", 1.0)), segments, str(source.get("source_id", "source-%d" % source_index)))
	for device in devices:
		if device is OpticalDevice:
			device.update_receiver(delta)
	_update_simultaneous_receivers(devices, delta)
	_publish_observations(segments)
	_render_segments(segments)


func _update_simultaneous_receivers(devices: Array, delta: float) -> void:
	var groups: Dictionary = {}
	for item in devices:
		if not item is OpticalDevice:
			continue
		var device := item as OpticalDevice
		if device.kind != "receiver" or device.simultaneous_group.is_empty():
			continue
		if not groups.has(device.simultaneous_group):
			groups[device.simultaneous_group] = []
		(groups[device.simultaneous_group] as Array).append(device)
	for group_value in groups.values():
		var members: Array = group_value
		if members.size() < 2:
			continue
		var all_hit := true
		var required_seconds := 0.0
		var progress := (members[0] as OpticalDevice).receiver_progress
		for item in members:
			var device := item as OpticalDevice
			all_hit = all_hit and device._hit_this_frame
			required_seconds = maxf(required_seconds, device.required_seconds)
		progress = minf(required_seconds, progress + delta) if all_hit else 0.0
		for item in members:
			(item as OpticalDevice).receiver_progress = progress
		if all_hit and progress >= required_seconds:
			for item in members:
				(item as OpticalDevice).activate_receiver()


func _trace(start: Vector3, direction: Vector3, channel: String, energy: float, segments: Array[Dictionary], source_id := "player") -> void:
	var pending: Array[Dictionary] = [{
		"source_id":source_id,"branch_id":"0",
		"origin": start,
		"direction": direction.normalized(),
		"channel": channel,
		"energy": energy,
		"inside_id": 0,
		"remaining": MAX_DISTANCE,
		"interactions": 0,
		"reflections": 0
	}]
	var processed := 0
	while not pending.is_empty() and processed < MAX_BRANCHES:
		processed += 1
		var branch: Dictionary = pending.pop_front()
		var origin: Vector3 = branch["origin"]
		var ray_direction: Vector3 = branch["direction"].normalized()
		var ray_channel: String = branch["channel"]
		var ray_energy: float = branch["energy"]
		var inside_id: int = branch["inside_id"]
		var remaining: float = float(branch.get("remaining", MAX_DISTANCE))
		var interactions: int = int(branch.get("interactions", 0))
		var reflections: int = int(branch.get("reflections", 0))
		var excluded: Array[RID] = []
		var skip_once: Array[RID] = []
		if branch.has("skip_once"):
			for skip_rid in branch["skip_once"]:
				skip_once.append(skip_rid)
		while remaining > 0.05 and interactions < MAX_INTERACTIONS:
			var hit: Dictionary = {}
			var collider: Object
			if inside_id != 0:
				var inside_object: Object = instance_from_id(inside_id)
				if inside_object is OpticalDevice:
					var interior_device := inside_object as OpticalDevice
					hit = interior_device.find_exit_surface(origin, ray_direction)
					if hit.is_empty():
						break
					collider = interior_device
				else:
					inside_id = 0
			if inside_id == 0:
				var query := PhysicsRayQueryParameters3D.create(origin, origin + ray_direction * remaining, 7)
				# A shoulder-mounted emitter can overlap a wall by a few centimetres.
				# Treat that wall as a hit instead of allowing a ray to escape its interior.
				query.hit_from_inside = true
				query.exclude = ignore_rids + excluded + skip_once
				skip_once.clear()
				query.collide_with_areas = false
				hit = get_world_3d().direct_space_state.intersect_ray(query)
				if hit.is_empty():
					_record_segment(segments, branch, origin, origin + ray_direction * remaining, ray_channel, ray_energy, reflections)
					break
				collider = hit["collider"]
			var hit_position: Vector3 = hit["position"]
			var normal: Vector3 = hit["normal"].normalized()
			var traveled := origin.distance_to(hit_position)
			if traveled > remaining:
				_record_segment(segments, branch, origin, origin + ray_direction * remaining, ray_channel, ray_energy, reflections)
				break
			remaining -= traveled
			_record_segment(segments, branch, origin, hit_position, ray_channel, ray_energy, reflections, collider)
			segments.back().path_length = MAX_DISTANCE-remaining
			interactions += 1
			if not (collider is OpticalDevice):
				break
			var device := collider as OpticalDevice
			if device.kind == "receiver":
				segments.back().receiver_accepted = device.receive_laser(ray_channel, ray_energy, ray_direction, reflections)
				break
			if device.kind == "white_source":
				if not device.source_active:
					device.source_active = true
					device._refresh_visual()
					device.source_activated.emit(device)
				break
			if device.kind == "shutter":
				if device.is_shutter_open():
					excluded.append(device.get_rid())
					origin = hit_position + ray_direction * EPSILON
					remaining -= EPSILON
					continue
				break
			if device.kind == "mirror":
				reflections += 1
				ray_direction = OpticalMath.reflect(ray_direction, normal)
				origin = hit_position + ray_direction * EPSILON
				skip_once.append(device.get_rid())
				continue
			if device.kind == "splitter":
				var transmitted_energy: float = ray_energy * 0.5
				var reflected_energy: float = ray_energy * 0.5
				if transmitted_energy >= 0.04:
					pending.append({"source_id":source_id,"branch_id":str(branch.branch_id)+"/T","origin": hit_position + ray_direction * EPSILON, "direction": ray_direction, "channel": ray_channel, "energy": transmitted_energy, "inside_id": 0, "remaining": maxf(0.0, remaining - EPSILON), "interactions": interactions, "reflections": reflections, "skip_once": [device.get_rid()]})
				if reflected_energy >= 0.04:
					var reflected := OpticalMath.reflect(ray_direction, normal)
					pending.append({"source_id":source_id,"branch_id":str(branch.branch_id)+"/R","origin": hit_position + reflected * EPSILON, "direction": reflected, "channel": ray_channel, "energy": reflected_energy, "inside_id": 0, "remaining": maxf(0.0, remaining - EPSILON), "interactions": interactions, "reflections": reflections + 1, "skip_once": [device.get_rid()]})
				break
			if device.kind in ["medium", "wedge_medium", "prism"]:
				var device_id := device.get_instance_id()
				var entering := inside_id != device_id
				if entering and device.kind in ["medium", "wedge_medium"]:
					device.amplifier_input_energy = ray_energy
					ray_energy = minf(3.0, ray_energy * device.amplification)
				if not entering:
					var exiting_direction := OpticalMath.refract(ray_direction, normal, device.get_refractive_index(ray_channel), 1.0)
					if exiting_direction.length_squared() < 0.0001:
						ray_direction = OpticalMath.reflect(ray_direction, normal)
					else:
						ray_direction = exiting_direction
						inside_id = 0
					origin = hit_position + ray_direction * EPSILON
					continue
				if device.kind == "prism" and entering and ray_channel == "white":
					for spectral_channel in ["red", "green", "blue"]:
						var spectral_direction := OpticalMath.refract(ray_direction, normal, 1.0, device.get_refractive_index(spectral_channel))
						if spectral_direction.length_squared() > 0.0:
							pending.append({"source_id":source_id,"branch_id":str(branch.branch_id)+"/"+spectral_channel,"origin": hit_position + spectral_direction * EPSILON, "direction": spectral_direction, "channel": spectral_channel, "energy": ray_energy / 3.0, "inside_id": device_id, "remaining": maxf(0.0, remaining - EPSILON), "interactions": interactions, "reflections": reflections})
					break
				var refracted := OpticalMath.refract(ray_direction, normal, 1.0, device.get_refractive_index(ray_channel))
				if refracted.length_squared() < 0.0001:
					ray_direction = OpticalMath.reflect(ray_direction, normal)
				else:
					ray_direction = refracted.normalized()
					inside_id = device_id
				origin = hit_position + ray_direction * EPSILON
				continue
		# Finish this physical segment, then drain any split/spectral branches.
func _render_segments(segments: Array[Dictionary]) -> void:
	while segment_nodes.size() < segments.size():
		var visual := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.025
		cylinder.bottom_radius = 0.025
		cylinder.radial_segments = 5
		visual.mesh = cylinder
		if has_meta("observer_layers"): visual.layers = 1 << 18
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(visual)
		segment_nodes.append(visual)
	for index in range(segment_nodes.size()):
		var visual := segment_nodes[index]
		if index >= segments.size():
			visual.visible = false
			continue
		var segment: Dictionary = segments[index]
		var from: Vector3 = segment["from"]
		var to: Vector3 = segment["to"]
		var offset := to - from
		if offset.length_squared() < 0.000001:
			visual.visible = false
			continue
		var cylinder := visual.mesh as CylinderMesh
		cylinder.height = maxf(offset.length(), 0.01)
		visual.global_position = (from + to) * 0.5
		visual.quaternion = Quaternion(Vector3.UP, offset.normalized())
		visual.material_override = channel_materials.get(segment["channel"], channel_materials["white"])
		visual.visible = float(segment["energy"]) > 0.03
	last_segment_count = segments.size()

