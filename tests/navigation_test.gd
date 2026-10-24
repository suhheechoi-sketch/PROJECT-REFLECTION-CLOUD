extends SceneTree
## Checks physical access gates, route ordering, and the one-room A entrance vestibule.
const MainScene = preload("res://scenes/main.tscn")
var failures := 0
var game: Variant


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL navigation: " + message)
		failures += 1


func _hit(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 4)
	return not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	await physics_frame
	var player: CharacterBody3D = game.player
	var state: Variant = game.progression
	_check(not game.hub_gate_shape.disabled, "T-04 keeps the A entrance closed before completion.")
	_check(not game.area_gates["a_lobby_to_hub"]["shape"].disabled, "The A vestibule does not expose H before A is entered.")
	_check(_hit(Vector3(-11, 1.4, 0), Vector3(-9, 1.4, 0)), "Closed vestibule connector physically blocks the hub.")
	for id in ["T-01", "T-02", "T-03", "T-04"]:
		state.advance_tutorial(id)
	await physics_frame
	await physics_frame
	_check(game.hub_gate_shape.disabled, "T-04 opens the A entrance without requiring circuit A.")
	_check(not game.area_gates["area_b"]["shape"].disabled, "B remains locked until circuit A is restored.")
	game.a_lobby_visited = true
	game._sync_progression_gates()
	await physics_frame
	await physics_frame
	_check(game.area_gates["a_lobby_to_hub"]["shape"].disabled, "Entering A opens the H connector without solving A-01.")
	_check(not _hit(Vector3(-11, 1.4, 0), Vector3(-9, 1.4, 0)), "Opened vestibule connector is physically traversable.")
	_check(game._area_id_at(Vector3(-15, 0, 0)) == "area_a_lobby", "The vestibule is identified as the A entrance lobby.")
	_check(game._area_id_at(Vector3(-30, 0, 10)) == "area_a", "The west wing is identified as A.")
	_check(game._area_id_at(Vector3(54, 0, 0)) == "area_b", "The east wing is identified as B.")
	_check(game._area_id_at(Vector3(0, 0, 53)) == "area_c", "The south wing is identified as C.")
	state.restore_circuit("A")
	await physics_frame
	await physics_frame
	_check(game.area_gates["area_b"]["shape"].disabled and game.area_gates["area_c"]["shape"].disabled, "A opens both B and C independently.")
	_check(not _hit(Vector3(18, 1.4, 0), Vector3(20, 1.4, 0)), "The B access opens through its actual wall aperture.")
	state.restore_circuit("C")
	game._sync_progression_gates()
	await physics_frame
	await physics_frame
	_check(state.is_area_unlocked("archive"), "Progression marks D unlocked after any second circuit.")
	_check(game.area_gates["shortcut_b"]["shape"].disabled and game.area_gates["shortcut_c"]["shape"].disabled, "Either B or C opens both maintenance shortcut doors.")
	_check(game.area_gates["archive"]["shape"].disabled, "Two circuits unlock D.")
	_check(not game.area_gates["control_entry"]["shape"].disabled, "F remains locked until B is also restored.")
	_check(not game.area_gates["d_f_shortcut"]["shape"].disabled and not game.area_gates["d_f_shortcut_f"]["shape"].disabled, "The D-F optional link stays closed while F is locked.")
	state.restore_circuit("B")
	game._sync_progression_gates()
	await physics_frame
	await physics_frame
	_check(game.area_gates["control_entry"]["shape"].disabled, "A, B, and C unlock F.")
	_check(game.area_gates["d_f_shortcut"]["shape"].disabled and game.area_gates["d_f_shortcut_f"]["shape"].disabled, "The D-F optional link opens once both D and F are available.")
	_check(state.is_area_unlocked("sealed") == false, "E remains hidden without two unauthorized receivers and D's record.")
	print("Navigation checks: %d failure(s)." % failures)
	quit(0 if failures == 0 else 1)
