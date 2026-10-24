extends Node3D
class_name RoomOcclusionSystem
## Render-only room masks. Room connectivity follows physical door collision state.

const REVEAL_SECONDS := 0.24

var rooms: Dictionary = {}
var links: Array[Dictionary] = []
var accessible_rooms: Dictionary = {}
var door_states: Dictionary = {}
var current_room_id := ""
var _lights: Array[Dictionary] = []
var _visuals_by_room: Dictionary = {}


func add_room(room_id: String, center: Vector2, size: Vector2) -> void:
	var mask := MeshInstance3D.new()
	mask.name = "UnseenRoomMask_%s" % room_id
	var volume := BoxMesh.new()
	volume.size = Vector3(size.x, 0.08, size.y)
	mask.mesh = volume
	mask.position = Vector3(center.x, 0.11, center.y)
	mask.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mask.layers = 1
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	black.cull_mode = BaseMaterial3D.CULL_DISABLED
	black.albedo_color = Color(0.002, 0.003, 0.004, 1.0)
	mask.material_override = black
	mask.transparency = 0.0
	mask.visible = false
	add_child(mask)
	rooms[room_id] = {
		"center": center,
		"size": size,
		"mask": mask,
		"reachable": true,
		"initialized": false,
	}
	_visuals_by_room[room_id] = []


func connect_rooms(room_a: String, room_b: String, gate_id: String = "", gate_shape: CollisionShape3D = null) -> void:
	links.append({"a": room_a, "b": room_b, "gate_id": gate_id, "shape": gate_shape})


func register_room_light(room_id: String, light: OmniLight3D) -> void:
	if rooms.has(room_id) and is_instance_valid(light):
		_lights.append({"room": room_id, "light": light})


func register_room_visual(room_id: String, visual: GeometryInstance3D) -> void:
	if rooms.has(room_id) and is_instance_valid(visual):
		_visuals_by_room[room_id].append({
			"visual": visual,
			"base_transparency": visual.transparency,
			"reachable": true,
			"initialized": false,
		})


func room_at(world_position: Vector3) -> String:
	var best_id := ""
	var best_area := INF
	for room_id in rooms:
		var room: Dictionary = rooms[room_id]
		var center: Vector2 = room["center"]
		var size: Vector2 = room["size"]
		if absf(world_position.x - center.x) > size.x * 0.5 or absf(world_position.z - center.y) > size.y * 0.5:
			continue
		var area := size.x * size.y
		if area < best_area:
			best_area = area
			best_id = String(room_id)
	return best_id


func refresh(player_position: Vector3, unlocked_gate_ids: Dictionary) -> void:
	var start := room_at(player_position)
	if start.is_empty():
		return
	current_room_id = start
	door_states.clear()
	for link in links:
		var gate_id := String(link["gate_id"])
		if gate_id.is_empty() or door_states.has(gate_id):
			continue
		var shape: CollisionShape3D = link["shape"]
		if shape == null:
			door_states[gate_id] = "OPEN"
		elif shape.disabled:
			door_states[gate_id] = "OPEN"
		elif bool(unlocked_gate_ids.get(gate_id, false)):
			door_states[gate_id] = "CLOSED"
		else:
			door_states[gate_id] = "LOCKED"

	var previous_accessible := accessible_rooms.duplicate()
	accessible_rooms.clear()
	accessible_rooms[start] = true
	var frontier: Array[String] = [start]
	while not frontier.is_empty():
		var current: String = frontier.pop_front()
		for link in links:
			var gate_id := String(link["gate_id"])
			if not gate_id.is_empty() and String(door_states.get(gate_id, "LOCKED")) != "OPEN":
				continue
			var next := ""
			if String(link["a"]) == current:
				next = String(link["b"])
			elif String(link["b"]) == current:
				next = String(link["a"])
			if not next.is_empty() and not accessible_rooms.has(next):
				accessible_rooms[next] = true
				frontier.append(next)

	for room_id in rooms:
		var reachable := accessible_rooms.has(room_id)
		var room: Dictionary = rooms[room_id]
		if not bool(room["initialized"]) or bool(room["reachable"]) != reachable:
			room["reachable"] = reachable
			room["initialized"] = true
			var mask: MeshInstance3D = room["mask"]
			mask.visible = not reachable
		# Carve all currently visible spaces out of the black floor. Overlapping
		# connector bounds must never cover the current room, irrespective of order.
		if not reachable and (not bool(room.get("mask_built", false)) or previous_accessible != accessible_rooms):
			_rebuild_mask(room)
			room["mask_built"] = true
		for visual_record in _visuals_by_room[room_id]:
			var visual: GeometryInstance3D = visual_record["visual"]
			if not is_instance_valid(visual):
				continue
			if not bool(visual_record["initialized"]) or bool(visual_record["reachable"]) != reachable:
				visual_record["reachable"] = reachable
				visual_record["initialized"] = true
				var previous_tween: Tween = visual_record.get("tween")
				if previous_tween != null and previous_tween.is_valid():
					previous_tween.kill()
				var visual_tween := visual.create_tween()
				visual_record["tween"] = visual_tween
				visual_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				var target_alpha := float(visual_record["base_transparency"]) if reachable else 1.0
				visual_tween.tween_property(visual, "transparency", target_alpha, REVEAL_SECONDS)

	for item in _lights:
		var light: OmniLight3D = item["light"]
		if is_instance_valid(light):
			light.visible = accessible_rooms.has(String(item["room"]))


func is_accessible(room_id: String) -> bool:
	return accessible_rooms.has(room_id)


func _rebuild_mask(room: Dictionary) -> void:
	var center: Vector2 = room.center
	var size: Vector2 = room.size
	var bounds := Rect2(center - size * 0.5, size)
	var xs: Array[float] = [bounds.position.x, bounds.end.x]
	var zs: Array[float] = [bounds.position.y, bounds.end.y]
	for id in accessible_rooms:
		var other: Dictionary = rooms[id]
		var rect := Rect2(other.center - other.size * 0.5, other.size)
		var overlap := bounds.intersection(rect)
		if overlap.has_area():
			xs.append(overlap.position.x)
			xs.append(overlap.end.x)
			zs.append(overlap.position.y)
			zs.append(overlap.end.y)
	xs.sort()
	zs.sort()
	var vertices := PackedVector3Array()
	for x in range(xs.size() - 1):
		for z in range(zs.size() - 1):
			var mid := Vector3((xs[x] + xs[x + 1]) * 0.5, 0, (zs[z] + zs[z + 1]) * 0.5)
			if _point_revealed(mid) or xs[x + 1] <= xs[x] or zs[z + 1] <= zs[z]:
				continue
			var a := Vector3(xs[x] - center.x, 0.04, zs[z] - center.y)
			var b := Vector3(xs[x + 1] - center.x, 0.04, zs[z] - center.y)
			var c := Vector3(xs[x + 1] - center.x, 0.04, zs[z + 1] - center.y)
			var d := Vector3(xs[x] - center.x, 0.04, zs[z + 1] - center.y)
			vertices.append_array(PackedVector3Array([a, c, b, a, d, c]))
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	room.mask.mesh = mesh

func _point_revealed(point: Vector3) -> bool:
	for id in accessible_rooms:
		var room: Dictionary = rooms[id]
		if Rect2(room.center - room.size * 0.5, room.size).has_point(Vector2(point.x, point.z)):
			return true
	return false


func get_door_state(gate_id: String) -> String:
	return String(door_states.get(gate_id, "UNKNOWN"))
