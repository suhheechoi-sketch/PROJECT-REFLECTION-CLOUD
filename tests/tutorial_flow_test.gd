extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _settle_physics() -> void:
	# process_frame can run several times before the next physics tick (e.g. CI).
	# Resume after a completed physics tick, including deferred gate/shape updates.
	await physics_frame
	await physics_frame


func _run() -> void:
	var game: Variant = MainScene.instantiate()
	root.add_child(game)
	await _settle_physics()
	var progression: Variant = game.get("progression")
	var player := game.get("player") as CharacterBody3D
	_check(progression.get_current_tutorial_id() == "T-01", "The playable scene starts at T-01.")
	_check(not game.get("tutorial_receiver").receiver_enabled, "T-02 receiver stays inactive before its step.")
	_check(not game.get("tutorial_final_receiver").receiver_enabled, "T-04 receiver stays inactive before its step.")
	_check(not player.get("has_emitter"), "The subject wakes without the portable emitter.")
	game.call("_interact")
	_check(progression.get_current_tutorial_id() == "T-01", "T-01 cannot be skipped before moving.")

	player.global_position += Vector3(1.5, 0.0, 0.0)
	game.call("_process_tutorial")
	_check(game.get("tutorial_move_completed"), "T-01 records the requested movement.")
	player.global_position = Vector3(-18.6, 0.03, -15.0)
	game.call("_interact")
	_check(progression.get_current_tutorial_id() == "T-02", "The nearby terminal advances T-01.")
	_check(not game.get("tutorial_receiver").receiver_enabled, "T-02 waits for physical emitter collection.")
	player.global_position = Vector3(-21, 0.03, -15)
	game.call("_interact")
	_check(not player.get("has_emitter"), "Emitter cannot be collected remotely.")
	player.global_position = Vector3(-18.6, 0.03, -17.0)
	game.call("_interact")
	_check(player.get("has_emitter"), "E at the rack collects the portable emitter.")
	_check(game.get("tutorial_receiver").receiver_enabled, "Collection enables the calibration receiver.")
	player.global_position = Vector3(-18.6, 0.03, -15.0)

	await _settle_physics()
	var laser: Variant = game.get("laser")
	var beam_start: Vector3 = player.get_emitter_origin()
	laser.update_beam(beam_start, beam_start + Vector3(8.0, 0.0, 0.0), true, 1.0)
	_check(game.get("tutorial_receiver").receiver_active, "The real beam activates the T-02 receiver.")
	_check(progression.get_current_tutorial_id() == "T-03", "The tutorial receiver advances to T-03.")
	_check(game.get("tutorial_mirror_receiver").receiver_enabled, "T-03 enables its direction receiver.")
	var single_receiver: Variant = game.get("tutorial_mirror_receiver")
	laser.update_beam(single_receiver.position + Vector3(-2, 1.15, 0), single_receiver.position + Vector3(0, 1.15, 0), true, 1.0)
	_check(not single_receiver.receiver_active, "T-03 rejects a direct-shot shortcut.")

	player.global_position = Vector3(-15.0, 0.03, -12.0)
	await _settle_physics()
	game.call("_interact")
	var wheel_event := InputEventMouseButton.new()
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_event.pressed = true
	game.call("_input", wheel_event)
	game.call("_input", wheel_event)
	game.call("_input", wheel_event)
	await _settle_physics()
	_check(is_equal_approx(game.get("tutorial_mirror").rotation.y, deg_to_rad(45.0)), "E selection and three wheel steps set the training mirror angle.")
	beam_start = player.get_emitter_origin()
	laser.update_beam(beam_start, beam_start + Vector3(8.0, 0.0, 0.0), true, 1.0)
	_check(game.get("tutorial_mirror_receiver").receiver_active, "The real reflected beam activates the T-03 receiver.")
	_check(progression.get_current_tutorial_id() == "T-04", "The reflected receiver advances to T-04.")
	_check(game.get("tutorial_gate").visible == false, "T-03 opens the physical tutorial gate.")
	await _settle_physics()
	_check(game.get("tutorial_gate_shape").disabled, "The opened tutorial gate stops blocking the player.")
	_check(game.get("tutorial_final_receiver").receiver_enabled, "T-04 enables the final assessment receiver.")
	_check(not progression.tutorial_completed, "T-03 alone does not complete the tutorial.")
	_check(not progression.is_area_unlocked("hub"), "The hub stays locked before the two-mirror test.")
	var final_receiver: Variant = game.get("tutorial_final_receiver")
	laser.update_beam(final_receiver.position + Vector3(-2, 1.15, 0), final_receiver.position + Vector3(0, 1.15, 0), true, 1.0)
	_check(not final_receiver.receiver_active, "T-04 rejects direct shots even from the required direction.")

	player.global_position = Vector3(-17.5, 0.03, -7.0)
	await _settle_physics()
	game.call("_interact")
	for _step in range(3):
		game.call("_input", wheel_event)
	await _settle_physics()
	_check(is_equal_approx(game.get("tutorial_assessment_mirror_a").rotation.y, deg_to_rad(45.0)), "T-04 accepts actual rotation input for the first mirror.")
	player.global_position = Vector3(-14.0, 0.03, -3.5)
	await _settle_physics()
	game.call("_interact")
	for _step in range(3):
		game.call("_input", wheel_event)
	await _settle_physics()
	_check(is_equal_approx(game.get("tutorial_assessment_mirror_b").rotation.y, deg_to_rad(45.0)), "T-04 accepts actual rotation input for the second mirror.")
	player.global_position = Vector3(-17.3, 0.03, -7.0)
	await _settle_physics()
	beam_start = player.get_emitter_origin()
	laser.update_beam(beam_start, beam_start + Vector3(15.0, 0.0, 0.0), true, 1.0)
	_check(laser.last_segment_count >= 3, "The T-04 beam travels through two mirror reflections.")
	_check(game.get("tutorial_final_receiver").receiver_active, "The twice-reflected beam activates the T-04 receiver.")
	_check(progression.tutorial_completed, "Activating the final assessment receiver completes the tutorial.")
	_check(progression.is_area_unlocked("hub"), "T-04 opens the hub.")
	_check(progression.is_area_unlocked("area_a"), "Tutorial completion enables the mirror wing.")
	await _settle_physics()
	_check(game.get("tutorial_assessment_gate_shape").disabled, "The completed assessment opens the A-wing gate.")
	_check(game.get("hub_gate_shape").disabled, "The completed assessment opens the hub gate.")
	_check(not progression.is_area_unlocked("area_b"), "The spectrum wing remains locked until circuit A.")

	if failures == 0:
		print("Tutorial flow checks passed.")
		quit(0)
	else:
		printerr("Tutorial flow checks failed: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: %s" % message)
		failures += 1
