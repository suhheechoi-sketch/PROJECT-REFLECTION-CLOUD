extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Lab = preload("res://scripts/a01_lab.gd")

func _initialize() -> void:
	call_deferred("run")

func capture(game: Node3D, filename: String) -> void:
	game.player.reset_physics_interpolation()
	game._update_room_visibility()
	game._update_nearby_prompt()
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + filename + ".png")

func run() -> void:
	var game = Main.instantiate()
	game.exploration_save_path = "user://a01_visual_review.json"
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.intro_veil.visible = false
	for id in ["T-01", "T-02", "T-03", "T-04"]:
		game.progression.advance_tutorial(id)
	game.player.set_emitter_acquired(true)
	for index in range(3):
		game.player.position = Lab.ORIGIN + Lab.SERVICE_POINTS[index]
		game.selected_device = null
		game._interact()
		game._rotate_selected(-3 if index == 0 else 3)
		await capture(game, "a01_m%d_service" % (index + 1))
	game.player.position = Lab.SPAWN
	await physics_frame
	await physics_frame
	var start: Vector3 = game.player.get_emitter_origin()
	game.laser.update_beam(start, start + Vector3.FORWARD * 20, true, 1.3)
	game._sync_progression_gates()
	await capture(game, "a01_play_solution")
	# Separate review-only overview; the playable camera configuration is untouched.
	game.player.position = Lab.ORIGIN + Vector3(10, 0.03, 7.5)
	game.camera.size = 21
	await capture(game, "a01_overview")
	print("A01 GPU captures saved to artifacts/a01_*.png")
	quit()
