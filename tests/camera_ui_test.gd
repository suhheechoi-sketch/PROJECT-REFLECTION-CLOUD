extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Lab = preload("res://scripts/a01_lab.gd")
const CameraRig = preload("res://scripts/puzzle_camera.gd")
var failures := 0
var game: Node3D
var render := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL camera/UI: ", message)

func press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._input(event)

func settle() -> void:
	await create_timer(1.2).timeout
	await process_frame

func capture(filename: String) -> void:
	if not render:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/camera_ui_" + filename + ".png")

func check_fit() -> void:
	var safe: Rect2 = game.puzzle_camera.safe_rect()
	var devices: Array = [game.player]
	devices.append_array(game.a01_lab.mirrors)
	devices.append(game.a01_lab.receiver)
	for device in devices:
		var point: Vector2 = game.camera.unproject_position(device.global_position + Vector3.UP * 1.5)
		check(safe.has_point(point), "Framed subject outside safe play area: " + str(device.name) + " at " + str(point))
		check(not game.hud_panel.get_global_rect().has_point(point), "Compact HUD covers subject")
		check(not game.minimap_panel.get_global_rect().has_point(point), "Minimap covers subject")
		check(not game.info_panel.visible or not game.info_panel.get_global_rect().has_point(point), "Device card covers subject")
	for marker in game.puzzle_camera.markers:
		check(marker.visible, "Puzzle marker missing")

func run() -> void:
	render = DisplayServer.get_name() != "headless"
	game = Main.instantiate()
	game.exploration_save_path = "user://camera_ui_test.json"
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.intro_veil.visible = false
	check(game.prompt_panel.visible, "Tutorial retains initial control teaching")
	for id in ["T-01", "T-02", "T-03", "T-04"]:
		game.progression.advance_tutorial(id)
	game.player.set_emitter_acquired(true)
	game.player.position = Lab.SPAWN
	game.player.reset_physics_interpolation()
	game._update_room_visibility()
	await settle()
	check(is_equal_approx(game.camera.size, 17), "Exploration zoom")
	check(not game.hud_details.visible and not game.prompt_panel.visible and not game.info_panel.visible, "Ordinary play has compact HUD and no persistent bottom panels")
	check(game.hud_panel.size.x < 500 and game.hud_panel.size.y < 180, "Compact HUD footprint")
	await capture("exploration")
	var cells: Dictionary = game.explored_cells.duplicate(true)
	var discoveries: Dictionary = game.visited_device_ids.duplicate(true)
	var positions: Array[Vector3] = []
	for device in game.a01_lab.mirrors:
		positions.append(device.global_position)
	var old_position: Vector3 = game.camera.position
	press(KEY_V)
	await physics_frame
	await physics_frame
	var pose: Dictionary = game.puzzle_camera.fit_pose()
	check(game.camera.global_position.distance_to(pose.position) > 0.1, "View transition should animate rather than snap")
	check(game.camera.position.distance_to(old_position) > 0.01, "Camera starts moving toward overview")
	await settle()
	check(game.puzzle_camera.overview and game.puzzle_camera.framing, "V enters overview")
	check_fit()
	check(game.camera.cull_mask == CameraRig.PUZZLE_LAYER, "Overview only renders puzzle visuals")
	check((game.get_node("A FLOOR 65x48m").get_child(0).layers & CameraRig.PUZZLE_LAYER) == 0, "Other A-wing floor is excluded")
	check((game.get_node("A01 STEEL FLOOR").get_child(0).layers & CameraRig.PUZZLE_LAYER) != 0, "Puzzle floor remains rendered")
	check((game.get_node("CONTROL CONSOLE").get_child(0).layers & CameraRig.PUZZLE_LAYER) != 0, "Existing collidable room prop stays visible")
	for child in game.get_children():
		if child is Light3D:
			check((child.layers & CameraRig.PUZZLE_LAYER) != 0, "Overview retains original lighting")
	check(game.explored_cells == cells and game.visited_device_ids == discoveries, "Overview does not publish minimap discoveries")
	await capture("overview")
	var fixed_view: Vector3 = game.camera.global_position
	for frame in range(30):
		game.player.position.x += 0.04
		await physics_frame
		await process_frame
	check(game.camera.global_position.distance_to(fixed_view) < 0.03, "Overview stays room-centered while player moves")
	check_fit()
	press(KEY_V)
	var start: Vector3 = game.player.get_emitter_origin()
	game.laser.update_beam(start, start + Vector3.FORWARD * 20, true, 0.1)
	await physics_frame
	await physics_frame
	for beam in game.laser.segment_nodes:
		check((beam.layers & CameraRig.PUZZLE_LAYER) != 0, "New beam meshes stay visible while returning to follow")
	await settle()
	check(not game.puzzle_camera.framing and game.camera.cull_mask == game.puzzle_camera.original_mask, "V returns to exploration and restores rendering")
	check(game.camera.position.is_equal_approx(CameraRig.OFFSET), "Original player-relative follow restored")
	for index in range(3):
		game.player.position = Lab.ORIGIN + Lab.SERVICE_POINTS[index]
		game.player.reset_physics_interpolation()
		game.selected_device = null
		press(KEY_E)
		await settle()
		check(game.selected_device == game.a01_lab.mirrors[index], "E still selects mirror")
		check(game.puzzle_camera.framing and not game.puzzle_camera.overview, "Selected mirror frames the full optical path")
		check_fit()
		check(game.info_panel.visible and not game.prompt_panel.visible, "Selected-device instructions replace global bottom bar")
		var before: float = game.selected_device.rotation.y
		game._rotate_selected(1, true)
		check(is_equal_approx(game.selected_device.rotation.y, before + deg_to_rad(1)), "Precision rotation remains operational")
		await capture("mirror_%d" % (index + 1))
		press(KEY_E)
		await settle()
	# Closing explicit V overview returns to follow even while a mirror is selected.
	game.player.position = Lab.ORIGIN + Lab.SERVICE_POINTS[2]
	press(KEY_E)
	await settle()
	press(KEY_V)
	await settle()
	press(KEY_V)
	await settle()
	check(not game.puzzle_camera.framing, "Second V overrides automatic selected-mirror framing")
	press(KEY_V)
	game.details_button.pressed.emit()
	check(game.hud_details.visible, "Long guidance expands on request")
	await settle()
	check_fit()
	game.details_button.pressed.emit()
	await process_frame
	check(not game.hud_details.visible and game.hud_panel.size.y < 180, "Guidance collapses and panel shrinks")
	press(KEY_H)
	await physics_frame
	await physics_frame
	check(game.help_panel.visible and game.prompt_panel.visible, "H keeps its help function")
	press(KEY_F1)
	await physics_frame
	await physics_frame
	check(not game.help_panel.visible and not game.prompt_panel.visible, "F1 closes help and bottom bar")
	# Resize the render viewport; pose calculation must use actual projection scale.
	game.selected_device = null
	game.puzzle_camera.manual_explore = false
	game.puzzle_camera.overview = true
	for resolution in [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(800, 1000)]:
		root.content_scale_size = Vector2i.ZERO
		root.size = resolution
		await settle()
		check_fit()
		print("Camera/UI viewport ", root.get_visible_rect().size, " zoom=", game.camera.size)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	game.player.position = Lab.SPAWN
	game.player.reset_physics_interpolation()
	for index in range(3):
		game.a01_lab.mirrors[index].reset_device()
		game.a01_lab.mirrors[index].rotate_steps(-3 if index == 0 else 3)
	await physics_frame
	await physics_frame
	var beam_start: Vector3 = game.player.get_emitter_origin()
	game.laser.update_beam(beam_start, beam_start + Vector3.FORWARD * 20, true, 1.3)
	game._sync_progression_gates()
	await settle()
	check(game.a01_lab.receiver.receiver_active and game.laser.last_segment_count == 4, "Overview preserves the actual three-reflection solution")
	check_fit()
	for beam in game.laser.segment_nodes:
		if beam.visible:
			check(game.puzzle_camera.safe_rect().has_point(game.camera.unproject_position(beam.global_position)), "Actual beam segment falls outside the framed play area")
	await capture("solution")
	game.player.position = Vector3(-15, 0.03, 0)
	game.player.reset_physics_interpolation()
	await settle()
	check(not game.puzzle_camera.overview and not game.puzzle_camera.framing, "Leaving the puzzle restores exploration")
	press(KEY_V)
	check(not game.puzzle_camera.overview, "V outside A01 reveals no remote room")
	for index in range(3):
		check(game.a01_lab.mirrors[index].global_position == positions[index], "Camera/UI must never move mirrors")
	print("Camera/UI checks: %d failure(s)." % failures)
	quit(0 if failures == 0 else 1)
