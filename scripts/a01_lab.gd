extends Node3D
## v6.3 pp.4–5 adapted for three locally operable mirrors.
## A continuous folded optical channel separates emitter-height rays from low service slots.
const ORIGIN := Vector3(-64, 0, 10)
const SPAWN := Vector3(-60.34, 0.03, 24)
const MIRROR_POINTS := [Vector3(4, 0, 4), Vector3(12, 0, 4), Vector3(12, 0, 10)]
const SERVICE_POINTS := [Vector3(1.4, 0.03, 4), Vector3(12, 0.03, 1.4), Vector3(12, 0.03, 12.6)]
const CHANNELS := [Rect2(2.5, 2.5, 3, 10), Rect2(2.5, 2.5, 11, 3), Rect2(10.5, 2.5, 3, 9), Rect2(10.5, 8.5, 8, 3)]
var mirrors: Array[OpticalDevice] = []
var receiver: OpticalDevice
var barrier: StaticBody3D
var exit_door: StaticBody3D
var world: Node3D
var concrete: StandardMaterial3D

func build(game: Node3D) -> void:
	world = game
	name = "A01_v63"
	concrete = world.materials["wall"].duplicate() as StandardMaterial3D
	concrete.albedo_color = Color("69716a")
	world._add_floor_zone("A01 STEEL FLOOR", ORIGIN + Vector3(11, 0.105, 7.5), Vector3(24, 0.02, 15), world.materials["metal"])
	# Retire only the superseded two-reflection A-01 sign; locked asset sources stay intact.
	for child in world.facility_art.get_children():
		if child is Label3D and child.text.contains("A-01") and child.text.contains("TWO REFLECTIONS"):
			child.visible = false
	_build_channel()
	# Existing room partitions at z=9/26 and their service openings remain in place.
	# Exit alcove remains sealed until the A-01 receiver latches.
	wall("EXIT NORTH", Vector3(20, 1.4, 2), Vector3(4, 2.8, 0.2))
	wall("EXIT SOUTH", Vector3(20, 1.4, 8), Vector3(4, 2.8, 0.2))
	wall("EXIT EAST NORTH", Vector3(22, 1.4, 2.75), Vector3(0.2, 2.8, 1.5))
	wall("EXIT EAST SOUTH", Vector3(22, 1.4, 7.25), Vector3(0.2, 2.8, 1.5))
	exit_door = world._make_gate("A01 PUZZLE EXIT", ORIGIN + Vector3(22, 1.4, 5), Vector3(0.2, 2.8, 3))
	barrier = world._make_gate("A01 MECHANICAL BARRIER", ORIGIN + Vector3(18, 1.4, 5), Vector3(0.2, 2.8, 6))
	world._disable_art_shadows(exit_door)
	world._disable_art_shadows(barrier)
	world._register_map_gate(exit_door, "A01-exit", "A-01 퍼즐 출입문", "area_a")
	world._register_map_gate(barrier, "A01-barrier", "A-01 기계식 차단벽", "area_a")
	for index in range(3):
		var mirror: OpticalDevice = world._create_device("mirror", "M-A01-%d 점검 거울" % (index + 1), ORIGIN + MIRROR_POINTS[index], Vector3(0.26, 2.3, 2.2), 0.0, Color(0.36, 0.55, 0.57))
		mirrors.append(mirror)
		# Probe the low service access at the mirror base; all other devices keep
		# their existing interaction height and the same E/wheel distance checks.
		mirror.set_meta("interaction_height", 0.25)
		var mark := Label3D.new()
		mark.text = "M%d" % (index + 1)
		mark.position = ORIGIN + MIRROR_POINTS[index] + Vector3.UP * 2.65
		mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mark.font_size = 32
		mark.pixel_size = 0.008
		add_child(mark)
	receiver = world._create_device("receiver", "R-A01 일반 수신기", ORIGIN + Vector3(17, 0, 10), Vector3(0.72, 2.1, 0.9), 0, Color(0.9, 0.23, 0.08))
	receiver.required_seconds = 1.2
	# Normal receiver: bypass prevention must hold with these ordinary defaults.
	receiver.minimum_reflections = 0
	receiver.required_direction = Vector3.ZERO
	for index in range(3):
		label_at("M%d 점검 위치\nE 선택 · 휠 회전" % (index + 1), SERVICE_POINTS[index])
		world._add_box("A01 SERVICE MARK %d" % index, ORIGIN + SERVICE_POINTS[index] + Vector3(0, 0.08, 0), Vector3(0.6, 0.025, 0.6), world.materials["yellow"], false)
	label_at("A-01 / 휴대 발사기\n세 거울 반사 실험", SPAWN - ORIGIN + Vector3(0, 0, 0.7))
	world._add_box("A01 FIRING MARK", SPAWN + Vector3(0, 0.08, 0), Vector3(0.6, 0.025, 0.6), world.materials["cyan"], false)
	world._add_area_light(ORIGIN + Vector3(8, 2.2, 7), Color(0.76, 0.84, 0.8), 0.8, 15)

func wall(title: String, point: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = world._add_wall("A01 " + title, ORIGIN + point, size)
	(body.get_child(0) as GeometryInstance3D).material_override = concrete

func in_channel(point: Vector2) -> bool:
	for rect in CHANNELS:
		if rect.has_point(point):
			return true
	return false

func _build_channel() -> void:
	# Extract and merge the union boundary, so adjoining legs have no duplicate walls.
	var groups := {}
	for x in range(5, 37):
		for z in range(5, 25):
			var cell := Vector2(x * 0.5 + 0.25, z * 0.5 + 0.25)
			if not in_channel(cell):
				continue
			for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				if in_channel(cell + direction * 0.5):
					continue
				var point: Vector2 = cell + direction * 0.25
				var vertical: bool = direction.x != 0
				var kind := "solid"
				if point.distance_to(Vector2(2.5, 4)) < 0.8 or point.distance_to(Vector2(12, 2.5)) < 0.8 or point.distance_to(Vector2(12, 11.5)) < 0.8:
					kind = "service"
				if is_equal_approx(point.y, 12.5) and absf(point.x - 4) < 0.3:
					kind = "beam"
				var fixed: float = point.x if vertical else point.y
				var along: float = point.y if vertical else point.x
				var id := "%s:%s:%s" % [vertical, fixed, kind]
				if not groups.has(id):
					groups[id] = {"vertical": vertical, "fixed": fixed, "kind": kind, "points": []}
				groups[id].points.append(along)
	var count := 0
	for group in groups.values():
		group.points.sort()
		var first: float = group.points[0] - 0.25
		var last := first
		for value in group.points:
			if float(value) - 0.25 > last + 0.01:
				_boundary(group, first, last, count)
				count += 1
				first = float(value) - 0.25
			last = float(value) + 0.25
		_boundary(group, first, last, count)
		count += 1

func _boundary(group: Dictionary, first: float, last: float, index: int) -> void:
	var point := Vector3(group.fixed, 0, (first + last) * 0.5) if group.vertical else Vector3((first + last) * 0.5, 0, group.fixed)
	var size := Vector3(0.2, 2.8, last - first) if group.vertical else Vector3(last - first, 2.8, 0.2)
	if group.kind == "solid":
		wall("CHANNEL %d" % index, point + Vector3.UP * 1.4, size)
	elif group.kind == "service":
		var bottom := size
		bottom.y = 0.55
		wall("SERVICE SILL %d" % index, point + Vector3.UP * 0.275, bottom)
		var top := size
		top.y = 2.8 - 1.10
		wall("SERVICE SHIELD %d" % index, point + Vector3.UP * (1.10 + top.y * 0.5), top)
	else:
		# Layer 8 is player-only. The existing laser mask 7 excludes it.
		# Reduce the merged 1m grid opening to a 0.5m optical slit.
		wall("APERTURE LEFT JAMB", point + Vector3(-0.375, 1.4, 0), Vector3(0.25, 2.8, 0.2))
		wall("APERTURE RIGHT JAMB", point + Vector3(0.375, 1.4, 0), Vector3(0.25, 2.8, 0.2))
		size.x = 0.5
		var window: StaticBody3D = world._add_box("A01 OPTICAL APERTURE", ORIGIN + point + Vector3.UP * 1.4, size, world.materials["cyan"], true, 8)
		(window.get_child(0) as GeometryInstance3D).visible = false
		label_at("OPTICAL ONLY / 0.5 m", point + Vector3(0, 0, 0.5))

func sync() -> void:
	if receiver == null:
		return
	for gate in [barrier, exit_door]:
		var shape := gate.get_node("CollisionShape3D") as CollisionShape3D
		if shape.disabled != receiver.receiver_active:
			shape.set_deferred("disabled", receiver.receiver_active)
		gate.visible = not receiver.receiver_active

func label_at(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = ORIGIN + Vector3(at.x, 0.16, at.z)
	label.rotation_degrees.x = -90
	label.font_size = 24
	label.pixel_size = 0.009
	add_child(label)
