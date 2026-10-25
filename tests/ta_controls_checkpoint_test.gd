extends SceneTree
const Pointer = preload("res://scripts/camera_pointer.gd")
var game: Node3D
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL TA UX: "+message)
	else: print("PASS TA UX: "+message)
func settle() -> void:
	await physics_frame
	await physics_frame
func key(code: int,shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.shift_pressed = shift
	game._input(e)
func click(device: OpticalDevice) -> void:
	var e := InputEventMouseButton.new()
	e.position = Pointer.screen_position(game.camera,device.position+Vector3.UP*1.5)
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	game._input(e)
func wheel(fine := false) -> void:
	var e := InputEventMouseButton.new()
	e.position = Vector2(900,500)
	e.button_index = MOUSE_BUTTON_WHEEL_UP
	e.pressed = true
	e.shift_pressed = fine
	game._input(e)
func make_game() -> void:
	game = preload("res://scenes/ta_demo.tscn").instantiate()
	game.checkpoint_enabled = false
	game.save_path = "user://ta_ux_test.json"
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.a02_lab.set_physics_process(false)
func dispose() -> void:
	game.queue_free()
	await process_frame
func run() -> void:
	make_game()
	await settle()
	for id in ["T-01","T-02","T-03","T-04","T-04_TERMINAL_E"]: game.completed.append(id)
	game.sync_demo()
	game.player.set_emitter_acquired(true)
	game.player.position = Vector3(36,0.03,46)
	key(KEY_E)
	await settle()
	for id in ["A01-M1","A01-M2","A01-M3"]:
		click(game.devices[id])
		check(game.selected_device == game.devices[id],"A01 screen ray selects "+id)
		wheel()
		check(is_equal_approx(game.devices[id].rotation_degrees.y,15),"wheel 15 degrees "+id)
		wheel(true)
		check(is_equal_approx(game.devices[id].rotation_degrees.y,16),"Shift wheel 1 degree "+id)
	game.player.velocity = Vector3.ONE
	game.player._physics_process(0.1)
	check(game.player.velocity == Vector3.ZERO and not game.player.firing,"console blocks move and fire")
	key(KEY_ESCAPE)
	check(not game.control_mode and game.selected_device == null,"Esc exits A01 and clears selection")
	game.devices["A01-RN"].receiver_active = true
	game.complete("A-01")
	var lab: Node3D = game.a02_lab
	game.player.position = Vector3(9,0.03,47)
	key(KEY_E)
	await settle()
	check(lab.control_mode,"A02 E console")
	for mirror in lab.mirrors:
		click(mirror)
		check(lab.selected == mirror,"A02 screen ray selects "+mirror.name)
	key(KEY_ESCAPE)
	game.player.position = Vector3(12,0.03,48)
	key(KEY_E)
	check(lab.docked and not game.player.has_emitter,"dock owns sole emitter")
	key(KEY_F)
	check(lab.sources().is_empty(),"F stops persistent beam")
	key(KEY_F)
	check(lab.sources().size() == 1,"F resumes persistent beam")
	key(KEY_R)
	check(not lab.docked and game.player.has_emitter and not lab.control.receiver_active,"R retries A02 and returns emitter")
	# Real shoulder origin and actual aim update, preserving the existing controller.
	game.player.position = Vector3(44.66,0.03,13.38)
	game.devices["T04-M1"].rotation_degrees.y = -45
	game.devices["T04-M2"].rotation_degrees.y = 45
	game.devices["T04-M1"]._sync_physics_transform()
	game.devices["T04-M2"]._sync_physics_transform()
	game.devices["T04-RN"].reset_device()
	game.devices["T04-RN"].receiver_enabled = true
	game.player.pointer_position = Pointer.screen_position(game.camera,Vector3(45,1.15,5))
	game.player._update_aim()
	await settle()
	game.laser.update_beam(game.player.get_emitter_origin(),game.player.aim_position,true,1.0)
	check(game.devices["T04-RN"].receiver_active,"real shoulder emitter and camera floor aim solve T04")
	# Trace from the real shoulder origin and real screen-to-floor aim for the other folded paths.
	for pair in [["T03-M1",-45],["A01-M1",-45],["A01-M2",45],["A01-M3",45],["A03-M4",-45]]:
		game.devices[pair[0]].rotation_degrees.y = pair[1]
		game.devices[pair[0]]._sync_physics_transform()
	game.devices["A03-RAIL"].position.x = 27
	game.devices["A03-RAIL"]._sync_physics_transform()
	await settle()
	for spec in [[Vector3(31,0,13),Vector3(31,0,5),"T03-RN"],[Vector3(36,0,43),Vector3(36,0,33),"A01-RN"],[Vector3(18,0,73),Vector3(18,0,66),"A03-RN"]]:
		game.player.position = spec[0]+Vector3(-0.34,0.03,0.38)
		game.player.pointer_position = Pointer.screen_position(game.camera,spec[1]+Vector3.UP*1.15)
		game.player._update_aim()
		var receiver: OpticalDevice = game.devices[spec[2]]
		receiver.receiver_enabled = true
		receiver.begin_laser_frame()
		var direction: Vector3 = game.player.aim_position-game.player.get_emitter_origin()
		direction.y = 0
		var segments: Array[Dictionary] = []
		game.laser._trace(game.player.get_emitter_origin(),direction.normalized(),"red",1.0,segments)
		check(receiver._hit_this_frame,"shoulder origin and screen aim hit "+spec[2])
	game.checkpoint_enabled = true
	game.save_checkpoint()
	await dispose()
	make_game()
	game.checkpoint_enabled = true
	game.load_checkpoint()
	game.sync_demo()
	await settle()
	check(game.loaded_checkpoint and game.next_stage() == "A-02","reload resumes next incomplete stage")
	check(game.player.has_emitter and not game.a02_lab.docked,"reload restores handheld L07 without duplicate")
	check(game.devices["A01-RN"].receiver_active and not game.restored,"reload keeps completed A01 without circuit restoration")
	key(KEY_R,true)
	check(game.completed.is_empty() and not game.player.has_emitter and not game.circuit_ready,"Shift R clears full progress and emitter")
	await dispose()
	make_game()
	game.checkpoint_enabled = true
	game.load_checkpoint()
	check(game.completed.is_empty() and not game.player.has_emitter,"cleared checkpoint persists")
	game.checkpoint_enabled = false
	await dispose()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ta_ux_test.json"))
	print("TA UX: %d checks / %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
