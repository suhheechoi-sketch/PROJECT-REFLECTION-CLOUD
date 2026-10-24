extends SceneTree
## Runs the implemented B-01, B-02, high-output demo lane, and C-01 paths in the facility.

const MainScene = preload("res://scenes/main.tscn")
var failures := 0
var game: Variant


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL representative puzzle: " + message)
		failures += 1


func _device(prefix: String) -> OpticalDevice:
	for item in game.get_tree().get_nodes_in_group("optical_devices"):
		if item is OpticalDevice and (item as OpticalDevice).display_name.begins_with(prefix):
			return item as OpticalDevice
	return null


func _run() -> void:
	game = MainScene.instantiate()
	game.exploration_save_path = "user://reflection_puzzle_v51_test.json"
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	await physics_frame
	await physics_frame

	var basic_receiver := _device("R-B01")
	game.laser.update_beam(Vector3(50, 1.15, -12), Vector3(67, 1.15, -12), true, 0.85)
	_check(basic_receiver != null and basic_receiver.receiver_active, "B-01 sends the portable 100% beam through G-B01 to its 200% receiver automatically.")
	if basic_receiver != null:
		_check(is_equal_approx(_device("G-B01").amplifier_input_energy, 1.0), "B-01's amplifier records the actual incoming 100% power.")

	var high_receiver := _device("R-B03")
	game.laser.update_beam(Vector3(51, 1.15, -18), Vector3(70, 1.15, -18), true, 0.85)
	_check(high_receiver != null and high_receiver.receiver_active, "The high-output B lane reaches its 300% receiver through the fixed ×3 amplifier.")
	var wedge_receiver := _device("R-B-WEDGE")
	game.laser.update_beam(Vector3(71, 1.15, -8), Vector3(87, 1.15, -8), true, 0.85, "red")
	_check(wedge_receiver != null and wedge_receiver.receiver_active, "The rotatable wedge amplifier redirects the doubled ray into the direction receiver.")
	var white_source := _device("W-B02")
	var prism := _device("P-01")
	var spectral_receivers: Array[OpticalDevice] = [_device("R-B 적색"), _device("R-B 녹색"), _device("R-B 청색")]
	_check(white_source != null and not white_source.source_active, "The fixed B-02 white source waits for an input beam.")
	game.laser.update_beam(Vector3(50.5, 1.15, 0), Vector3(70, 1.15, 0), true, 2.1, "red")
	_check(spectral_receivers[0].receiver_progress == 0.0 and not spectral_receivers[0].receiver_active, "Monochromatic red cannot solve the simultaneous RGB receiver group.")
	_check(not spectral_receivers[1].receiver_active and not spectral_receivers[2].receiver_active, "The portable light remains a single color after the prism.")
	game.laser.update_beam(Vector3(46, 1.15, 0), Vector3(52, 1.15, 0), true, 0.1, "red")
	_check(white_source != null and white_source.source_active, "The fixed white source starts when the portable beam reaches its input.")
	game.player.position = Vector3(52, 0.03, 0)
	game._physics_process(0.2)
	_check(not spectral_receivers.all(func(device: OpticalDevice) -> bool: return device.receiver_active), "The initial prism angle leaves the RGB receivers unsatisfied.")
	for id in ["T-01", "T-02", "T-03", "T-04"]:
		game.progression.advance_tutorial(id)
	game.progression.restore_circuit("A")
	game._on_progression_changed()
	game.player.position = Vector3(59, 0.03, 1.5)
	game._interact()
	_check(game.selected_device == prism, "The player can select P-01 before aligning the spectral paths.")
	game._rotate_selected(2)
	game._rotate_selected(1, true)
	_check(absf(rad_to_deg(prism.rotation.y) - 31.0) < 0.01, "Coarse and fine wheel turns set the B-02 prism's 31° solution.")
	await physics_frame
	game._physics_process(2.1)
	_check(spectral_receivers.all(func(device: OpticalDevice) -> bool: return device.receiver_active), "The fixed white source, G-01, and aligned P-01 solve B-02 through actual RGB paths.")
	_check(game.progression.restored_circuits.has("B"), "The three simultaneous color inputs restore B through the normal callbacks.")

	var relay_a := _device("R-C1")
	var relay_b := _device("R-C2")
	game.laser.update_beam(Vector3(-5, 1.1, 53), Vector3(10, 1.1, 53), true, 2.1)
	_check(relay_a != null and relay_a.receiver_active, "C-01's splitter transmits a 50% straight branch to the first parallel relay.")
	_check(relay_b != null and relay_b.receiver_active, "C-01's plate reflects a 50% branch to the second parallel relay.")
	_check(game.progression.restored_circuits.has("C"), "Both real C-01 outputs restore the circuit through the normal receiver callbacks.")

	print("Representative puzzle checks: %d failure(s)." % failures)
	quit(0 if failures == 0 else 1)
