extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: " + message)
		failures += 1

func _run() -> void:
	var game: Variant = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	var player: Variant = game.player
	var state: Variant = game.progression
	for id in ["T-01", "T-02", "T-03", "T-04"]:
		state.advance_tutorial(id)
	player.set_emitter_acquired(true)
	game._on_progression_changed()
	player.position = preload("res://scripts/a01_lab.gd").SPAWN
	await physics_frame
	await physics_frame
	var relay: Variant = game.mirror_relay
	var laser: Variant = game.laser
	# A correct direction alone must not bypass the authored reflection route.
	laser.update_beam(Vector3(-50.5, 1.15, 19.5), Vector3(-45.5, 1.15, 19.5), true, 2.0)
	_check(not relay.receiver_active, "A-01 rejects direct irradiation from the correct side.")
	var mirrors: Array = []
	for device in get_nodes_in_group("optical_devices"):
		if device.display_name.begins_with("M-A01"):
			mirrors.append(device)
	_check(mirrors.size() == 3, "A-01 has three locally operable mirrors.")
	for index in range(3):
		player.position = preload("res://scripts/a01_lab.gd").ORIGIN + preload("res://scripts/a01_lab.gd").SERVICE_POINTS[index]
		game._interact()
		game._rotate_selected(-3 if index == 0 else 3)
	player.position = preload("res://scripts/a01_lab.gd").SPAWN
	await physics_frame
	await physics_frame
	var start: Vector3 = player.get_emitter_origin()
	laser.update_beam(start, start + Vector3.FORWARD * 20, true, 0.5)
	_check(not relay.receiver_active, "A-01 requires sustained illumination, not a pulse.")
	laser.update_beam(start, start + Vector3.FORWARD * 20, true, 0.8)
	_check(laser.last_segment_count == 4, "A-01 uses three physical reflections.")
	_check(relay.receiver_active and state.restored_circuits.has("A"), "A-01 real beam restores circuit A.")
	await physics_frame
	_check(game.area_gates["area_b"]["shape"].disabled and game.area_gates["area_c"]["shape"].disabled, "A opens both physical B/C doors.")
	_check(game.facility_art._powered, "Circuit restoration powers the hub rotor.")
	game._reset_current_puzzle()
	_check(state.restored_circuits.has("A"), "Local reset preserves completed circuits.")
	_check(player.position.distance_to(preload("res://scripts/a01_lab.gd").SPAWN) < 0.01, "Local reset returns player to a safe firing lane.")
	_check(game.selected_device == null, "Reset clears stale selection.")
	game._reset_all_progress()
	_check(not player.has_emitter and not player.emitter.visible, "Full reset restores emitter acquisition.")
	_check(state.get_current_tutorial_id() == "T-01" and not state.is_area_unlocked("hub"), "Full reset returns to isolation with locked progression.")
	_check(not relay.receiver_active and relay.receiver_progress == 0, "Full reset clears receiver latches and timers.")
	_check(not game.facility_art._powered, "Full reset powers down the hub.")
	_check(game.camera.size < 20.5, "Camera framing is closer than the old prototype.")
	print("Quality pass checks: %d failure(s)." % failures)
	quit(0 if failures == 0 else 1)
