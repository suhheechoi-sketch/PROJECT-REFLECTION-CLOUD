extends SceneTree
## Development entry only: normal game remains at T-01. No puzzle is pre-solved.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.exploration_save_path = "user://reflection_a01_playtest.json"
	root.add_child(game)
	for id in ["T-01", "T-02", "T-03", "T-04"]:
		game.progression.advance_tutorial(id)
	game.player.set_emitter_acquired(true)
	game.player.position = preload("res://scripts/a01_lab.gd").SPAWN
	game.player.reset_physics_interpolation()
	game.a_lobby_visited = true
	game._on_progression_changed()
	game._update_room_visibility()
	game._show_status("A-01 검수 시작 · 노란 점검 위치에서 E / 휠 · R 초기화")
