extends AnimatableBody3D
class_name OpticalDevice

signal receiver_activated(device: OpticalDevice)
signal source_activated(device: OpticalDevice)

const CHANNEL_COLORS := {
	"white": Color(1.0, 0.96, 0.78),
	"red": Color(1.0, 0.12, 0.08),
	"green": Color(0.18, 1.0, 0.3),
	"blue": Color(0.18, 0.48, 1.0)
}

var kind: String = "mirror"
var display_name: String = "광학 장치"
var receiver_color: String = "white"
var required_seconds: float = 0.25
var minimum_energy: float = 0.1
var minimum_reflections: int = 0
var required_direction: Vector3 = Vector3.ZERO
var minimum_direction_dot: float = 0.94
var simultaneous_group: String = ""
var refractive_indices: Dictionary = {"white": 1.48, "red": 1.46, "green": 1.49, "blue": 1.53}
var optical_size: Vector3 = Vector3.ONE
var initial_rotation_y: float = 0.0
var amplification: float = 1.0
var rotatable: bool = true
var amplifier_input_energy: float = 1.0
var shutter_speed: float = 1.8
var shutter_running: bool = true
var receiver_progress: float = 0.0
var receiver_active: bool = false
var source_active: bool = false
var receiver_enabled: bool = true
var _hit_this_frame: bool = false
var _base_material: Material
var _selected_material: Material
var _targeted_material: Material
var _active_material: Material
var _white_source_active_material: Material
var visual: MeshInstance3D
var marker: MeshInstance3D
var state_ring: MeshInstance3D
var type_mark: Label3D
var is_selected: bool = false
var is_targeted: bool = false


func configure(device_kind: String, label: String, base_color: Color) -> void:
	kind = device_kind
	display_name = label
	# Rotation is synchronized explicitly after input so the ray collider matches the mesh.
	sync_to_physics = false
	collision_layer = 2
	collision_mask = 0
	add_to_group("optical_devices")
	var material := StandardMaterial3D.new()
	material.albedo_color = base_color
	material.metallic = 0.65 if kind in ["mirror", "splitter", "shutter"] else 0.18
	material.roughness = 0.32 if kind == "mirror" else 0.72
	if kind in ["medium", "wedge_medium", "prism"]:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var tinted_color := base_color
		tinted_color.a = 0.38 if kind in ["medium", "wedge_medium"] else 0.62
		material.albedo_color = tinted_color
	material.emission_enabled = true
	material.emission = base_color * 0.2
	material.emission_energy_multiplier = 0.65
	_base_material = material
	var selected := StandardMaterial3D.new()
	var selected_color := base_color.lightened(0.42)
	if kind in ["medium", "wedge_medium", "prism"]:
		selected.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		selected_color.a = 0.7
	selected.albedo_color = selected_color
	selected.emission_enabled = true
	selected.emission = base_color
	selected.emission_energy_multiplier = 1.4
	_selected_material = selected
	var targeted := selected.duplicate() as StandardMaterial3D
	targeted.albedo_color = base_color.lightened(0.28)
	targeted.emission_enabled = true
	targeted.emission = base_color.lightened(0.32)
	targeted.emission_energy_multiplier = 1.8
	_targeted_material = targeted
	var active := StandardMaterial3D.new()
	active.albedo_color = Color(0.35, 1.0, 0.52)
	active.emission_enabled = true
	active.emission = Color(0.24, 1.0, 0.35)
	active.emission_energy_multiplier = 2.2
	active.roughness = 0.35
	_active_material = active
	var white_active := StandardMaterial3D.new()
	white_active.albedo_color = Color(1.0, 0.91, 0.66)
	white_active.emission_enabled = true
	white_active.emission = Color(1.0, 0.93, 0.72)
	white_active.emission_energy_multiplier = 2.0
	white_active.roughness = 0.35
	_white_source_active_material = white_active


func set_visual(mesh_instance: MeshInstance3D) -> void:
	visual = mesh_instance
	_refresh_visual()


func set_marker(mesh_instance: MeshInstance3D) -> void:
	marker = mesh_instance
	_refresh_visual()


func set_selected(is_selected: bool) -> void:
	self.is_selected = is_selected
	_refresh_visual()


func set_targeted(targeted: bool) -> void:
	is_targeted = targeted
	_refresh_visual()


func _refresh_visual() -> void:
	var material: Material = _base_material
	if kind == "white_source" and source_active:
		material = _white_source_active_material
	elif kind == "receiver" and receiver_active:
		material = _active_material
	elif is_selected:
		material = _selected_material
	elif is_targeted:
		material = _targeted_material
	if visual != null:
		visual.material_override = material
	if marker != null:
		var marker_material: Material = _base_material
		if kind == "receiver" and receiver_active:
			marker_material = _active_material
		elif is_selected or is_targeted:
			marker_material = _targeted_material
		marker.material_override = marker_material
	if state_ring != null:
		state_ring.material_override = _active_material if receiver_active else (_targeted_material if is_targeted or is_selected else _base_material)
	if type_mark != null:
		var code: String = {"red": "R", "green": "G", "blue": "B"}.get(receiver_color, "R")
		if minimum_reflections > 0:
			code += " / %d↗" % minimum_reflections
		elif not required_direction.is_zero_approx():
			code += " →"
		type_mark.text = code


func rotate_steps(steps: int) -> void:
	if not rotatable:
		return
	rotation.y = wrapf(rotation.y + deg_to_rad(15.0 * float(steps)), 0.0, TAU)
	_sync_physics_transform()


func rotate_fine_steps(steps: int) -> void:
	if not rotatable:
		return
	rotation.y = wrapf(rotation.y + deg_to_rad(float(steps)), 0.0, TAU)
	_sync_physics_transform()


func reset_device() -> void:
	rotation = Vector3(rotation.x, initial_rotation_y, rotation.z)
	_sync_physics_transform()
	shutter_running = true
	receiver_progress = 0.0
	receiver_active = false
	source_active = false
	_refresh_visual()


func find_exit_surface(world_origin: Vector3, world_direction: Vector3) -> Dictionary:
	var local_origin := to_local(world_origin)
	var local_direction := global_basis.inverse() * world_direction
	var nearest_distance := INF
	var local_normal := Vector3.ZERO
	if kind == "medium":
		var center := Vector3(0.0, optical_size.y * 0.5, 0.0)
		var point := local_origin - center
		var half_size := optical_size * 0.5
		for axis in [0, 2]:
			var component: float = local_direction[axis]
			if absf(component) < 0.00001:
				continue
			var face: float = half_size[axis] if component > 0.0 else -half_size[axis]
			var distance := (face - point[axis]) / component
			if distance > 0.001 and distance < nearest_distance:
				nearest_distance = distance
				local_normal = Vector3.ZERO
				local_normal[axis] = 1.0 if component > 0.0 else -1.0
	elif kind in ["wedge_medium", "prism"]:
		var point_2d := Vector2(local_origin.x, local_origin.z)
		var direction_2d := Vector2(local_direction.x, local_direction.z)
		var vertices: Array[Vector2]
		if kind == "wedge_medium":
			vertices = [
				Vector2(-optical_size.x * 0.5, -optical_size.z * 0.5),
				Vector2(optical_size.x * 0.5, -optical_size.z * 0.5),
				Vector2(optical_size.x * 0.5, optical_size.z * 0.5),
				Vector2(-optical_size.x * 0.07, optical_size.z * 0.5)
			]
		else:
			vertices = [
				Vector2(-optical_size.x * 0.5, -optical_size.z * 0.5),
				Vector2(optical_size.x * 0.5, -optical_size.z * 0.5),
				Vector2(0.0, optical_size.z * 0.5)
			]
		for index in range(vertices.size()):
			var edge_start: Vector2 = vertices[index]
			var edge: Vector2 = vertices[(index + 1) % vertices.size()] - edge_start
			var denominator := direction_2d.cross(edge)
			if absf(denominator) < 0.00001:
				continue
			var offset := edge_start - point_2d
			var distance := offset.cross(edge) / denominator
			var edge_weight := offset.cross(direction_2d) / denominator
			if distance > 0.001 and edge_weight >= -0.0001 and edge_weight <= 1.0001 and distance < nearest_distance:
				nearest_distance = distance
				var edge_normal := Vector2(edge.y, -edge.x).normalized()
				local_normal = Vector3(edge_normal.x, 0.0, edge_normal.y)
	if nearest_distance == INF:
		return {}
	var local_exit := local_origin + local_direction * nearest_distance
	return {
		"position": to_global(local_exit),
		"normal": (global_basis * local_normal).normalized(),
		"distance": nearest_distance
	}


func interact() -> String:
	match kind:
		"white_source":
			return "%s: %s" % [display_name, "백색광 출력 중" if source_active else "단색 광선을 받아 출력 대기"]
		"shutter":
			return "%s: 자동 회전 중 · 제어 수신기만 정지할 수 있습니다." % display_name
		"receiver":
			return "%s: %s" % [display_name, "수신 완료" if receiver_active else "대기 중"]
		_:
			return "%s 선택됨 · 휠로 회전" % display_name


func is_shutter_open() -> bool:
	return not shutter_running or abs(cos(rotation.y)) < 0.22


func get_refractive_index(channel: String) -> float:
	return float(refractive_indices.get(channel, refractive_indices.get("white", 1.48)))


func begin_laser_frame() -> void:
	_hit_this_frame = false


func receive_laser(channel: String, energy: float, incoming_direction: Vector3, reflections: int = 0) -> void:
	if kind != "receiver" or not receiver_enabled or energy < minimum_energy:
		return
	if reflections < minimum_reflections:
		return
	if receiver_color != "white" and receiver_color != channel:
		return
	if required_direction.length_squared() > 0.0001 and incoming_direction.normalized().dot(required_direction.normalized()) < minimum_direction_dot:
		return
	_hit_this_frame = true


func update_receiver(delta: float) -> void:
	if kind != "receiver":
		return
	if not simultaneous_group.is_empty():
		return
	if _hit_this_frame:
		receiver_progress = minf(required_seconds, receiver_progress + delta)
	else:
		receiver_progress = maxf(0.0, receiver_progress - delta * 2.0)
	if not receiver_active and receiver_progress >= required_seconds:
		activate_receiver()


func activate_receiver() -> void:
	if kind != "receiver" or receiver_active:
		return
	receiver_active = true
	_refresh_visual()
	receiver_activated.emit(self)


func get_status_text() -> String:
	if kind != "receiver":
		if kind == "white_source":
			return "%s · %s" % [display_name, "출력 중" if source_active else "대기 중"]
		if kind == "shutter":
			return "%s · %s" % [display_name, "정지" if not shutter_running else "회전 중"]
		if kind in ["medium", "wedge_medium"]:
			return "%s · 고정 배율 ×%.1f" % [display_name, amplification]
		return display_name
	if receiver_active:
		return "%s · 활성" % display_name
	return "%s · %d%%" % [display_name, int((receiver_progress / maxf(required_seconds, 0.01)) * 100.0)]


func get_function_text() -> String:
	match kind:
		"white_source":
			return "고정 설치형 백색광원 · 입력을 받으면 정해진 방향으로 출력\nE: 상태 확인"
		"mirror":
			return "금속 반사면 · 입사각 = 반사각\n%s" % ("E 선택 / 휠 15° · Shift+휠 1°" if rotatable else "고정식")
		"medium", "wedge_medium":
			var geometry_hint := " · 경사 출사" if kind == "wedge_medium" else " · 평행 출사"
			return "굴절·증폭 코어 · %.0f%% → 최대 %.0f%%%s\n통과 시 자동 작동%s" % [amplifier_input_energy * 100.0, minf(300.0, amplifier_input_energy * amplification * 100.0), geometry_hint, " · E / 휠 15° · Shift+휠 1°" if rotatable else " · 고정식"]
		"prism":
			return "삼각 분산체 · 백색광 → RGB\n채널마다 입력 광량의 1/3 · E / 휠 15° · Shift+휠 1°"
		"splitter":
			return "고정 50:50 분기판 · 투과 50%% / 반사 50%%\nE 선택 / 휠 15° · Shift+휠 1°"
		"shutter":
			return "자동 회전 차단막 · 직접 조작 불가\n제어 수신기를 활성화하면 정지"
		"receiver":
			var wavelength: String = {"white": "전체", "red": "적색", "green": "녹색", "blue": "청색"}.get(receiver_color, receiver_color)
			var direction_hint := " · 지정 방향" if not required_direction.is_zero_approx() else ""
			return "%s · 최소 %d%% · %.2f초 · 반사 %d회 이상%s" % [wavelength, int(minimum_energy * 100), required_seconds, minimum_reflections, direction_hint]
	return "광학 장치"


func _physics_process(delta: float) -> void:
	if kind == "shutter" and shutter_running:
		rotate_y(shutter_speed * delta)
		_sync_physics_transform()


func _sync_physics_transform() -> void:
	force_update_transform()
	if is_inside_tree() and get_rid().is_valid():
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform)

