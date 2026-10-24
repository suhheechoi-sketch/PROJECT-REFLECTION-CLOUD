extends "res://assets/v4_0/facility_visuals.gd"
## RF-FAC v5.1: room marks and hub portals aligned to the expanded facility plan.


func build() -> void:
	super.build()
	name = "FacilityArt_v5_1"
	_zone_visuals()


func _build_tiles(_origin: Vector2, _extent: Vector2, _key: String) -> void:
	# The expanded floor is already one continuous slab; per-zone marks are cheaper and clearer.
	pass


func _lobby() -> void:
	_portal(Vector3(-19, 0, 0), true)
	_floor_text("A / ENTRY LOBBY", Vector3(-25.5, 0.14, 1.2), "amber", 30)
	_floor_text("MIRROR ARRAY  /  A-01", Vector3(-51.5, 0.14, 12.0), "paper", 30)
	_sign("A-01  /  MIRROR RELAY\nTWO REFLECTIONS · HOLD 1.2 s", Vector3(-54.0, 2.5, 15.2), "amber", 25)
	_rack(Vector3(-27.0, 0, 4.3))
	_strip(Vector3(-28.5, 0.14, 0.0), Vector3(-20.5, 0.14, 0.0), "amber", 0.12)
	for x in [-69.0, -34.5]:
		_strip(Vector3(x, 0.14, 10.0), Vector3(x, 0.14, 25.0), "amber", 0.1)


func _hub() -> void:
	_portal(Vector3(-10, 0, 0), true)
	_portal(Vector3(19, 0, 0), true)
	_portal(Vector3(0, 0, 17))
	_portal(Vector3(0, 0, -17))
	_portal(Vector3(19, 0, -13), true)
	_floor_text("H / CENTRAL DISTRIBUTION", Vector3(0, 0.14, -3.8), "paper", 32)
	_floor_text("A   MIRROR", Vector3(-12.5, 0.14, 0), "amber", 25)
	_floor_text("B   SPECTRUM", Vector3(11.5, 0.14, 0), "cyan", 25)
	_floor_text("C   POWER", Vector3(0, 0.14, 12.0), "amber", 25)
	_floor_text("D   ARCHIVE", Vector3(0, 0.14, -13.5), "paper", 22)
	for index in range(3):
		var id: String = ["A", "B", "C"][index]
		var x := -1.6 + index * 1.6
		_box(Vector3(1.1, 0.4, 1.1), Vector3(x, 0.32, -1.6), "dark")
		circuit_lamps[id] = Shapes.ring(self, 0.42, 0.09, Vector3(x, 0.6, -1.6), palette["red"])
		_sign(id, Vector3(x, 1.0, -1.6), "paper", 30)
	Shapes.cylinder(self, 1.0, 0.42, Vector3(0, 0.35, 2.3), palette["dark"])
	Shapes.ring(self, 1.12, 0.08, Vector3(0, 0.7, 2.3), palette["amber"])
	rotor = Node3D.new()
	rotor.position = Vector3(0, 0.68, 2.3)
	add_child(rotor)
	for angle in range(6):
		var blade := Shapes.box(rotor, Vector3(0.22, 0.12, 1.6), Vector3.ZERO, palette["steel"])
		blade.rotation.y = angle * PI / 3.0
	for corner in [Vector2(-16, -13), Vector2(16, -13), Vector2(-16, 13), Vector2(16, 13)]:
		_box(Vector3(0.4, 2.6, 0.4), Vector3(corner.x, 1.3, corner.y), "dark")
		_box(Vector3(0.07, 1.6, 0.07), Vector3(corner.x - 0.23, 1.55, corner.y), "cyan")
	main_lamp = OmniLight3D.new()
	main_lamp.position = Vector3(0, 2.5, 2.3)
	main_lamp.omni_range = 11.0
	main_lamp.light_color = Color("55b7b0")
	main_lamp.light_energy = 0.2
	add_child(main_lamp)


func _zone_visuals() -> void:
	# A light texture layer gives each large slab a readable industrial material.
	for zone in [
		{"at": Vector3(-15, 0.09, -10), "size": Vector3(45, 0.025, 24), "key": "steel"},
		{"at": Vector3(-51.5, 0.09, 17), "size": Vector3(65, 0.025, 48), "key": "rust"},
		{"at": Vector3(0, 0.09, 0), "size": Vector3(38, 0.025, 34), "key": "steel"},
		{"at": Vector3(54, 0.09, 0), "size": Vector3(70, 0.025, 50), "key": "steel"},
		{"at": Vector3(0, 0.09, 53), "size": Vector3(75, 0.025, 56), "key": "concrete"},
		{"at": Vector3(0, 0.09, -38), "size": Vector3(40, 0.025, 30), "key": "dark"},
		{"at": Vector3(-52, 0.09, -70), "size": Vector3(45, 0.025, 34), "key": "dark"},
		{"at": Vector3(55, 0.09, -42), "size": Vector3(46, 0.025, 42), "key": "rust"}
	]:
		_box(zone["size"], zone["at"], zone["key"])
	_floor_text("ISOLATION / T", Vector3(-32, 0.14, -13.5), "cyan", 24)
	_floor_text("B-01  AMPLIFICATION", Vector3(54, 0.14, -20.5), "amber", 24)
	_floor_text("B-02 / B-03  SPECTRUM", Vector3(64, 0.14, 2), "cyan", 24)
	_floor_text("C-01  SPLIT CIRCUIT", Vector3(-16, 0.14, 34), "amber", 24)
	_floor_text("C-02  SHUTTER CONTROL", Vector3(13, 0.14, 60), "paper", 24)
	_floor_text("D / ARCHIVE", Vector3(0, 0.14, -49), "paper", 22)
	_floor_text("F / CONTROL", Vector3(55, 0.14, -55), "amber", 22)
	_sign("NOTICE\nINTERNAL OPTICAL TEST AREAS", Vector3(-25, 2.4, 1.2), "paper", 24)
	_sign("UNPOWERED SECTOR\nACCESS LOGGED", Vector3(-52, 2.5, -82), "red", 22)
