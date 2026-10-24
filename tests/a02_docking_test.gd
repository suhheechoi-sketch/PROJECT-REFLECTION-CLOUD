extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Lab = preload("res://scripts/a02_lab.gd")
var game: Node3D
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL A02: " + message)
func settle() -> void:
	await physics_frame
	await physics_frame
func beam(seconds: float) -> void:
	game.laser.update_beam(Vector3.ZERO, Vector3.RIGHT, false, seconds, "red", game.a02_lab.sources())
func check_walk_routes() -> void:
	var probe := PhysicsShapeQueryParameters3D.new()
	probe.shape = game.player.get_child(0).shape
	probe.collision_mask = 4 | 8
	probe.exclude = [game.player.get_rid()]
	var cells := {}
	for x in range(-166, -100):
		for z in range(54, 82):
			var c := Vector2i(x, z)
			probe.transform.origin = Vector3(x * 0.5, 0.86, z * 0.5)
			if game.get_world_3d().direct_space_state.intersect_shape(probe).is_empty():
				cells[c] = true
	var seed := Vector2i(-106, 54)
	var parents := {seed: seed}
	var queue := [seed]
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + d
			if cells.has(next) and not parents.has(next):
				parents[next] = cell
				queue.append(next)
	for station in [Lab.CONSOLE, Lab.DOCK, Lab.HANDLE]:
		var target := Vector2i(roundi(station.x * 2), roundi(station.z * 2))
		check(parents.has(target), "capsule path from A service entrance reaches station " + str(station))
		if not parents.has(target):
			continue
		var path := [target]
		while path.back() != seed:
			path.append(parents[path.back()])
		path.reverse()
		game.player.position = Vector3(seed.x * 0.5, 0.03, seed.y * 0.5)
		for c in path:
			var at := Vector3(c.x * 0.5, 0.03, c.y * 0.5)
			game.player.move_and_collide(at - game.player.position)
			check(game.player.position.distance_to(at) < 0.03, "actual body sweep follows station route")

func run() -> void:
	game = Main.instantiate()
	game.exploration_save_path = "user://a02_test.json"
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for id in ["T-01", "T-02", "T-03", "T-04"]:
		game.progression.advance_tutorial(id)
	game.player.set_emitter_acquired(true)
	var lab: Node3D = game.a02_lab
	await settle()
	check_walk_routes()
	game.player.position = Lab.DOCK
	game._interact()
	check(not lab.docked, "A01 prerequisite prevents early docking")
	game.mirror_relay.activate_receiver()
	await settle()
	check(lab.mirrors.size() == 2 and not lab.rail.rotatable, "exactly two ordinary mirrors plus one translating rail")
	game.player.position = Lab.CONSOLE
	var pose: Transform3D = game.camera.global_transform
	game._interact()
	check(lab.control_mode, "E console enters control immediately")
	game.player.velocity = Vector3.ONE
	game.player._physics_process(0.1)
	check(not game.player.firing and game.player.velocity == Vector3.ZERO, "console blocks locomotion/fire")
	await settle()
	for i in range(2):
		var pixel := preload("res://scripts/camera_pointer.gd").screen_position(game.camera, lab.mirrors[i].position + Vector3.UP * 1.5)
		var click := InputEventMouseButton.new()
		click.position = pixel
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		game._input(click)
		check(lab.selected == lab.mirrors[i], "real camera ray selects console mirror")
		var wheel := InputEventMouseButton.new()
		wheel.position = pixel
		wheel.pressed = true
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if i == 0 else MOUSE_BUTTON_WHEEL_UP
		for step in range(3):
			game._input(wheel)
		check(absf(angle_difference(lab.mirrors[i].rotation.y, -PI / 4 if i == 0 else PI / 4)) < 0.001, "console wheel rotates 15 degrees")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	game._input(esc)
	check(not lab.control_mode and game.camera.global_transform.is_equal_approx(pose), "Esc restores camera")
	game.player.position = Lab.HANDLE
	lab.move_rail(3)
	check(is_equal_approx(lab.rail.position.x, Lab.ORIGIN.x + 9), "locked rail refuses movement")
	game.player.position = Lab.DOCK
	game._interact()
	check(lab.docked and not game.player.has_emitter and not game.player.emitter.visible and lab.dock_mesh.visible, "one emitter transfers into dock")
	await settle()
	beam(0.8)
	check(lab.control.receiver_active and not lab.receiver.receiver_active, "real two-mirror beam unlocks only control R")
	game.player.position = preload("res://scripts/a01_lab.gd").SPAWN
	game._reset_current_puzzle()
	check(lab.docked and lab.control.receiver_active, "A01 retry preserves the separate parked A02 puzzle")
	game.player.position = Lab.HANDLE
	game._interact()
	check(lab.rail_selected, "local E selects unlocked handle")
	var wheel := InputEventMouseButton.new()
	wheel.position = Vector2(800, 400)
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	for step in range(20):
		game._input(wheel)
	await settle()
	check(is_equal_approx(lab.rail.position.x, Lab.ORIGIN.x + 12), "rail clamps to physical endpoint")
	beam(0.5)
	check(not lab.receiver.receiver_active, "final requires sustained irradiation")
	beam(0.8)
	check(lab.receiver.receiver_active and game.laser.last_segment_count == 4, "real three-reflection route completes final R")
	await settle()
	for mirror in lab.mirrors + [lab.rail]:
		game.laser.ignore_rids.append(mirror.get_rid())
		lab.receiver.reset_device()
		beam(2.0)
		check(not lab.receiver.receiver_active, "every mirror is physically necessary for final route")
		game.laser.ignore_rids.erase(mirror.get_rid())
	beam(1.3)
	check(game.progression.completed_stage_ids.has("A-02"), "completion is registered separately")
	game.player.position = Lab.DOCK
	var f := InputEventKey.new()
	f.keycode = KEY_F
	f.pressed = true
	game._input(f)
	check(lab.sources().is_empty() and lab.docked, "F stops beam without returning equipment")
	game._interact()
	check(not lab.docked and game.player.has_emitter and lab.sources().is_empty(), "E retrieves equipment and stops source")
	# Direct fire cannot traverse the folded channel from sampled body-clear exterior cells.
	var bypasses := 0
	var shape := SphereShape3D.new()
	shape.radius = 0.38
	for xi in range(-166, -116):
		for zi in range(54, 82):
			var point := Vector3(xi * 0.5, 0.83, zi * 0.5)
			if lab._inside(Vector2(point.x - Lab.ORIGIN.x, point.z - Lab.ORIGIN.z)):
				continue
			var probe := PhysicsShapeQueryParameters3D.new()
			probe.shape = shape
			probe.transform.origin = point
			probe.collision_mask = 4 | 8
			probe.exclude = [game.player.get_rid()]
			if not game.get_world_3d().direct_space_state.intersect_shape(probe).is_empty():
				continue
			point.y = 1.15
			var query := PhysicsRayQueryParameters3D.create(point, lab.receiver.position + Vector3.UP * 1.15, 7)
			query.exclude = [game.player.get_rid(), lab.mirrors[0].get_rid(), lab.mirrors[1].get_rid(), lab.rail.get_rid()]
			query.hit_from_inside = true
			var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.get("collider") == lab.receiver:
				bypasses += 1
	check(bypasses == 0, "sampled exterior direct-fire bypasses: %d" % bypasses)
	lab.reset_lab(true)
	game.player.position = Lab.DOCK
	game._interact()
	await settle()
	game._reset_current_puzzle()
	await settle()
	check(not lab.docked and game.player.has_emitter and not lab.control.receiver_active and not lab.receiver.receiver_active, "local retry returns equipment and clears unfinished state")
	check(is_equal_approx(lab.rail.position.x, Lab.ORIGIN.x + 9), "retry restores rail position")
	game.player.position = Lab.DOCK
	game._interact()
	game._reset_all_progress()
	check(not lab.docked and not game.player.has_emitter and lab.sources().is_empty(), "full reset leaves no duplicate or orphan source")
	print("A02 docking checks: %d failure(s)" % failures)
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
