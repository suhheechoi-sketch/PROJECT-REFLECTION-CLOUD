extends SceneTree
## Checks fixed camera framing and door-graph room visibility without changing collision or map fog.

const MainScene = preload("res://scenes/main.tscn")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL room visibility: " + message)
		failures += 1


func _run() -> void:
	var game: Variant = MainScene.instantiate()
	game.exploration_save_path = "user://reflection_room_visibility_test.json"
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	await physics_frame
	game.explored_cells.clear()
	game.current_cells.clear()
	game._update_map_views()

	_check(game.camera.get_parent() == game.player, "The camera follows the interpolated player transform.")
	_check(is_equal_approx(game.camera.size, 17.0), "Exploration uses a slightly wider fixed orthographic view.")
	_check(game.camera.unproject_position(game.player.global_position).distance_to(game.get_viewport().get_visible_rect().size * 0.5) < 1.0, "Player feet remain centered in the orthographic view.")
	_check(game.camera.position.y > 4.5, "The camera clears the facility's 4.5m walls.")
	_check(game.camera.rotation.is_equal_approx(Vector3(deg_to_rad(-70.0), 0.0, 0.0)), "The camera angle remains fixed.")
	_check(ProjectSettings.get_setting("physics/common/physics_interpolation", false), "Godot physics interpolation is enabled.")
	_check(not (game.get_node("WorldEnvironment") as WorldEnvironment).environment.fog_enabled, "World-space fog is disabled while map exploration fog remains separate.")
	_check(game.room_occlusion.current_room_id == "t_main", "The starting tutorial room is identified from the player's position.")
	_check(game.room_occlusion.is_accessible("t_main"), "The current room remains visible.")
	_check(not game.room_occlusion.is_accessible("hub"), "A closed assessment door hides H.")
	_check(game.room_occlusion.get_door_state("tutorial_gate") == "LOCKED", "An unavailable tutorial gate is classified as locked.")
	await create_timer(0.3).timeout
	_check(is_equal_approx(game.room_occlusion.rooms["hub"]["mask"].transparency, 0.0), "An inaccessible room fades to an opaque black mask.")
	_check(game.room_occlusion.rooms["hub"]["mask"].visible, "The unexplored room's black floor is rendered.")
	var hub_floor: GeometryInstance3D = game.get_node("HUB FLOOR 38x34m").get_child(0)
	_check(hub_floor.transparency == 0.0, "Shared slabs never disappear from centroid-based room assignment.")
	_check(game.room_occlusion._point_revealed(Vector3(-15, 0, -15)), "The current tutorial room is carved out of the overlapping locked hub mask.")
	for room in game.room_occlusion.rooms.values():
		if not room.mask.visible or room.mask.mesh.get_surface_count() == 0:
			continue
		var vertices: PackedVector3Array = room.mask.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for index in range(0, vertices.size(), 3):
			var center: Vector3 = room.mask.global_transform * ((vertices[index] + vertices[index + 1] + vertices[index + 2]) / 3.0)
			_check(not game.room_occlusion._point_revealed(center), "Black mask triangle overlaps a reachable room.")

	for tutorial_id in ["T-01", "T-02", "T-03"]:
		game.progression.advance_tutorial(tutorial_id)
	game._sync_progression_gates()
	await physics_frame
	await physics_frame
	game._update_room_visibility()
	_check(game.room_occlusion.is_accessible("t04"), "Opening the training gate reveals only its connected room.")
	_check(not game.room_occlusion.is_accessible("hub"), "The assessment exit remains closed after the mirror tutorial.")
	_check(game.room_occlusion.get_door_state("tutorial_gate") == "OPEN", "An opened tutorial gate is classified as open.")

	game.progression.advance_tutorial("T-04")
	game._sync_progression_gates()
	await physics_frame
	await physics_frame
	game._update_room_visibility()
	_check(game.room_occlusion.is_accessible("a01"), "T-04 reveals the A entrance wing without completing A-01.")
	_check(not game.room_occlusion.is_accessible("hub"), "H remains behind the separate lobby access door.")
	game.a_lobby_visited = true
	game._sync_progression_gates()
	await physics_frame
	await physics_frame
	game._update_room_visibility()
	_check(game.room_occlusion.is_accessible("hub"), "Entering the A lobby reveals the connected hub.")
	_check(not game.room_occlusion.is_accessible("b01"), "The B lab stays hidden before circuit A is restored.")
	await create_timer(0.3).timeout
	_check(not game.room_occlusion.rooms["hub"]["mask"].visible, "An accessible room's black floor mask is removed.")
	_check(hub_floor != null and hub_floor.transparency <= 0.01, "The H room fades back in after its doorway opens.")

	game.progression.restore_circuit("A")
	game._sync_progression_gates()
	await physics_frame
	await physics_frame
	game._update_room_visibility()
	_check(game.room_occlusion.is_accessible("b01") and game.room_occlusion.is_accessible("c_corridor"), "Circuit A independently opens the B and C routes.")
	_check(game.room_occlusion.get_door_state("area_b") == "OPEN", "Progression gates report their live collision state.")

	var c_gate: CollisionShape3D = game.area_gates["area_c"]["shape"]
	c_gate.disabled = false
	game._update_room_visibility()
	_check(game.room_occlusion.get_door_state("area_c") == "CLOSED", "An unlocked but physically closed door is classified as closed.")
	_check(not game.room_occlusion.is_accessible("c_corridor"), "A closed H-C door stops visibility while no alternate route is open.")
	c_gate.disabled = true
	game._update_room_visibility()

	game.progression.restore_circuit("C")
	game._sync_progression_gates()
	await physics_frame
	await physics_frame
	var b_position := Vector3(54.0, 0.03, 0.0)
	game.room_occlusion.refresh(b_position, game._room_gate_unlock_states())
	c_gate.disabled = false
	game.room_occlusion.refresh(b_position, game._room_gate_unlock_states())
	await physics_frame
	await physics_frame
	_check(game.room_occlusion.is_accessible("c02") and game.room_occlusion.is_accessible("c_corridor"), "The open B-C maintenance shortcut reveals C even with H-C closed.")

	var closed_c_hit := _ray_hits(game, Vector3(0, 1.4, 16), Vector3(0, 1.4, 18))
	_check(closed_c_hit, "Room masks leave the closed C gate's physical collision intact.")
	_check(game.minimap_view.cells.size() == game.explored_cells.size(), "Room reveal does not change discovered-cell fog on the minimap.")
	_check(not game.minimap_view.cells.has(Vector2i(27, 0)), "The undiscovered B cells remain hidden on the minimap.")
	_check(game.room_occlusion.get_children().all(func(node: Node) -> bool: return node is MeshInstance3D), "Room occluders contain visuals only and add no physics bodies.")

	var absolute_save := ProjectSettings.globalize_path(game.exploration_save_path)
	if FileAccess.file_exists(game.exploration_save_path):
		DirAccess.remove_absolute(absolute_save)
	print("Room visibility checks: %d failure(s)." % failures)
	quit(0 if failures == 0 else 1)


func _ray_hits(game: Variant, start: Vector3, finish: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(start, finish, 4)
	return not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _find_room_visual(game: Variant, room_id: String, body_name: String) -> GeometryInstance3D:
	for record in game.room_occlusion._visuals_by_room[room_id]:
		var visual: GeometryInstance3D = record["visual"]
		if visual.get_parent().name == body_name:
			return visual
	return null
