extends SceneTree
## Independent render comparisons; never writes the normal exploration save.
const Main = preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var mode := "baseline"
	if not OS.get_cmdline_user_args().is_empty():
		mode = OS.get_cmdline_user_args()[0]
	var game = Main.instantiate()
	game.exploration_save_path = "user://render_diagnosis.json"
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.intro_veil.visible = false
	game.player.position = Vector3(-21, 0.03, -15)
	game.player.reset_physics_interpolation()
	game._update_room_visibility()
	await create_timer(0.4).timeout
	if mode == "A":
		for room in game.room_occlusion.rooms.values():
			room.mask.visible = false
		for records in game.room_occlusion._visuals_by_room.values():
			for record in records:
				record.visual.transparency = record.base_transparency
		for record in game.room_occlusion._lights:
			record.light.visible = true
	if mode == "B":
		shadows_off(game)
	if mode == "C" and game.get("wall_visibility") != null:
		game.wall_visibility.enabled = false
	if mode == "D":
		game.camera.reparent(game, true)
		game.camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if mode in ["65", "70", "75"]:
		var angle := float(mode)
		game.camera.rotation_degrees.x = -angle
		game.camera.position = Vector3(0, 8, 8 / tan(deg_to_rad(angle)))
	await create_timer(0.4).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/diagnosis_%s.png" % mode)
	print("DIAGNOSIS ", mode, " room=", game.room_occlusion.current_room_id,
		" player_screen=", game.camera.unproject_position(game.player.global_position + Vector3.UP))
	quit()

func shadows_off(node: Node) -> void:
	if node is Light3D:
		node.shadow_enabled = false
	for child in node.get_children():
		shadows_off(child)
