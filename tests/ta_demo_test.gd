extends SceneTree
var game: Node3D
var failures := 0
var checks := 0
var visual := "--visual-review" in OS.get_cmdline_user_args()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL TA: "+message)
	else: print("PASS TA: "+message)
func settle() -> void:
	await physics_frame
	await physics_frame
func shot(point: Vector3,target: Vector3,seconds := 1.3) -> void:
	game.accepted_receiver_this_frame = ""
	game.laser.update_beam(point+Vector3.UP*1.15,target+Vector3.UP*1.15,true,seconds,"red")
	game.check_sequence_reentry()
func necessary(ids: Array,point: Vector3,target: Vector3,receiver: OpticalDevice) -> void:
	for id in ids:
		var mirror: OpticalDevice = game.devices[id]
		game.laser.ignore_rids.append(mirror.get_rid())
		receiver.reset_device()
		shot(point,target,1.3)
		check(not receiver.receiver_active,"physical path requires "+id)
		game.laser.ignore_rids.erase(mirror.get_rid())
func angles(ids: Array,values: Array) -> void:
	for i in range(ids.size()):
		game.devices[ids[i]].rotation_degrees.y = values[i]
		game.devices[ids[i]]._sync_physics_transform()
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._input(event)
func capture(label: String,point: Vector3) -> void:
	if not visual: return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/validation"))
	game.player.position = point
	game.room_id = game.current_room()
	game.camera.position = Vector3(0,16,5.82)
	game.camera.rotation_degrees = Vector3(-70,0,0)
	game.camera.size = 25
	game.update_demo_map(0.3)
	game.update_demo_hud(0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/validation/ta_"+label+".png")
func run() -> void:
	game = preload("res://scenes/ta_demo.tscn").instantiate()
	game.checkpoint_enabled = false
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.a02_lab.set_physics_process(false)
	await settle()
	check(game.next_stage() == "T-01","fresh start")
	await capture("start",Vector3(5,0.03,8))
	game.player.position = Vector3(7,0.03,8)
	key(KEY_E)
	check(game.completed.has("T-01"),"identity E")
	game.player.position = Vector3(18,0.03,7.5)
	key(KEY_E)
	check(game.player.has_emitter,"pickup E")
	shot(Vector3(18,0,12),Vector3(24,0,6))
	check(game.completed.has("T-02"),"T02 physical direct beam")
	angles(["T03-M1"],[-45])
	await settle()
	shot(Vector3(31,0,13),Vector3(31,0,5))
	check(game.completed.has("T-03"),"T03 one real reflection")
	await capture("t03_reflection",Vector3(30.66,0.03,13.38))
	angles(["T04-M1","T04-M2"],[-45,45])
	await settle()
	shot(Vector3(45,0,13),Vector3(45,0,5))
	check(game.completed.has("T-04"),"T04 two real reflections")
	check(not game.progression.tutorial_completed,"T04 receiver alone does not open A")
	game.player.position = Vector3(47,0.03,13.5)
	key(KEY_E)
	check(game.completed.has("T-04_TERMINAL_E"),"T04 exit terminal E")
	game.player.position = Vector3(36,0.03,46)
	key(KEY_E)
	check(game.control_mode,"A01 console E immediately enters")
	angles(["A01-M1","A01-M2","A01-M3"],[-45,45,45])
	key(KEY_ESCAPE)
	await settle()
	necessary(["A01-M1","A01-M2","A01-M3"],Vector3(36,0,43),Vector3(36,0,33),game.devices["A01-RN"])
	shot(Vector3(36,0,43),Vector3(36,0,33))
	check(game.completed.has("A-01"),"A01 physical three-mirror path")
	await capture("a01_solved",Vector3(35.66,0.03,43.38))
	check(not game.restored,"A01 never restores A circuit")
	var lab: Node3D = game.a02_lab
	for i in range(2):
		lab.mirrors[i].rotation_degrees.y = -45 if i == 0 else 45
		lab.mirrors[i]._sync_physics_transform()
	game.player.position = Vector3(12,0.03,48)
	key(KEY_E)
	await settle()
	check(lab.docked and not game.player.has_emitter,"same L07 transfers into dock")
	lab._physics_process(0.02)
	game.player.position = Vector3(25,0.03,48)
	lab.move_rail(4)
	check(is_equal_approx(lab.rail.position.x,19),"control receiver locks rail before irradiation")
	game.laser.update_beam(Vector3.ZERO,Vector3.RIGHT,false,0.8,"red",lab.sources())
	check(lab.control.receiver_active,"A02 two reflections unlock control")
	await capture("a02_control",Vector3(18,0.03,46))
	lab._physics_process(0.02)
	game.player.position = Vector3(25,0.03,48)
	key(KEY_E)
	for i in range(16): lab.move_rail(0.25)
	await settle()
	check(is_equal_approx(lab.rail.position.x,23),"A02 rail endpoint 4m")
	game.laser.update_beam(Vector3.ZERO,Vector3.RIGHT,false,1.3,"red",lab.sources())
	check(lab.receiver.receiver_active,"A02 third reflection final receiver")
	await capture("a02_rail",Vector3(24,0.03,45))
	lab._physics_process(0.02)
	if lab.receiver.receiver_active: game.complete("A-02")
	game.player.position = Vector3(12,0.03,48)
	key(KEY_E)
	check(not lab.docked and game.player.has_emitter,"emitter retrieval")
	angles(["A03-M1","A03-M2","A03-M3","A03-M4"],[-45,-45,45,-45])
	await settle()
	shot(Vector3(15,0,73),Vector3(15,0,62))
	check(game.sequence == 0,"out of order physical shot resets sequence")
	shot(Vector3(10,0,73),Vector3(10,0,60))
	check(game.sequence == 1,"A03 RO1 reflection")
	game.laser.update_beam(Vector3.ZERO,Vector3.RIGHT,false,0.1)
	game.check_sequence_reentry()
	shot(Vector3(10,0,73),Vector3(10,0,60))
	check(game.sequence == 0,"re-shooting a latched previous receiver resets order")
	shot(Vector3(10,0,73),Vector3(10,0,60))
	shot(Vector3(15,0,73),Vector3(15,0,62))
	check(game.sequence == 2,"A03 RO2 two reflections")
	await capture("a03_order",Vector3(14.66,0.03,73.38))
	game.player.position = Vector3(29.5,0.03,67.5)
	key(KEY_E)
	var wheel := InputEventMouseButton.new()
	wheel.position = Vector2(900,500)
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	for i in range(12): game._input(wheel)
	await settle()
	check(is_equal_approx(game.devices["A03-RAIL"].position.x,27),"A03 local rail reaches 3m endpoint")
	necessary(["A03-M4","A03-RAIL"],Vector3(18,0,73),Vector3(18,0,66),game.devices["A03-RN"])
	shot(Vector3(18,0,73),Vector3(18,0,66))
	check(game.completed.has("A-03") and game.circuit_ready,"A03 final ray sets READY")
	await capture("a03_ready",Vector3(27,0.03,68))
	check(not game.restored,"READY requires separate E")
	game.player.position = Vector3(47,0.03,64)
	key(KEY_E)
	check(game.restored and game.ending_elapsed >= 0,"restoration terminal E starts demo ending")
	game._physics_process(3.2)
	check(game.ending_label.text.contains("DEMO END"),"ending title")
	await capture("ending",Vector3(47,0.03,64))
	print("TA DEMO: %d checks / %d failure(s)" % [checks,failures])
	game.save_path = "user://ta_end_test.json"
	game.checkpoint_enabled = true
	game.save_checkpoint()
	game.hum.stop()
	game.tone.stop()
	game.queue_free()
	await process_frame
	var reloaded := preload("res://scenes/ta_demo.tscn").instantiate()
	reloaded.checkpoint_enabled = false
	reloaded.save_path = "user://ta_end_test.json"
	root.add_child(reloaded)
	await settle()
	if visual: await RenderingServer.frame_post_draw
	reloaded.checkpoint_enabled = true
	reloaded.load_checkpoint()
	check(reloaded.restored and reloaded.progression.restored_circuits.has("A"),"RESTORED survives restart")
	check(reloaded.ending_elapsed >= 3 and not reloaded.player.is_physics_processing(),"restart returns to stable ending screen")
	reloaded.queue_free()
	await process_frame
	if visual:
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ta_end_test.json"))
	print("TA FINAL: %d checks / %d failure(s)" % [checks,failures])
	quit(0 if failures == 0 else 1)
