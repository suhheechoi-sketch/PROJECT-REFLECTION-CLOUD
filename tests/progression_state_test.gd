extends SceneTree

const ProgressionState = preload("res://scripts/progression_state.gd")

var failures: int = 0


func _initialize() -> void:
	var state = ProgressionState.new()
	_check(state.get_current_tutorial_id() == "T-01", "Tutorial must start at T-01.")
	_check(not state.advance_tutorial("T-02"), "Tutorial cannot skip a step.")
	for step_id in ["T-01", "T-02", "T-03", "T-04"]:
		_check(state.advance_tutorial(step_id), "Expected ordered tutorial step %s." % step_id)
	_check(state.tutorial_completed, "T-04 must mark tutorial complete.")
	_check(state.is_area_unlocked("hub") and state.is_area_unlocked("area_a"), "T-04 must unlock the hub and A.")
	_check(not state.is_area_unlocked("area_b") and not state.is_area_unlocked("area_c"), "B and C remain locked until A.")

	state.restore_circuit("A")
	_check(state.is_area_unlocked("area_b") and state.is_area_unlocked("area_c"), "A must unlock B and C.")
	_check(not state.is_area_unlocked("archive"), "The archive needs two main circuits.")
	_check(not state.activate_spectrum_channel("red"), "One spectrum channel is not circuit B.")
	_check(not state.activate_spectrum_channel("green"), "Two spectrum channels are not circuit B.")
	_check(state.activate_spectrum_channel("blue"), "The third color channel completes spectrum calibration.")
	state.restore_circuit("B")
	_check(state.is_area_unlocked("archive"), "Two circuits must unlock the archive.")
	_check(not state.is_area_unlocked("control"), "The control room needs all three circuits.")
	state.restore_circuit("C")
	_check(state.is_area_unlocked("control"), "A, B, and C must unlock central control.")
	_check(not state.is_area_unlocked("sealed"), "The sealed wing needs a hidden circuit and a record.")
	state.discover_record("D-EMERGENCY_CONTROL")
	_check(not state.is_area_unlocked("sealed"), "The emergency record alone must not unlock the sealed wing.")
	state.activate_unauthorized_receiver("A-UNAUTHORIZED")
	_check(not state.is_area_unlocked("sealed"), "One unauthorized receiver is not enough.")
	state.activate_unauthorized_receiver("B-UNAUTHORIZED")
	_check(state.is_area_unlocked("sealed"), "Two unauthorized receivers plus the emergency record unlock the sealed wing.")
	_check(not state.activate_unauthorized_receiver("A-UNAUTHORIZED"), "The same unauthorized receiver cannot count twice.")
	_check(not state.activate_unauthorized_receiver("not-a-real-receiver"), "Unknown receiver IDs are rejected.")
	for order in [["A", "B", "C"], ["A", "C", "B"]]:
		var alternate = ProgressionState.new()
		for id in ["T-01", "T-02", "T-03", "T-04"]:
			alternate.advance_tutorial(id)
		alternate.restore_circuit(order[0])
		_check(alternate.is_area_unlocked("area_b") and alternate.is_area_unlocked("area_c"), "B and C both open immediately after A.")
		alternate.restore_circuit(order[1])
		_check(alternate.is_area_unlocked("archive"), "Either second circuit unlocks the archive.")
		alternate.restore_circuit(order[2])
		_check(alternate.is_area_unlocked("control"), "Either B/C order reaches the control room.")

	if failures == 0:
		print("Progression state checks passed.")
		quit(0)
	else:
		printerr("Progression state checks failed: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: %s" % message)
		failures += 1
