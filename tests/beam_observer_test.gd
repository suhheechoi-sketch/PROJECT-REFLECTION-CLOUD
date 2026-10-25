extends SceneTree
var game: Node3D
var observer: PanelContainer
var failures := 0
var checks := 0
var visual := "--visual-review" in OS.get_cmdline_user_args()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL OBSERVER: "+message)
	else: print("PASS OBSERVER: "+message)
func settle() -> void:
	await physics_frame
	await physics_frame
func capture(label: String) -> void:
	if not visual: return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/validation"))
	game.room_id = game.current_room()
	game.update_demo_hud(0)
	game.player.set_physics_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/validation/observer_"+label+".png")
func sample(seconds := 0.25) -> void:
	for i in range(ceili(seconds/0.05)): observer._process(0.05)
func run() -> void:
	game = preload("res://scenes/ta_demo.tscn").instantiate()
	game.checkpoint_enabled = false
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.a02_lab.set_physics_process(false)
	observer = game.beam_observer
	observer.set_process(false)
	game.platform_ui.select_mode("COMPUTER")
	game.platform_ui.open()
	await process_frame
	await process_frame
	var pick_touch := InputEventScreenTouch.new()
	pick_touch.index = 91
	pick_touch.position = game.platform_ui.mode_buttons["MOBILE"].get_global_rect().get_center()
	pick_touch.pressed = true
	root.push_input(pick_touch,true)
	pick_touch = pick_touch.duplicate()
	pick_touch.pressed = false
	root.push_input(pick_touch,true)
	check(game.platform_ui.mode == "MOBILE" and not game.platform_ui.is_open(),"real ScreenTouch selects MOBILE while mouse emulation stays disabled")
	pick_touch.position = game.platform_ui.settings_button.get_global_rect().get_center()
	pick_touch.pressed = true
	root.push_input(pick_touch,true)
	pick_touch = pick_touch.duplicate()
	pick_touch.pressed = false
	root.push_input(pick_touch,true)
	check(game.platform_ui.is_open(),"settings button can be opened using only touch")
	game.platform_ui.select_mode("COMPUTER")
	game.player.set_physics_process(false)
	game.player.set_emitter_acquired(true)
	await settle()
	check(game.platform_ui.modal.theme == game.hud_root.theme and game.platform_ui.settings_button.get_theme_font("font") == ThemeDB.fallback_font,"settings dialog and button explicitly use Korean-capable font in web builds")
	check(observer.viewport.size == Vector2i(320,180) and observer.viewport.world_3d == game.get_world_3d(),"real low-resolution SubViewport shares the gameplay world")
	check(observer.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"hidden observer does not render")
	check(ThemeDB.fallback_font is FontVariation and ThemeDB.fallback_font.variation_opentype.get(TextServerManager.get_primary_interface().name_to_tag("wght")) == 550.0,"Korean/English variable font uses medium weight instead of Thin")
	# T03 real shoulder beam, reflected by the actual collision surface into the receiver.
	game.completed.assign(["T-01","T-02"])
	game.sync_demo()
	game.devices["T03-M1"].rotation_degrees.y = -45
	game.devices["T03-M1"]._sync_physics_transform()
	game.player.position = Vector3(30.66,0.03,15.38)
	game.camera.position = Vector3(0,11,4)
	game.camera.rotation_degrees = Vector3(-70,0,0)
	game.camera.size = 18
	await settle()
	game.player.firing = true
	game.laser.update_beam(game.player.get_emitter_origin(),Vector3(31,1.15,5),true,0.25)
	var snapshot: Array[Dictionary] = game.laser.observation_snapshot()
	check(snapshot.size() == game.laser.last_segment_count and snapshot.size() >= 2,"observer snapshot uses the exact rendered physical segments")
	var last: Dictionary = snapshot.back()
	check(last.terminal and last.collider_id == game.devices["T03-RN"].get_instance_id() and last.reflection_count == 1,"last endpoint is the receiver after reflection, not the first mirror or original direction")
	check(last.receiver_accepted and not last.receiver_active,"actual accepted hit reports charging before required duration")
	var original_endpoint: Vector3 = last.to
	snapshot.back().to = Vector3.ZERO
	check(game.laser.observation_snapshot().back().to == original_endpoint,"snapshot consumers cannot mutate the tracer's data")
	check(observer.offscreen(original_endpoint),"real reflected endpoint is outside player camera")
	var follow_pose: Transform3D = game.camera.global_transform
	sample()
	check(game.camera.global_transform.is_equal_approx(follow_pose),"observer never moves the player camera")
	check(observer.visible and observer.selected.to == original_endpoint,"offscreen endpoint shows exactly one actual camera view")
	check(game.devices["T04-RN"].visual.layers == observer.MAIN_ONLY and not observer.proxy_ids.has(game.devices["T04-RN"].get_instance_id()),"unhit neighboring receiver is excluded from the observer render")
	check(observer.proxy_ids.has(game.devices["T03-RN"].get_instance_id()) and observer.proxy_ids.has(game.devices["T03-M1"].get_instance_id()),"only terminal receiver and preceding actual mirror are rendered as device silhouettes")
	check(observer.caption.text.contains("CHARGING"),"observer does not falsely announce receiver active")
	check(observer.get_global_rect().intersection(game.hud_panel.get_global_rect()).size == Vector2.ZERO,"observer does not cover objective HUD")
	check(not game.minimap_panel.visible or not observer.get_global_rect().intersects(game.minimap_panel.get_global_rect()),"observer does not cover minimap")
	var before_pointer: Vector2 = game.player.pointer_position
	var previous_touch_visibility: bool = game.touch_controls.visible
	game.touch_controls.visible = true
	var panel_touch := InputEventScreenTouch.new()
	panel_touch.index = 72
	panel_touch.position = observer.get_global_rect().get_center()
	panel_touch.pressed = true
	game.touch_controls._input(panel_touch)
	check(game.player.pointer_position == before_pointer and not game.touch_controls.contacts.has(72),"new touch on observer does not redirect the existing beam or start a world gesture")
	game.touch_controls.visible = previous_touch_visibility
	var panel_click := InputEventMouseButton.new()
	panel_click.position = observer.get_global_rect().get_center()
	panel_click.button_index = MOUSE_BUTTON_LEFT
	panel_click.pressed = true
	game._input(panel_click)
	check(game.suppress_fire_until_release and not game.player.firing,"click on observer suppresses a new handheld shot until release")
	game.restore_fire_state()
	game.player.firing = true
	check(game.blocked_by_ui(observer.get_global_rect().get_center()),"observer captures clicks instead of selecting or firing at the world")
	await capture("t03_reflected_receiver")
	game.laser.update_beam(game.player.get_emitter_origin(),Vector3(31,1.15,5),true,0.9)
	sample()
	check(observer.caption.text.contains("RECEIVER ACTIVE") and game.completed.has("T-03"),"actual receiver latch and tutorial completion are preserved")
	var sound: AudioStreamWAV = game.feedback.make_mechanical_sound()
	check(sound.data.size() == 22050 and sound.data.decode_s16(160) != 0,"mechanical feedback contains generated non-silent PCM audio (playback listening unverified)")
	check(game.feedback.emitted_events > 0 and not game.demo_doors["D-T04"].visible,"feedback follows real activation without delaying physical gate unlock")
	game.feedback._process(0.3)
	await capture("receiver_power_feedback")
	var requests: int = observer.render_requests
	sample(0.4)
	check(observer.render_requests-requests <= 6,"observer rendering requested at approximately 12 Hz, not every physics frame")
	# Endpoint moves into view: release hysteresis, no full-screen camera following.
	var main_pose: Transform3D = game.camera.global_transform
	game.camera.global_position = original_endpoint+Vector3(0,11,4)
	game.camera.look_at(original_endpoint,Vector3.UP)
	game.camera.reset_physics_interpolation()
	game.camera.force_update_transform()
	await process_frame
	if visual: await RenderingServer.frame_post_draw
	sample(0.35)
	check(not observer.visible,"onscreen terminal endpoint hides observer")
	game.camera.global_transform = main_pose
	game.camera.reset_physics_interpolation()
	await process_frame
	if visual: await RenderingServer.frame_post_draw
	sample()
	check(observer.visible,"offscreen again restores observer")
	game.laser.update_beam(Vector3.ZERO,Vector3.ZERO,true,0.1)
	sample()
	check(not observer.visible,"an empty physical path hides an active observer instead of displaying stale contact")
	game.laser.update_beam(game.player.get_emitter_origin(),Vector3(31,1.15,5),true,0.1)
	sample()
	for dimensions in [Vector2i(1920,1080),Vector2i(1440,1080)]:
		root.size = dimensions
		await process_frame
		game.platform_ui.select_mode("MOBILE")
		game.player.set_physics_process(false)
		game.player.firing = true
		sample()
		observer.place()
		var safe := true
		for rect in game.touch_controls.buttons.values():
			safe = safe and not observer.get_global_rect().intersects(rect)
		check(safe,"observer does not overlap mobile controls at "+str(dimensions))
		await capture("mobile_"+str(dimensions.x))
	game.platform_ui.select_mode("COMPUTER")
	game.player.set_physics_process(false)
	game.player.firing = false
	game.laser.update_beam(Vector3.ZERO,Vector3.RIGHT,false,0.01)
	sample(0.5)
	check(observer.visible,"firing stop retains last frame for 0.8 seconds")
	sample(0.4)
	check(not observer.visible and observer.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,"retained frame fades and rendering stops")
	game.player.firing = true
	sample()
	check(not observer.visible,"firing flag without a real path cannot invent an observation")
	# Separate physical splitter fixture, in an otherwise empty portion of the same world.
	var splitter: OpticalDevice = game._create_device("splitter","Observer Split Fixture",Vector3(110,0,10),Vector3(0.26,2.3,2.2),PI/4,Color.CYAN)
	var receiver: OpticalDevice = game._create_device("receiver","Observer Receiver Fixture",Vector3(110,0,17),Vector3(1,2.1,1),0,Color.CYAN)
	receiver.required_seconds = 0.2
	await settle()
	game.laser.update_beam(Vector3(105,1.15,10),Vector3(110,1.15,10),true,0.3)
	var split: Array[Dictionary] = game.laser.observation_snapshot()
	var branches := {}
	var energy := 0.0
	for segment in split:
		if segment.terminal:
			branches[segment.branch_id] = true
			energy += float(segment.energy)
	check(branches.has("0/T") and branches.has("0/R") and is_equal_approx(energy,1.0),"splitter leaf IDs stay distinct and conserve the existing 50/50 energy")
	var weak_source: Array[Dictionary] = [{"source_id":"a02-dock","origin":Vector3(105,1.15,10),"direction":Vector3.RIGHT,"active":true,"energy":0.15,"channel":"red"}]
	game.laser.update_beam(Vector3(105,1.15,10),Vector3(110,1.15,10),true,0.3,"red",weak_source)
	var rejected_branch := false
	for segment in game.laser.observation_snapshot():
		if segment.source_id == "a02-dock" and segment.collision_type == "receiver": rejected_branch = not segment.receiver_accepted
	check(rejected_branch,"receiver acceptance is per branch, not copied from another valid source hitting the same device")
	var choice: Dictionary = observer.choose(split,false)
	check(choice.collision_type == "receiver" and choice.receiver_active and choice.source_id == "player","actual receiver branch wins deterministic selection")
	for i in range(5): check(observer.choose(split,false).branch_id == choice.branch_id,"stable branch selection "+str(i))
	sample()
	await capture("split_receiver")
	var prism: OpticalDevice = game._create_device("prism","Observer Prism Fixture",Vector3(145,0,100),Vector3(1.7,2.2,1.4),deg_to_rad(8),Color.CYAN)
	await settle()
	game.laser.update_beam(Vector3(142,1.15,99.9),Vector3(146,1.15,99.9),true,0.1,"white")
	var spectra: Array[Dictionary] = game.laser.observation_snapshot()
	var spectral_ids := {}
	var spectral_energy := 0.0
	for segment in spectra:
		if segment.terminal:
			spectral_ids[segment.branch_id] = true
			spectral_energy += float(segment.energy)
	check(spectral_ids.has("0/red") and spectral_ids.has("0/green") and spectral_ids.has("0/blue") and is_equal_approx(spectral_energy,1.0),"physical prism preserves RGB branch identities and energy conservation")
	# Real source IDs also survive an additional dock emission in the same frame.
	var dock_sources: Array[Dictionary] = [{"source_id":"a02-dock","origin":Vector3(170,1.15,100),"direction":Vector3.RIGHT,"active":true,"energy":1.0,"channel":"red"}]
	game.laser.update_beam(Vector3(105,1.15,10),Vector3(110,1.15,10),true,0.3,"red",dock_sources)
	check(observer.choose(game.laser.observation_snapshot(),true).source_id == "player","player source takes precedence over concurrent dock source")
	game.player.firing = false
	game.player.position = Vector3(12,0.03,48)
	game.a02_lab.docked = true
	game.a02_lab.emitting = true
	game.laser.update_beam(Vector3.ZERO,Vector3.RIGHT,false,0.1,"red",dock_sources)
	sample()
	check(observer.visible and observer.selected.source_id == "a02-dock","engaged A02 dock source is observable when no handheld beam is firing")
	game.player.position = Vector3(5,0.03,8)
	sample(0.9)
	check(not observer.visible,"dock beam is not observed from an unrelated room")
	game.a02_lab.docked = false
	game.a02_lab.emitting = false
	game.player.firing = true
	receiver.reset_device()
	receiver.minimum_energy = 0.8
	game.laser.update_beam(Vector3(105,1.15,10),Vector3(110,1.15,10),true,0.3)
	sample()
	check(observer.caption.text.contains("REJECTED") and not receiver._hit_this_frame,"a real receiver contact with insufficient energy never reports active or charging")
	# Range limit is not a wall contact.
	game.laser.update_beam(Vector3(140,1.15,50),Vector3(150,1.15,50),true,0.1)
	check(not game.laser.observation_snapshot().back().did_hit and game.laser.observation_snapshot().back().collision_type == "range_limit","no collision at distance cap is explicitly marked range limit")
	sample()
	check(observer.caption.text.contains("NO CONTACT"),"range cap never claims a real collision")
	observer.set_fallback(true)
	sample()
	check(not observer.image.visible and observer.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and observer.caption.text.contains("XYZ"),"2D data fallback renders no secondary world camera")
	await capture("data_fallback")
	observer.set_fallback(false)
	# Overlay and console lifecycle.
	game.control_mode = true
	observer._process(0.1)
	check(not observer.visible,"console camera immediately hides observer")
	game.control_mode = false
	game.a02_lab.enter_control()
	check(game.camera.cull_mask & observer.OBSERVER_ONLY == 0 and game.camera.cull_mask & observer.MAIN_ONLY != 0,"A02 console preserves main-only device visibility and excludes observation proxies")
	game.a02_lab.exit_control()
	sample()
	game.is_paused_overlay = true
	observer._process(0.1)
	check(not observer.visible,"pause immediately hides observer")
	game.is_paused_overlay = false
	game.ending_elapsed = 0
	sample()
	check(not observer.visible,"demo ending hides observer")
	game.ending_elapsed = -1
	game.player.firing = false
	game.laser.update_beam(Vector3.ZERO,Vector3.RIGHT,false,0.1)
	game.platform_ui.select_mode("MOBILE")
	check(game.touch_controls.visible,"MOBILE exposes existing touch controls")
	game.player.touch_movement = Vector2.ONE
	game.player.touch_firing = true
	game.platform_ui.select_mode("COMPUTER")
	check(not game.touch_controls.visible and game.player.touch_movement == Vector2.ZERO and not game.player.touch_firing,"COMPUTER hides touch UI and cancels held input")
	var code := InputEventKey.new()
	code.keycode = KEY_V
	code.pressed = true
	game._input(code)
	check(not game.overview,"V cannot enable an ordinary exploration overview")
	# Exercise the actual Computer keyboard/mouse path, including an actual held click.
	var old_position: Vector3 = game.player.position
	var move := InputEventKey.new()
	move.keycode = KEY_W
	move.pressed = true
	Input.parse_input_event(move)
	Input.flush_buffered_events()
	game.player._physics_process(0.1)
	check(game.player.position.z < old_position.z,"Computer WASD still moves the character")
	move.pressed = false
	Input.parse_input_event(move)
	Input.flush_buffered_events()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = Vector2(900,500)
	mouse.pressed = true
	mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	game.player._physics_process(0.1)
	check(game.player.firing,"Computer held left click fires acquired L07")
	mouse.pressed = false
	mouse.button_mask = 0
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	game.player._physics_process(0.1)
	game.platform_ui.open()
	check(game.platform_ui.is_open() and not game.player.is_physics_processing(),"settings suspends gameplay while choosing input")
	await capture("input_choice")
	var select_event := InputEventKey.new()
	select_event.keycode = KEY_C
	select_event.pressed = true
	game.platform_ui._input(select_event)
	check(not game.platform_ui.is_open() and game.platform_ui.mode == "COMPUTER","accessible keyboard mode selection exits modal")
	game.platform_ui.settings_path = "user://observer_test_preferences.cfg"
	game.platform_ui.persistent = true
	game.platform_ui.select_mode("MOBILE")
	var config := ConfigFile.new()
	check(config.load(game.platform_ui.settings_path) == OK and config.get_value("input","mode") == "MOBILE","platform preference saved separately from progress")
	var reloaded: CanvasLayer = preload("res://scripts/input_preferences.gd").new()
	reloaded.settings_path = game.platform_ui.settings_path
	root.add_child(reloaded)
	reloaded.setup(game,true)
	check(reloaded.mode == "MOBILE" and not reloaded.is_open(),"saved mode reload skips the first-run choice and restores touch UI")
	reloaded.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.platform_ui.settings_path))
	game.platform_ui.persistent = false
	game.queue_free()
	await process_frame
	print("OBSERVER: %d checks / %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
