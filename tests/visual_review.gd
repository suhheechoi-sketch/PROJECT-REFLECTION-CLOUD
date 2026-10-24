extends SceneTree
## Rendered review poses, not a save file or completion proof.
const MainScene = preload("res://scenes/main.tscn")
const REVIEW_DIR := "res://tools/validation/v5_1_review"

func _initialize() -> void:
	call_deferred("_run")

func _capture(game: Node3D, filename: String, position: Vector3, view_size: float, _focus: Vector3) -> void:
	game.set_physics_process(false)
	var player: Variant = game.get("player")
	player.set_physics_process(false)
	player.position = position
	player.reset_physics_interpolation()
	game.call("_update_room_visibility")
	var camera: Camera3D = game.get("camera")
	camera.size = view_size
	game.call("_update_objectives")
	game.call("_update_nearby_prompt")
	await create_timer(0.3).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(REVIEW_DIR + "/" + filename + ".png")
	if result != OK:
		push_error("Could not save review image: " + filename)
		quit(1)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	var game: Variant = MainScene.instantiate()
	game.exploration_save_path = "user://reflection_visual_review_v51.json"
	root.add_child(game)
	await process_frame
	game.intro_veil.visible = false
	await _capture(game, "01_isolation", Vector3(-21, 0.03, -15), 13.5, Vector3(-13, 0, -14))
	for id in ["T-01", "T-02", "T-03", "T-04"]:
		game.progression.advance_tutorial(id)
	game.player.set_emitter_acquired(true)
	for index in range(3):
		game.a01_lab.mirrors[index].rotate_steps(-3 if index == 0 else 3)
	game.player.position = preload("res://scripts/a01_lab.gd").SPAWN
	await physics_frame
	await physics_frame
	var start: Vector3 = game.player.get_emitter_origin()
	game.laser.update_beam(start, start + Vector3.FORWARD * 20, true, 1.3)
	await _capture(game, "02_a01", preload("res://scripts/a01_lab.gd").SPAWN, 15.5, Vector3.ZERO)
	game.a_lobby_visited = true
	game._sync_progression_gates()
	game.progression.restore_circuit("A")
	game.laser.update_beam(start, start + Vector3.RIGHT, false, 0.01)
	game._on_progression_changed()
	await _capture(game, "03_hub_powered", Vector3(-2, 0.03, 0), 15.5, Vector3(0, 0, 0))
	game.laser.update_beam(Vector3(50, 1.15, -12), Vector3(70, 1.15, -12), true, 0.3, "red")
	await _capture(game, "04_b01_amplifier", Vector3(52, 0.03, -12), 13.5, Vector3(56, 0, -12))
	game.laser.update_beam(Vector3(71, 1.15, -8), Vector3(87, 1.15, -8), true, 0.3, "red")
	await _capture(game, "05_b01_wedge_refraction", Vector3(72, 0.03, -8), 13.5, Vector3(76, 0, -9))
	game.white_spectrum_source.source_active = true
	var prism: OpticalDevice = game.get_tree().get_nodes_in_group("optical_devices").filter(func(device: OpticalDevice) -> bool: return device.display_name.begins_with("P-01"))[0]
	prism.rotation.y = deg_to_rad(31.0)
	prism._sync_physics_transform()
	await physics_frame
	var fixed_source: Array[Dictionary] = [{"origin": game.white_spectrum_source.global_position + Vector3(0.45, 1.15, 0), "direction": Vector3.RIGHT, "channel": "white", "energy": 1.0, "active": true}]
	game.laser.update_beam(Vector3.ZERO, Vector3.ZERO, false, 0.2, "red", fixed_source)
	await _capture(game, "06_b02_rgb", Vector3(58, 0.03, 1.8), 14.0, Vector3(61, 0, 2.3))
	game.laser.update_beam(Vector3(-5, 1.1, 53), Vector3(10, 1.1, 53), true, 0.2, "red")
	await _capture(game, "07_c01_splitter", Vector3(-3.5, 0.03, 53), 13.5, Vector3(1.0, 0, 54))
	game._update_exploration(0.3)
	game._update_map_views()
	await _capture(game, "08_minimap_exploration", Vector3(-21, 0.03, -15), 13.5, Vector3(-16, 0, -14))
	print("Rendered review images saved to tools/validation/v5_1_review.")
	quit(0)
