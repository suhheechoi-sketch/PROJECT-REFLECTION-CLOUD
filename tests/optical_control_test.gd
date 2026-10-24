extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Lab = preload("res://scripts/a01_lab.gd")
const Pointer = preload("res://scripts/camera_pointer.gd")
var game: Node3D
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL optical control: ", text)

func press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._input(event)

func mouse(pixel: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pixel
	event.global_position = pixel
	root.push_input(event, true)

func wheel(up: bool, fine: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.shift_pressed = fine
	game._input(event)

func click(pixel: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = pixel
	event.global_position = pixel
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	game._input(event)

func settle() -> void:
	await create_timer(0.9).timeout
	await process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/remote_" + name + ".png")

func run() -> void:
	game = Main.instantiate()
	game.exploration_save_path = "user://optical_control_test.json"
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.intro_veil.visible = false
	for id in ["T-01", "T-02", "T-03", "T-04"]:
		game.progression.advance_tutorial(id)
	game.player.set_emitter_acquired(true)
	game.player.position = Lab.SPAWN
	game.player.reset_physics_interpolation()
	game._update_room_visibility()
	mouse(Vector2(800, 400))
	await settle()
	mouse(Vector2(800, 400))
	check(game.player.pointer_position.distance_to(Vector2(800, 400)) < 0.1, "Mouse events reach the shared input position")
	await settle()
	var point: Vector2 = Pointer.screen_position(game.camera, game.a01_lab.mirrors[0].global_position + Vector3.UP * 1.5)
	mouse(point)
	press(KEY_E)
	check(game.selected_device == null and not game.optical_control.authorized(), "Remote picking is locked before console activation")
	game.player.position = Vector3(-55, 0.03, 20)
	game.player.reset_physics_interpolation()
	mouse(Vector2(800, 400))
	await settle()
	mouse(Vector2(800, 400))
	check(game.optical_control.near_console(), "Existing room console is reachable")
	var console_position: Vector3 = game.player.position
	var previous_overview: bool = game.puzzle_camera.overview
	game.selected_device = game.a01_lab.mirrors[0]
	game.selected_device.set_selected(true)
	press(KEY_E)
	check(game.selected_device == null and not game.a01_lab.mirrors[0].is_selected, "Console entry clears stale local selection")
	check(game.optical_control.authorized() and game.optical_control.control_mode and game.puzzle_camera.overview and game.player.position == console_position, "E console grants permission and immediately enters full-room remote mode")
	check(not game.optical_control.permissions.has("B01"), "Permissions are scoped to A01")
	await capture("console")
	press(KEY_R)
	check(game.optical_control.authorized(), "Local reset preserves console authorization")
	await settle()
	var stationary: Vector3 = game.player.position
	for index in range(3):
		var mirror: OpticalDevice = game.a01_lab.mirrors[index]
		point = Pointer.screen_position(game.camera, mirror.global_position + Vector3.UP * 1.5)
		check(not game.optical_control.blocked_by_ui(point), "Mirror is not behind HUD")
		mouse(point)
		await physics_frame
		await physics_frame
		# A live OS cursor may move while the render test waits. Inject the
		# intended viewport event immediately before querying/selecting.
		point = Pointer.screen_position(game.camera, mirror.global_position + Vector3.UP * 1.5)
		mouse(point)
		game.optical_control._physics_process(0)
		check(game.optical_control.hovered == mirror and mirror.is_targeted, "3D cursor hover highlights M%d" % (index + 1))
		check(game.player.position.distance_to(mirror.global_position) > 4.5, "Test operates beyond local rotation range")
		var before_e: OpticalDevice = game.selected_device
		press(KEY_E)
		check(game.selected_device == before_e, "E does not change mirror selection in remote mode")
		click(point)
		check(game.selected_device == mirror and game.optical_control.owns_selection(), "Click selects remote M%d" % (index + 1))
		for step in range(3):
			wheel(index != 0)
		var expected := deg_to_rad(315 if index == 0 else 45)
		check(is_equal_approx(mirror.rotation.y, expected), "Wheel remotely reaches solution angle")
		wheel(true, true)
		check(is_equal_approx(mirror.rotation.y, expected + deg_to_rad(1)), "Shift+wheel rotates one degree")
		wheel(false, true)
		check(game.player.position == stationary, "Remote rotation never repositions player")
		await physics_frame
		await physics_frame
		if index == 1:
			game._update_compact_hud()
			check(game.info_panel.visible, "Selected mirror card is visible during remote control")
			check(root.get_visible_rect().encloses(game.info_panel.get_global_rect()), "Selected mirror card stays within the screen")
			check(game.device_info_label.text.contains("M2") and game.device_info_label.text.contains("45°"), "Selected mirror card shows its ID and current angle")
			await capture("hover_m2")
	# UI consumes clicks/wheel without selecting or changing the current mirror.
	var selected: OpticalDevice = game.selected_device
	var angle := selected.rotation.y
	mouse(game.hud_panel.get_global_rect().get_center())
	wheel(true)
	check(game.selected_device == selected and is_equal_approx(selected.rotation.y, angle), "HUD blocks selection and wheel")
	click(game.hud_panel.get_global_rect().get_center())
	check(game.selected_device == selected, "HUD blocks mirror selection clicks")
	mouse(Vector2(800, 400))
	press(KEY_TAB)
	await physics_frame
	await physics_frame
	press(KEY_E)
	wheel(true)
	check(game.selected_device == selected and is_equal_approx(selected.rotation.y, angle), "Full map blocks controls and preserves selection")
	click(Vector2(800, 400))
	check(game.selected_device == selected, "Full map consumes pointer clicks")
	press(KEY_TAB)
	var mini_before: bool = game.minimap_panel.visible
	press(KEY_M)
	check(game.minimap_panel.visible != mini_before, "M minimap remains operational")
	press(KEY_M)
	# A foreign mirror inside the camera frustum still fails the ownership whitelist.
	var foreign: OpticalDevice = game._create_device("mirror", "FOREIGN TEST MIRROR", Vector3(-63, 0, 24), Vector3(0.26, 2.3, 2.2), 0, Color.WHITE)
	await physics_frame
	await physics_frame
	point = Pointer.screen_position(game.camera, foreign.global_position + Vector3.UP * 1.5)
	check(game.optical_control.pick_at(point) == null, "Foreign mirror cannot be remotely picked even inside the camera frustum")
	foreign.queue_free()
	await process_frame
	press(KEY_R)
	check(game.optical_control.authorized() and game.selected_device == null, "Reset preserves permission and clears remote selection")
	check(game.a01_lab.mirrors.all(func(mirror: OpticalDevice) -> bool: return is_zero_approx(mirror.rotation.y)), "R resets all remotely changed angles")
	for index in range(3):
		point = Pointer.screen_position(game.camera, game.a01_lab.mirrors[index].global_position + Vector3.UP * 1.5)
		mouse(point)
		await physics_frame
		point = Pointer.screen_position(game.camera, game.a01_lab.mirrors[index].global_position + Vector3.UP * 1.5)
		mouse(point)
		click(point)
		for step in range(3):
			wheel(index != 0)
		await physics_frame
	await settle()
	var move := InputEventKey.new()
	move.keycode = KEY_D
	move.pressed = true
	var before_move: Vector3 = game.player.position
	Input.parse_input_event(move)
	Input.flush_buffered_events()
	for tick in range(12):
		game.player._physics_process(1.0 / 60.0)
	var stop := move.duplicate() as InputEventKey
	stop.pressed = false
	Input.parse_input_event(stop)
	Input.flush_buffered_events()
	for tick in range(12):
		game.player._physics_process(1.0 / 60.0)
	check(is_zero_approx(game.player.position.distance_to(before_move)) and game.optical_control.active(), "WASD movement is disabled in optical control mode")
	var held_fire := InputEventMouseButton.new()
	held_fire.button_index = MOUSE_BUTTON_LEFT
	held_fire.pressed = true
	held_fire.button_mask = MOUSE_BUTTON_MASK_LEFT
	held_fire.position = root.get_final_transform() * point
	held_fire.global_position = held_fire.position
	Input.parse_input_event(held_fire)
	Input.flush_buffered_events()
	game.player._physics_process(0.016)
	check(not game.player.firing, "Handheld firing is disabled in remote mode")
	click(Vector2(800, 400))
	check(game.selected_device == null, "Empty-space click clears selection")
	point = Pointer.screen_position(game.camera, game.a01_lab.mirrors[2].global_position + Vector3.UP * 1.5)
	mouse(point)
	click(point)
	check(game.selected_device == game.a01_lab.mirrors[2], "Click selects M3")
	click(point)
	check(game.selected_device == null, "Clicking selected mirror clears selection")
	press(KEY_ESCAPE)
	check(not game.optical_control.control_mode and game.puzzle_camera.overview == previous_overview and not game.is_paused_overlay, "Esc exits remote mode and restores prior camera view")
	game.player._physics_process(0.016)
	check(not game.player.firing, "Held selection click cannot turn into a shot on mode exit")
	var held_release := held_fire.duplicate() as InputEventMouseButton
	held_release.pressed = false
	held_release.button_mask = 0
	Input.parse_input_event(held_release)
	Input.flush_buffered_events()
	game.player._physics_process(0.016)
	for frame in range(8):
		await process_frame
	await settle()
	press(KEY_V)
	check(game.puzzle_camera.overview, "V still enters the normal puzzle overview outside control mode")
	press(KEY_V)
	check(not game.puzzle_camera.overview, "V still returns to exploration outside control mode")
	# Shared pointer agrees with Godot's ordinary projection at a settled pose.
	var aim_target := Vector3(-60, 1.15, 14)
	point = Pointer.screen_position(game.camera, aim_target)
	var ray := Pointer.ray(game.camera, point)
	var ordinary = Plane(Vector3.UP, 1.15).intersects_ray(game.camera.project_ray_origin(point), game.camera.project_ray_normal(point))
	check(ordinary != null and ordinary.distance_to(aim_target) < 0.02, "Shared ray agrees with Godot projection after settling")
	mouse(point)
	game.player._update_aim()
	check(game.player.aim_position.distance_to(aim_target) < 0.002, "Visible-camera mouse aim reaches the intended world point")
	var fire := InputEventMouseButton.new()
	fire.button_index = MOUSE_BUTTON_LEFT
	fire.pressed = true
	fire.button_mask = MOUSE_BUTTON_MASK_LEFT
	# parse_input_event receives window pixels; push_input above receives logical
	# viewport coordinates. Convert explicitly for canvas_items stretch.
	fire.position = root.get_final_transform() * point
	fire.global_position = fire.position
	Input.parse_input_event(fire)
	Input.flush_buffered_events()
	check(game.player.pointer_position.distance_to(point) < 0.1, "Window-pixel mouse press maps to the intended logical viewport point")
	game.player._physics_process(0.016)
	check(game.player.firing, "Holding left mouse still fires the handheld emitter")
	for frame in range(14):
		game._physics_process(0.1)
	check(game.a01_lab.receiver.receiver_active and game.laser.last_segment_count == 4, "Remote angles solve the unchanged three-reflection puzzle")
	if game.laser.segment_nodes.is_empty():
		quit(1)
		return
	var beam: MeshInstance3D = game.laser.segment_nodes[0]
	var emitted_from: Vector3 = beam.global_transform * Vector3(0, -beam.mesh.height * 0.5, 0)
	check(emitted_from.distance_to(game.player.get_emitter_origin()) < 0.002, "First real beam begins at the current handheld emitter")
	game.player.position.z += 0.4
	await physics_frame
	await physics_frame
	game.player._update_aim()
	game._physics_process(0.1)
	beam = game.laser.segment_nodes[0]
	var moved_origin: Vector3 = beam.global_transform * Vector3(0, -beam.mesh.height * 0.5, 0)
	check(moved_origin.distance_to(game.player.get_emitter_origin()) < 0.002 and absf(moved_origin.z - emitted_from.z - 0.4) < 0.002, "Moving the player moves the actual beam source")
	var release := fire.duplicate() as InputEventMouseButton
	release.pressed = false
	release.button_mask = 0
	Input.parse_input_event(release)
	await settle()
	await capture("solution")
	# Revalidate projection while normal camera is returning from the control view.
	for frame in range(8):
		mouse(Pointer.screen_position(game.camera, aim_target))
		game.player._update_aim()
		check(game.player.aim_position.distance_to(aim_target) < 0.002, "Aim round-trip stays aligned during camera transition")
		await process_frame
	await settle()
	game.player.position = Vector3(-55, 0.03, 20)
	game.player.reset_physics_interpolation()
	game.puzzle_camera.toggle()
	await settle()
	check(game.puzzle_camera.overview and game.optical_control.near_console(), "Console is reachable with the normal V overview already active")
	press(KEY_E)
	check(game.optical_control.control_mode, "E enters remote mode from the pre-existing overview")
	press(KEY_ESCAPE)
	check(not game.optical_control.control_mode and game.puzzle_camera.overview, "Esc restores a previously active overview camera")
	press(KEY_V)
	check(not game.puzzle_camera.overview, "Restored V overview returns to exploration")
	press(KEY_ESCAPE)
	check(game.is_paused_overlay, "Esc outside control mode retains pause")
	press(KEY_ESCAPE)
	game.player.position = Vector3(-15, 0.03, 0)
	game.player.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	check(not game.optical_control.authorized() and not game.optical_control.active(), "Room exit removes remote access")
	game.player.position = Lab.SPAWN
	game.player.reset_physics_interpolation()
	check(game.optical_control.authorized(), "Reentry reuses the one-time room authorization")
	var before_restart: bool = game.puzzle_camera.overview
	game.optical_control.enter_control_mode()
	game._reset_all_progress()
	check(not game.optical_control.control_mode and game.puzzle_camera.overview == before_restart, "Full restart exits console through camera restoration")
	check(game.optical_control.permissions.is_empty(), "Full restart clears run-scoped console permissions")
	print("Optical control checks: %d failure(s)." % failures)
	quit(0 if failures == 0 else 1)
