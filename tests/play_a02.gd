extends SceneTree
## Development entry; normal main scene still starts at T-01.
func _initialize() -> void:
	call_deferred("start")
func start() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.exploration_save_path = "user://a02_development_map.json"
	root.add_child(game)
	for id in ["T-01", "T-02", "T-03", "T-04"]:
		game.progression.advance_tutorial(id)
	game.player.set_emitter_acquired(true)
	game.mirror_relay.activate_receiver()
	game.player.position = preload("res://scripts/a02_lab.gd").CONSOLE + Vector3(0, 0.03, 0)
	game.player.reset_physics_interpolation()
	game._show_status("A-02 개발 시작 · E 콘솔에서 거울 설정 → 발사기 거치 → 현장 레일 이동")
