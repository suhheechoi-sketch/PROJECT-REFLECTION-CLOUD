extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Lab = preload("res://scripts/a01_lab.gd")
var failures := 0
var game: Variant

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL A01: ", text)

func pose(point: Vector3) -> void:
	game.player.position = point
	game.player.velocity = Vector3.ZERO
	game.player.reset_physics_interpolation()

func hit(start: Vector3, end: Vector3, mask: int = 7, excluded: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start, end, mask)
	query.exclude = [game.player.get_rid()] + excluded
	query.hit_from_inside = true
	return game.get_world_3d().direct_space_state.intersect_ray(query)

func run() -> void:
	game = Main.instantiate()
	game.exploration_save_path = "user://a01_lab_test.json"
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for id in ["T-01", "T-02", "T-03", "T-04"]:
		game.progression.advance_tutorial(id)
	game.player.set_emitter_acquired(true)
	await physics_frame
	await physics_frame
	var lab: Node3D = game.a01_lab
	check(lab.mirrors.size() == 3, "Exactly three mirrors")
	check(lab.receiver.required_direction == Vector3.ZERO and lab.receiver.minimum_reflections == 0, "Ordinary receiver has no direction or reflection-count lock")
	var angles := [-45.0, 45.0, 45.0]
	for index in range(3):
		pose(Lab.ORIGIN + Lab.SERVICE_POINTS[index])
		game.selected_device = null
		var interact := InputEventKey.new()
		interact.keycode = KEY_E
		interact.pressed = true
		game._input(interact)
		check(game.selected_device == lab.mirrors[index], "E selects mirror %d through its service slot" % (index + 1))
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if index == 0 else MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		for step in range(3):
			game._input(wheel)
		wheel.shift_pressed = true
		game._input(wheel)
		check(is_equal_approx(rad_to_deg(wrapf(lab.mirrors[index].rotation.y, -PI, PI)), angles[index] + (-1 if index == 0 else 1)), "Shift+wheel precise rotation mirror %d" % (index + 1))
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP if index == 0 else MOUSE_BUTTON_WHEEL_DOWN
		game._input(wheel)
		check(is_equal_approx(rad_to_deg(wrapf(lab.mirrors[index].rotation.y, -PI, PI)), angles[index]), "Wheel reaches solution mirror %d" % (index + 1))
		var close_point: Vector3 = Lab.MIRROR_POINTS[index].lerp(Lab.SERVICE_POINTS[index], 2.0 / 2.6)
		close_point.y = 0.03
		pose(Lab.ORIGIN + close_point)
		check(game._nearest_device() == lab.mirrors[index], "Mirror remains selectable when approaching the sill")
	pose(Lab.SPAWN)
	await physics_frame
	await physics_frame
	# Aim the actual handheld origin through the 0.5m entrance slit.
	var origin: Vector3 = game.player.get_emitter_origin()
	var target := Vector3(origin.x, origin.y, Lab.ORIGIN.z + 4)
	game.laser.update_beam(origin, target, true, 0.5)
	check(not lab.receiver.receiver_active, "A pulse does not complete the hold")
	game.laser.update_beam(origin, target, true, 0.8)
	print("Solution segments: ", game.laser.last_segment_count, " origin=", origin)
	check(game.laser.last_segment_count == 4 and lab.receiver.receiver_active, "Handheld beam follows all three mirrors to ordinary receiver")
	check(game.progression.restored_circuits.has("A"), "Existing A progression callback retained")
	game._sync_progression_gates()
	await physics_frame
	await physics_frame
	check(lab.barrier.get_node("CollisionShape3D").disabled and lab.exit_door.get_node("CollisionShape3D").disabled, "Receiver opens barrier and puzzle door")
	check(hit(Lab.ORIGIN + Vector3(17, 1.15, 5), Lab.ORIGIN + Vector3(23, 1.15, 5), 4).is_empty(), "Opened exit corridor clears body and laser path")
	# Remove each mirror from the actual optical collision scene in turn.
	for mirror in lab.mirrors:
		lab.receiver.reset_device()
		game.laser.ignore_rids.append(mirror.get_rid())
		game.laser.update_beam(origin, target, true, 2.0)
		check(not lab.receiver.receiver_active, "Every mirror is necessary: " + mirror.display_name)
		game.laser.ignore_rids.erase(mirror.get_rid())
	# Enumerate body-clear grid positions, then direct rays to the entire receiver face.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.65
	var body_query := PhysicsShapeQueryParameters3D.new()
	body_query.shape = capsule
	body_query.collision_mask = 12
	body_query.exclude = [game.player.get_rid()]
	var samples := 0
	var bypasses := 0
	var escaped := 0
	var clear_cells := {}
	var excluded: Array[RID] = []
	for mirror in lab.mirrors:
		excluded.append(mirror.get_rid())
	# Includes surrounding A wing and approach corridors, both before and after solve.
	for xi in range(0, 261):
		for zi in range(0, 193):
			var feet := Vector3(-84 + xi * 0.25, 0.03, -7 + zi * 0.25)
			body_query.transform = Transform3D(Basis.IDENTITY, feet + Vector3(0, 0.83, 0))
			if not game.get_world_3d().direct_space_state.intersect_shape(body_query, 1).is_empty():
				continue
			clear_cells[Vector2i(xi, zi)] = true
			var local := Vector2(feet.x - Lab.ORIGIN.x, feet.z - Lab.ORIGIN.z)
			# Channel positions are intentionally inaccessible; verify separation by body sweep below.
			if lab.in_channel(local):
				continue
			samples += 1
			var start := feet + Vector3(0.34, 1.12, -0.38)
			for dz in [-0.44, 0.0, 0.44]:
				var result := hit(start, lab.receiver.global_position + Vector3(-0.36, 1.15, dz), 7, excluded)
				if not result.is_empty() and result.collider == lab.receiver:
					bypasses += 1
	check(bypasses == 0, "No direct shot from %d capsule-clear exterior samples (0.25m grid, three receiver-face targets)" % samples)
	print("A01 direct-fire samples=", samples, " bypasses=", bypasses)
	# Continuous direct-fire bound: every ray entering the only emitter-height
	# aperture and ending anywhere on the receiver rectangle crosses the right
	# wall of the entry leg at x=5.5, well inside its solid z=[5.5,12.5] span.
	var lowest := INF
	var highest := -INF
	for entry_x in [3.75, 4.25]:
		for receiver_x in [16.64, 17.36]:
			for receiver_z in [9.55, 10.45]:
				var z: float = lerpf(12.4, receiver_z, (5.5 - entry_x) / (receiver_x - entry_x))
				lowest = minf(lowest, z)
				highest = maxf(highest, z)
	check(lowest > 5.6 and highest < 12.4, "Continuous aperture-to-receiver ray family intersects the solid entry-leg wall")
	print("A01 continuous direct-fire bound: wall x=5.5, z=[", lowest, ",", highest, "]")
	# Flood from the unchanged north service opening. Capsule diameter exceeds
	# the grid step and wall thickness, so cardinal links cannot jump a wall.
	var seed := Vector2i(128, 60) # world (-52,8), immediately before the A lab opening.
	check(clear_cells.has(seed), "Existing A entry is capsule-clear")
	var reached := {seed: true}
	var parents := {}
	var queue: Array[Vector2i] = [seed]
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		var point := Vector2(-84 + cell.x * 0.25 - Lab.ORIGIN.x, -7 + cell.y * 0.25 - Lab.ORIGIN.z)
		if lab.in_channel(point):
			escaped += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + step
			if clear_cells.has(neighbor) and not reached.has(neighbor):
				reached[neighbor] = true
				parents[neighbor] = cell
				queue.append(neighbor)
	check(escaped == 0, "No reachable capsule position enters the optical channel")
	for point in Lab.SERVICE_POINTS + [Lab.SPAWN - Lab.ORIGIN]:
		var cell := Vector2i(roundi((Lab.ORIGIN.x + point.x + 84) * 4), roundi((Lab.ORIGIN.z + point.z + 7) * 4))
		check(reached.has(cell), "Entry connects to service/firing position " + str(point))
		if reached.has(cell):
			var path: Array[Vector2i] = [cell]
			while path.back() != seed:
				path.append(parents[path.back()])
			path.reverse()
			pose(Vector3(-52, 0.03, 8))
			for step in path:
				var next := Vector3(-84 + step.x * 0.25, 0.03, -7 + step.y * 0.25)
				game.player.move_and_collide(next - game.player.global_position)
				check(game.player.global_position.distance_to(next) < 0.02, "Actual body sweep reaches service route cell")
	print("A01 reachable capsule cells=", reached.size(), " channel entries=", escaped)
	# Real CharacterBody sweeps through inspection and optical openings.
	for index in range(3):
		pose(Lab.ORIGIN + Lab.SERVICE_POINTS[index])
		var movement: Vector3 = Lab.MIRROR_POINTS[index] - Lab.SERVICE_POINTS[index]
		movement.y = 0
		check(game.player.test_move(game.player.global_transform, movement), "Service slot blocks player %d" % (index + 1))
	pose(Lab.SPAWN)
	check(game.player.test_move(game.player.global_transform, Vector3(0, 0, -4)), "Optical aperture blocks player")
	game.progression.restored_circuits.erase("A")
	game._reset_current_puzzle()
	game._sync_progression_gates()
	await physics_frame
	await physics_frame
	check(game.player.position.is_equal_approx(Lab.SPAWN), "R returns player to safe A01 lane")
	check(not lab.receiver.receiver_active and lab.receiver.receiver_progress == 0, "R clears unfinished receiver")
	check(lab.mirrors.all(func(mirror: OpticalDevice) -> bool: return is_zero_approx(mirror.rotation.y)), "R restores all three initial angles")
	check(not lab.exit_door.get_node("CollisionShape3D").disabled, "R closes unfinished puzzle exit")
	check(not hit(Lab.ORIGIN + Vector3(21, 1.15, 5), Lab.ORIGIN + Vector3(23, 1.15, 5), 4).is_empty(), "Closed puzzle door blocks laser")
	# Actual laser must also stop when its shoulder origin overlaps a solid wall.
	var shield_origin := Lab.ORIGIN + Vector3(4, 1.15, 2.5)
	game.laser.update_beam(shield_origin, shield_origin + Vector3(0, 0, 20), true, 2)
	check(not lab.receiver.receiver_active and game.laser.last_segment_count == 1, "A ray beginning inside a wall cannot escape through it")
	print("A01 lab checks: %d failure(s)." % failures)
	quit(0 if failures == 0 else 1)
