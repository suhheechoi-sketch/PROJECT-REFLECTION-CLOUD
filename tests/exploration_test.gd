extends SceneTree
## Verifies local visibility, map privacy, and saved explored-cell restoration.
const MainScene = preload("res://scenes/main.tscn")
var failures := 0
var game: Variant


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL exploration: " + message)
		failures += 1


func _run() -> void:
	game = MainScene.instantiate()
	game.exploration_save_path = "res://tools/validation/exploration_test_save.json"
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	await physics_frame
	game.explored_cells.clear()
	game.current_cells.clear()
	game.discovered_areas.clear()
	game.visited_gate_ids.clear()
	game.discovered_gates.clear()
	game.visited_device_ids.clear()
	game.discovered_devices.clear()
	game.player.position = Vector3(-15, 0.03, -4)
	game.scan_timer = 0.0
	game._update_exploration(0.3)
	var near_cell := Vector2i(-8, -2)
	var beyond_t04 := Vector2i(-8, 0)
	var unknown_b := Vector2i(27, 0)
	_check(game.explored_cells.has(near_cell), "The current 2m floor cell is discovered.")
	_check(not game.explored_cells.has(beyond_t04), "A closed T-04 gate prevents discovery on its far side.")
	_check(not game.explored_cells.has(unknown_b), "A distant unvisited B room remains unknown.")
	_check(game.current_cells.has(near_cell), "Nearby visible floor is marked current.")
	_check(game.discovered_gates.has("T-04/H"), "A visible access door is recorded without revealing the room beyond it.")
	for id in ["T-01", "T-02", "T-03", "T-04"]:
		game.progression.advance_tutorial(id)
	await physics_frame
	await physics_frame
	game.scan_timer = 0.0
	game._update_exploration(0.3)
	_check(game.explored_cells.has(beyond_t04), "Opening the gate reveals its floor only after sight reaches it.")
	_check(not game.explored_cells.has(unknown_b), "Opening one training gate does not reveal remote rooms.")
	game._update_map_views()
	_check(game.minimap_view.cells.has(near_cell) and not game.minimap_view.cells.has(unknown_b), "The minimap receives explored cells only.")
	_check(game.fullmap_view.cells.has(beyond_t04) and not game.fullmap_view.cells.has(unknown_b), "The full map also omits undiscovered structure.")
	game._save_exploration()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.exploration_save_path))
	_check(saved is Dictionary and saved.get("cells", []).has("-8:0"), "The opened area is written to the exploration save.")
	game.explored_cells.clear()
	game.discovered_areas.clear()
	game.visited_gate_ids.clear()
	game.discovered_gates.clear()
	game.visited_device_ids.clear()
	game._load_exploration()
	_check(game.explored_cells.has(near_cell) and game.explored_cells.has(beyond_t04), "Explored cells persist across a reload.")
	_check(game.discovered_areas.has("tutorial"), "Visited area labels persist across a reload.")
	var absolute_save := ProjectSettings.globalize_path(game.exploration_save_path)
	if FileAccess.file_exists(game.exploration_save_path):
		DirAccess.remove_absolute(absolute_save)
	print("Exploration checks: %d failure(s)." % failures)
	quit(0 if failures == 0 else 1)
