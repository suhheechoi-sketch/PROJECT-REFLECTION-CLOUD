extends Node3D
## RF-FAC v4.0: modular industrial dressing, no optical collision surfaces.

const Shapes = preload("res://assets/v4_0/device_visuals.gd")
const Finish = preload("res://assets/v4_0/surface_finish.gd")
var palette: Dictionary = {}
var circuit_lamps: Dictionary = {}
var rotor: Node3D
var pickup: Node3D
var main_lamp: OmniLight3D
var camera_led: MeshInstance3D
var _time := 0.0
var _powered := false


func build() -> void:
	name = "FacilityArt_v4_0"
	for key in {"steel": "485552", "dark": "192625", "concrete": "69716a", "amber": "d69a43", "rust": "754733", "cyan": "55b7b0", "red": "c45442", "paper": "c3c3a0"}:
		var colors := {"steel": "485552", "dark": "192625", "concrete": "69716a", "amber": "d69a43", "rust": "754733", "cyan": "55b7b0", "red": "c45442", "paper": "c3c3a0"}
		palette[key] = Shapes.material(Color(colors[key]), 0.65 if key in ["cyan", "red"] else 0.0)
	for key in ["steel", "dark", "rust", "concrete"]:
		(palette[key] as StandardMaterial3D).albedo_texture = Finish.texture(407, true)
		(palette[key] as StandardMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_build_tiles(Vector2(-22, -18.5), Vector2(14, 17), "steel")
	_build_tiles(Vector2(-22, -0.5), Vector2(14, 7), "rust")
	_build_tiles(Vector2(-7, -6.5), Vector2(14, 13), "steel")
	_isolation()
	_training()
	_lobby()
	_hub()


func _box(size: Vector3, at: Vector3, key: String) -> MeshInstance3D:
	return Shapes.box(self, size, at, palette[key])


func _solid(size: Vector3, at: Vector3, key: String) -> void:
	_box(size, at, key)
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	add_child(body)


func _sign(text_value: String, at: Vector3, color_key: String = "paper", font_size: int = 36) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = at
	label.font_size = font_size
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = (palette[color_key] as StandardMaterial3D).albedo_color
	label.outline_size = 6
	add_child(label)


func _floor_text(text_value: String, at: Vector3, color_key: String = "paper", font_size: int = 42) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = at
	label.rotation_degrees.x = -90
	label.font_size = font_size
	label.pixel_size = 0.012
	label.modulate = (palette[color_key] as StandardMaterial3D).albedo_color
	add_child(label)


func _build_tiles(origin: Vector2, extent: Vector2, key: String) -> void:
	for x in range(int(extent.x / 2)):
		for z in range(int(extent.y / 2)):
			var at := Vector3(origin.x + x * 2 + 1, 0.085, origin.y + z * 2 + 1)
			_box(Vector3(1.97, 0.025, 1.97), at, key if (x + z) % 5 else "dark")


func _strip(from: Vector3, to: Vector3, key: String, width: float = 0.08) -> void:
	var line := _box(Vector3(width, 0.026, from.distance_to(to)), (from + to) / 2, key)
	line.rotation.y = atan2((to - from).x, (to - from).z)


func _rack(at: Vector3) -> void:
	_solid(Vector3(1.2, 1.8, 0.65), at + Vector3(0, 0.9, 0), "dark")
	for index in range(5):
		_box(Vector3(1.0, 0.06, 0.05), at + Vector3(0, 0.35 + index * 0.28, 0.35), "steel")
		_box(Vector3(0.08, 0.07, 0.06), at + Vector3(-0.4, 0.48 + index * 0.28, 0.35), "cyan")


func _portal(at: Vector3, along_x: bool = false) -> void:
	var portal := Node3D.new()
	portal.position = at
	portal.rotation.y = PI / 2 if along_x else 0.0
	add_child(portal)
	for side in [-1.0, 1.0]:
		Shapes.box(portal, Vector3(0.22, 2.9, 0.65), Vector3(side * 1.9, 1.45, 0), palette["dark"])
		Shapes.box(portal, Vector3(0.07, 2.4, 0.08), Vector3(side * 1.78, 1.45, 0.35), palette["cyan"])
	Shapes.box(portal, Vector3(4.0, 0.2, 0.65), Vector3(0, 2.95, 0), palette["steel"])


func _isolation() -> void:
	# Human scale landmarks: 2.0m bunk, 1.2m console, wall-fixed equipment.
	_solid(Vector3(1.05, 0.55, 2.0), Vector3(-21.3, 0.3, -17.2), "dark")
	_box(Vector3(0.95, 0.15, 1.9), Vector3(-21.3, 0.58, -17.2), "concrete")
	_box(Vector3(0.8, 0.13, 0.4), Vector3(-21.3, 0.72, -17.8), "paper")
	_solid(Vector3(0.12, 2.2, 3), Vector3(-19.75, 1.1, -17.3), "steel")
	_solid(Vector3(0.12, 2.2, 2.0), Vector3(-19.75, 1.1, -12), "steel")
	_sign("07 / OBSERVATION\n격리실 · 생체 반응 정상", Vector3(-21, 1.65, -18.7), "cyan", 24)
	_box(Vector3(0.72, 0.45, 0.08), Vector3(-18.6, 1.55, -15.36), "dark")
	_sign("E  신원 확인", Vector3(-18.6, 1.95, -15), "cyan", 25)
	# Pick-up is a separate action after the identification console.
	pickup = Node3D.new()
	pickup.position = Vector3(-18.6, 0, -17.4)
	add_child(pickup)
	Shapes.box(pickup, Vector3(0.9, 1.0, 0.6), Vector3(0, 0.5, 0), palette["dark"])
	Shapes.box(pickup, Vector3(0.18, 0.18, 0.6), Vector3(0, 1.15, 0), palette["cyan"])
	_sign("L-07 / 휴대 광원\nE  지급 장치", Vector3(-18.6, 2.0, -17.4), "amber", 26)
	_floor_text("07", Vector3(-21, 0.13, -15.1), "paper", 66)
	_strip(Vector3(-20.8, 0.13, -14), Vector3(-17, 0.13, -14), "cyan")
	_box(Vector3(0.55, 0.25, 0.8), Vector3(-22, 2.45, -18.3), "dark")
	camera_led = _box(Vector3(0.09, 0.09, 0.08), Vector3(-22, 2.4, -17.85), "red")
	_sign("REC ●", Vector3(-22, 2.85, -18.4), "red", 18)


func _training() -> void:
	_portal(Vector3(-15, 0, -9.2))
	_portal(Vector3(-15, 0, -1))
	_floor_text("02 / EMISSION", Vector3(-15.5, 0.13, -17.4), "cyan", 30)
	_floor_text("03 / REFLECTION", Vector3(-12, 0.13, -13.8), "amber", 27)
	_floor_text("04 / DOUBLE BOUNCE", Vector3(-15, 0.13, -5.5), "amber", 28)
	for z in [-16.0, -6.0]:
		_box(Vector3(0.1, 0.16, 2.0), Vector3(-22.15, 2.25, z), "cyan")
		_box(Vector3(0.18, 0.18, 2.4), Vector3(-22.25, 2.25, z), "dark")
	_rack(Vector3(-8.5, 0, -17.9))
	_rack(Vector3(-8.5, 0, -3.0))
	for x in [-21.5, -8.5]:
		_strip(Vector3(x, 0.13, -8.5), Vector3(x, 0.13, -1.6), "amber", 0.12)


func _lobby() -> void:
	_portal(Vector3(-7.5, 0, 0), true)
	_floor_text("A / MIRROR ARRAY", Vector3(-15, 0.14, 0.3), "amber", 34)
	_floor_text("H  →", Vector3(-10, 0.14, 0), "cyan", 42)
	_floor_text("01  →  02  →  R", Vector3(-16, 0.14, 6.3), "paper", 24)
	_rack(Vector3(-21.5, 0, 5.8))
	_box(Vector3(1.8, 0.75, 0.8), Vector3(-21, 0.48, 2), "dark")
	_sign("A-01 / 우회 광로\n반사 2회 · 방향 → · 1.2초", Vector3(-17.8, 2.3, 3.8), "amber", 27)
	for x in range(6):
		var stripe := _box(Vector3(0.12, 0.03, 0.45), Vector3(-15 + x * 0.3, 0.14, 3.6), "amber")
		stripe.rotation.y = -PI / 4
	_strip(Vector3(-20, 0.14, 1.0), Vector3(-9, 0.14, 1.0), "amber")


func _hub() -> void:
	_portal(Vector3(7.5, 0, 0), true)
	_portal(Vector3(0, 0, 7))
	_portal(Vector3(3, 0, -7))
	_floor_text("H / CENTRAL DISTRIBUTION", Vector3(0, 0.14, -4.8), "paper", 32)
	_floor_text("← A", Vector3(-5.3, 0.14, 0), "amber", 38)
	_floor_text("B →", Vector3(5.5, 0.14, 0), "cyan", 38)
	_floor_text("C ↓", Vector3(0, 0.14, 5.3), "amber", 38)
	for index in range(3):
		var id: String = ["A", "B", "C"][index]
		var x := -1.4 + index * 1.4
		_box(Vector3(1.1, 0.4, 1.1), Vector3(x, 0.32, -2.5), "dark")
		circuit_lamps[id] = Shapes.ring(self, 0.42, 0.09, Vector3(x, 0.6, -2.5), palette["red"])
		_sign(id, Vector3(x, 1.0, -2.5), "paper", 32)
	Shapes.cylinder(self, 1.15, 0.45, Vector3(0, 0.35, 1), palette["dark"])
	Shapes.ring(self, 1.3, 0.08, Vector3(0, 0.7, 1), palette["amber"])
	rotor = Node3D.new()
	rotor.position = Vector3(0, 0.65, 1)
	add_child(rotor)
	for angle in range(6):
		var blade := Shapes.box(rotor, Vector3(0.23, 0.12, 1.9), Vector3.ZERO, palette["steel"])
		blade.rotation.y = angle * PI / 3
	for z in [-5.8, 5.8]:
		for x in [-5.8, 5.8]:
			_box(Vector3(0.45, 2.7, 0.45), Vector3(x, 1.35, z), "dark")
			_box(Vector3(0.08, 1.8, 0.08), Vector3(x - 0.25, 1.6, z), "cyan")
	for x in [-5.0, 5.0]:
		_strip(Vector3(x, 0.13, -5.8), Vector3(x, 0.13, 5.8), "cyan", 0.06)
	_rack(Vector3(-5.9, 0, -4.7))
	_rack(Vector3(5.9, 0, -4.7))
	main_lamp = OmniLight3D.new()
	main_lamp.position = Vector3(0, 2.5, 1)
	main_lamp.omni_range = 7
	main_lamp.light_color = Color("55b7b0")
	main_lamp.light_energy = 0.15
	add_child(main_lamp)


func update_power(circuits: Array[String], acquired: bool) -> void:
	_powered = not circuits.is_empty()
	for id in circuit_lamps:
		(circuit_lamps[id] as MeshInstance3D).material_override = palette["cyan"] if circuits.has(id) else palette["red"]
	main_lamp.light_energy = 0.15 + circuits.size() * 0.45
	# Keep the rack, remove the portable unit from the rack after collection.
	if pickup != null:
		(pickup.get_child(1) as Node3D).visible = not acquired


func _process(delta: float) -> void:
	_time += delta
	if _powered:
		rotor.rotate_y(delta * 0.6)
	if camera_led != null:
		camera_led.visible = fmod(_time, 2.0) < 1.7
