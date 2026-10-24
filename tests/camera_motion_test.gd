extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.exploration_save_path = "user://camera_motion_test.json"
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var offset: Vector3 = game.camera.position
	var angle: Vector3 = game.camera.rotation
	for codes in [[], [KEY_D], [KEY_D, KEY_S], [KEY_A], []]:
		var before: Vector3 = game.player.position
		for code in codes:
			key(code, true)
		for frame in range(30):
			await physics_frame
			check(game.camera.position.is_equal_approx(offset), "Camera offset changed during movement")
			check(game.camera.rotation.is_equal_approx(angle), "Camera rotated during movement")
		for code in codes:
			key(code, false)
		if not codes.is_empty():
			check(game.player.position.distance_to(before) > 0.05, "Injected movement input did not move player")
	for frame in range(30):
		await physics_frame
	var stopped: Vector3 = game.player.position
	for frame in range(30):
		await physics_frame
	check(game.player.position.is_equal_approx(stopped), "Player drifted after stopping")
	check(not game.wall_visibility.walls.is_empty(), "No structural walls registered")
	var record: Dictionary = game.wall_visibility.walls[0]
	var wall: MeshInstance3D = record.visual
	var original_shape: Shape3D = wall.get_parent().get_node("CollisionShape3D").shape
	game.player.set_physics_process(false)
	game.player.global_position = wall.global_position + Vector3(0, -wall.global_position.y, -0.7)
	game.player.reset_physics_interpolation()
	await create_timer(0.5).timeout
	check(record.material.albedo_color.a < 0.3, "Occluding wall did not fade")
	game.player.global_position = Vector3(300, 0, 300)
	game.player.reset_physics_interpolation()
	await create_timer(0.5).timeout
	check(record.material.albedo_color.a > 0.95, "Wall did not recover opacity")
	check(wall.get_parent().get_node("CollisionShape3D").shape == original_shape, "Wall collision changed")
	print("Camera motion and wall checks: %d failure(s)." % failures)
	quit(0 if failures == 0 else 1)
