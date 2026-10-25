extends SceneTree
const Pointer = preload("res://scripts/camera_pointer.gd")
var game: Node3D
var touch: Control
var failures := 0
var checks := 0
var visual := "--visual-review" in OS.get_cmdline_user_args()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL CONSOLE: "+message)
	else: print("PASS CONSOLE: "+message)
func settle() -> void:
	await physics_frame
	await physics_frame
func key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	game._input(e)
func tap(at: Vector2,id := 0,down := true) -> void:
	var e := InputEventScreenTouch.new()
	e.index = id
	e.position = at
	e.pressed = down
	touch._input(e)
func click(at: Vector2) -> void:
	game.player.pointer_position = at
	var e := InputEventMouseButton.new()
	e.position = at
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	game._input(e)
func pixel(device: OpticalDevice) -> Vector2:
	return Pointer.screen_position(game.camera,device.position+Vector3.UP*1.4)
func capture(label: String) -> void:
	if not visual: return
	game.room_id = game.current_room()
	game.update_demo_hud(0)
	game.update_demo_map(0.3)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/validation"))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/validation/console_"+label+".png")
func structure_hash() -> String:
	var rows: Array[String] = []
	for body in game.get_children():
		if not body is StaticBody3D: continue
		var shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape == null or not shape.shape is BoxShape3D: continue
		if not [0.7,1.95,2.65].any(func(h): return absf(h-shape.shape.size.y)<0.001): continue
		var p: Vector3 = body.position
		var s: Vector3 = shape.shape.size
		var values: Array[String] = []
		for v in [p.x,p.y,p.z,s.x,s.y,s.z,body.collision_layer]: values.append(str(roundi(v*1000)))
		rows.append(",".join(values))
	rows.sort()
	return "\n".join(rows).sha256_text()
func run() -> void:
	game = preload("res://scenes/ta_demo.tscn").instantiate()
	game.checkpoint_enabled = false
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.a02_lab.set_physics_process(false)
	touch = game.touch_controls
	touch.visible = true
	await settle()
	# Baseline main collider fingerprint minus exactly the T03 vault's 5 walls + 1 slit.
	check(structure_hash() == "d8a84e7080a6455152f4b2e33485dbe5765a12467cf380b36247fd68b526673c","only the six specified vault colliders removed; all other structures and L duct unchanged")
	check(game.devices["T03-RN"].position == Vector3(39,0,5) and game.devices["T03-RN"].minimum_reflections == 1,"T03 receiver position and reflected-hit condition unchanged")
	game.player.position = Vector3(35,0.03,13)
	game.camera.position = Vector3(0,15,5)
	game.camera.rotation_degrees.x = -70
	game.camera.size = 22
	game.camera.reset_physics_interpolation()
	game.room_id = "T-03"
	game.update_demo_hud(0)
	await capture("t03_vault_removed")
	for id in ["T-01","T-02","T-03","T-04","T-04_TERMINAL_E"]: game.completed.append(id)
	game.sync_demo()
	game.player.set_emitter_acquired(true)
	game.player.position = Vector3(35.66,0.03,43.38)
	var pose: Transform3D = game.camera.global_transform
	key(KEY_E)
	await settle()
	check(game.control_mode and game.console_stage == "A-01","A01 E immediately enters existing V-style view")
	game.player.velocity = Vector3.ONE
	game.player._physics_process(0.1)
	check(game.player.velocity == Vector3.ZERO and not game.player.firing,"console restricts normal locomotion and firing")
	var m1: OpticalDevice = game.devices["A01-M1"]
	var m2: OpticalDevice = game.devices["A01-M2"]
	click(pixel(m1))
	check(game.selected_device == m1 and m1.selection_outline.visible,"PC click selects and outlines mirror")
	click(game.hud_panel.get_global_rect().get_center())
	check(game.selected_device == m1,"HUD click does not deselect")
	click(pixel(game.devices["A01-RN"]))
	check(game.selected_device == null and game.control_mode,"receiver click deselects without leaving console")
	click(pixel(m2))
	check(game.selected_device == m2,"another mirror can be selected")
	click(Pointer.screen_position(game.camera,Vector3(41,0,39)))
	check(game.selected_device == null and not m2.is_selected and game.control_mode,"floor click clears selection and highlight but keeps mode")
	var previous := m2.rotation.y
	var wheel := InputEventMouseButton.new()
	wheel.position = Vector2(800,500)
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	game._input(wheel)
	check(m2.rotation.y == previous,"unselected wheel does nothing")
	for pair in [["A01-M1",-45],["A01-M2",45],["A01-M3",45]]:
		game.devices[pair[0]].rotation_degrees.y = pair[1]
		game.devices[pair[0]]._sync_physics_transform()
	await settle()
	click(pixel(m1))
	game.player._update_aim()
	key(KEY_F)
	game._physics_process(1.3)
	check(game.devices["A01-RN"]._hit_this_frame,"console uses real handheld L07 origin and existing reflection engine")
	var segments: int = game.laser.last_segment_count
	wheel.position = pixel(m1)
	game._input(wheel)
	await settle()
	game._physics_process(0.02)
	check(game.laser.last_segment_count != segments,"rotation updates live optical collision path")
	game.room_id = "A-01"
	await capture("a01_pc")
	var angle := m1.rotation.y
	key(KEY_ESCAPE)
	check(not game.control_mode and game.selected_device == null and m1.rotation.y == angle,"Esc clears selection without resetting mirror")
	check(game.camera.global_transform.is_equal_approx(pose),"Esc restores saved camera transform")
	check(game.devices["A01-RN"].receiver_active and game.completed.has("A-01") and not game.restored,"console exit preserves real receiver latch and puzzle progress")
	check(not game.wall_visibility.console_room.has_area(),"exit restores normal wall visibility")
	game.complete("A-01")
	game.mirror_relay.receiver_active = true
	game.player.position = Vector3(9,0.03,47)
	key(KEY_E)
	await settle()
	check(game.a02_lab.control_mode,"existing A02 console still enters")
	click(pixel(game.a02_lab.mirrors[0]))
	check(game.a02_lab.selected == game.a02_lab.mirrors[0],"A02 mirror click selects")
	click(Pointer.screen_position(game.camera,Vector3(15,0,45)))
	check(game.a02_lab.selected == null and game.a02_lab.control_mode,"A02 empty click clears selection only")
	await capture("a02")
	key(KEY_ESCAPE)
	game.complete("A-02")
	game.player.position = Vector3(9,0.03,73.5)
	touch._layout()
	tap(touch.buttons["E"].get_center())
	tap(touch.buttons["E"].get_center(),0,false)
	await settle()
	check(game.control_mode and game.console_stage == "A-03","touch E enters new accessible A03 console")
	var a3: OpticalDevice = game.devices["A03-M2"]
	tap(pixel(a3)+Vector2(20,0))
	tap(pixel(a3)+Vector2(20,0),0,false)
	check(game.selected_device == a3,"touch selects A03 ordinary mirror")
	var neighbor_angle: float = game.devices["A03-M1"].rotation.y
	var before := a3.rotation.y
	tap(touch.buttons["+"].get_center())
	tap(touch.buttons["+"].get_center(),0,false)
	check(is_equal_approx(a3.rotation.y-before,deg_to_rad(15)),"touch + rotates selected mirror 15 degrees without deselecting")
	check(game.devices["A03-M1"].rotation.y == neighbor_angle,"rotation does not alter other mirrors")
	tap(touch.buttons["FINE"].get_center())
	tap(touch.buttons["FINE"].get_center(),0,false)
	before = a3.rotation.y
	tap(touch.buttons["-"].get_center())
	tap(touch.buttons["-"].get_center(),0,false)
	check(is_equal_approx(a3.rotation.y-before,deg_to_rad(-1)),"touch fine - rotates one degree")
	for dimensions in [Vector2i(1920,1080),Vector2i(1440,1080)]:
		root.size = dimensions
		await settle()
		preload("res://scripts/ta_console_view.gd").fit(game,"A-03")
		touch._layout()
		for stage in ["A-01","A-02"]:
			preload("res://scripts/ta_console_view.gd").fit(game,stage)
			var members: Array = [game.devices["A01-M1"],game.devices["A01-M2"],game.devices["A01-M3"],game.devices["A01-RN"]] if stage == "A-01" else game.a02_lab.mirrors+[game.a02_lab.rail,game.a02_lab.control,game.a02_lab.receiver]
			var visible := true
			for member in members:
				var p := pixel(member)
				visible = visible and root.get_visible_rect().has_point(p) and not game.blocked_by_ui(p)
			check(visible,"all mirrors/receivers outside HUD at "+str(dimensions)+" "+stage)
		preload("res://scripts/ta_console_view.gd").fit(game,"A-03")
		for id in ["A03-M1","A03-M2","A03-M3","A03-M4","A03-RAIL","A03-RN","A03-RO1","A03-RO2"]:
			var at := pixel(game.devices[id])
			check(root.get_visible_rect().has_point(at) and not game.blocked_by_ui(at),"device visible and outside UI at "+str(dimensions)+" "+id)
	await capture("a03_ipad_ratio")
	var empty := Pointer.screen_position(game.camera,Vector3(20,0,75))
	tap(empty)
	tap(empty,0,false)
	check(game.selected_device == null and game.control_mode,"external touch deselects but keeps console")
	tap(pixel(game.devices["A03-RAIL"]))
	tap(pixel(game.devices["A03-RAIL"]),0,false)
	check(game.selected_device == null,"fixed rail cannot be rotated from console")
	tap(touch.buttons["ESC"].get_center())
	tap(Vector2.ZERO,0,false)
	check(not game.control_mode and game.player.touch_movement == Vector2.ZERO,"touch exit returns to exploration without held movement")
	game.player.position = Vector3(12.5,0.03,62)
	key(KEY_E)
	check(game.selected_device == null,"A03 field E cannot bypass console selection restriction")
	print("CONSOLE: %d checks / %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	if visual: await RenderingServer.frame_post_draw
	quit(0 if failures == 0 else 1)
