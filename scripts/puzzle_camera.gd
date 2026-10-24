extends Node
const Pointer = preload("res://scripts/camera_pointer.gd")
## One physics-tick camera writer. Transform interpolation stays on the existing
## player/camera hierarchy; no competing render-frame transform interpolation.
const PUZZLE_LAYER := 1 << 19
const EXPLORE_SIZE := 17.0
const OFFSET := Vector3(0, 8, 2.911761874)
const ROOM := Rect2(-65, 9.3, 24, 16.4)
var game: Node3D
var overview := false
var framing := false
var manual_explore := false
var last_selected: OpticalDevice
var original_mask := 0
var previous_player_position := Vector3.ZERO
var markers: Array[Label] = []

func setup(world: Node3D) -> void:
	game = world
	process_physics_priority = 10
	process_mode = Node.PROCESS_MODE_PAUSABLE
	original_mask = game.camera.cull_mask
	previous_player_position = game.player.global_position
	for child in game.get_children():
		if String(child.name).begins_with("A01 ") or child == game.a01_lab or child == game.player or child == game.laser or (child is OpticalDevice and child in game.a01_lab.mirrors) or child == game.a01_lab.receiver:
			_tag(child)
	_tag_lights(game)
	_tag_local_meshes(game)
	for text in ["M1", "M2", "M3", "R-A01"]:
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 21)
		label.add_theme_color_override("font_color", Color("7df4e1"))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.visible = false
		game.hud_root.add_child(label)
		markers.append(label)

func _tag(node: Node) -> void:
	if node is VisualInstance3D:
		node.layers |= PUZZLE_LAYER
	for child in node.get_children():
		_tag(child)

func _tag_lights(node: Node) -> void:
	# Godot culls light instances with the camera mask too. Preserve the same
	# lighting while excluding the surrounding room geometry.
	if node is Light3D:
		node.layers |= PUZZLE_LAYER
	for child in node.get_children():
		_tag_lights(child)

func _tag_local_meshes(node: Node) -> void:
	if node == game.room_occlusion:
		return
	# Keep existing props (including collidable consoles) inside the room visible.
	# Full mesh bounds are checked so a large slab cannot reveal another room.
	if node is MeshInstance3D:
		var bounds: AABB = node.get_aabb()
		var contained := true
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					var point: Vector3 = node.global_transform * Vector3(x, y, z)
					contained = contained and ROOM.has_point(Vector2(point.x, point.z))
		if contained:
			node.layers |= PUZZLE_LAYER
	for child in node.get_children():
		_tag_local_meshes(child)

func in_room() -> bool:
	return ROOM.has_point(Vector2(game.player.global_position.x, game.player.global_position.z))

func toggle() -> void:
	if game.optical_control != null and game.optical_control.control_mode:
		return
	if in_room():
		overview = not overview
		manual_explore = not overview
	else:
		overview = false
		game._show_status("전체 보기는 A-01 퍼즐실 안에서 V로 전환합니다.")

func safe_rect() -> Rect2:
	var size: Vector2 = game.get_viewport().get_visible_rect().size
	# Use actual HUD bounds, including expanded guidance, rather than assuming
	# a resolution or fitting devices underneath a UI panel.
	var top: float = game.hud_panel.get_global_rect().end.y + 18
	if game.minimap_panel.visible:
		top = maxf(top, game.minimap_panel.get_global_rect().end.y + 18)
	var bottom := 36.0
	if game.info_panel.visible:
		bottom = size.y - game.info_panel.get_global_rect().position.y + 18
	return Rect2(Vector2(28, top), Vector2(size.x - 56, maxf(100, size.y - top - bottom)))

func fit_pose() -> Dictionary:
	var camera: Camera3D = game.camera
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	# Room perimeter includes all service positions, devices, and possible beam
	# segments. Height covers mirrors/labels, not only their floor origins.
	for x in [ROOM.position.x, ROOM.end.x]:
		for z in [ROOM.position.y, ROOM.end.y]:
			for y in [0.0, 3.2]:
				var point := Vector3(x, y, z)
				var projected := Vector2(point.dot(right), point.dot(up))
				low = low.min(projected)
				high = high.max(projected)
	var rect := safe_rect()
	var viewport: Vector2 = game.get_viewport().get_visible_rect().size
	var probe: Vector3 = game.player.global_position
	var k := camera.unproject_position(probe).distance_to(camera.unproject_position(probe + right)) * camera.size
	var size := maxf(EXPLORE_SIZE, maxf((high.x - low.x) * k / rect.size.x, (high.y - low.y) * k / rect.size.y) * 1.05)
	var center := Vector3(ROOM.get_center().x, 1.6, ROOM.get_center().y)
	var bias := rect.get_center() - viewport * 0.5
	var focus := center - right * bias.x * size / k + up * bias.y * size / k
	return {"position": focus + OFFSET, "size": size}

func _physics_process(delta: float) -> void:
	if game == null:
		return
	if not in_room():
		overview = false
		manual_explore = false
	if game.selected_device != last_selected:
		last_selected = game.selected_device
		manual_explore = false
	var selected: bool = game.selected_device != null and game.selected_device in game.a01_lab.mirrors
	framing = in_room() and (overview or (selected and not manual_explore))
	var camera: Camera3D = game.camera
	var target := OFFSET
	var target_size := EXPLORE_SIZE
	if framing:
		var pose := fit_pose()
		target = pose.position - game.player.global_position
		target_size = pose.size
		camera.cull_mask = PUZZLE_LAYER
	if camera.cull_mask == PUZZLE_LAYER:
		_tag(game.laser) # Keep lazy beam meshes visible during the return transition too.
	var weight := 1.0 - exp(-8.0 * delta)
	if framing:
		# Cancel the parent's movement before easing in world space. Otherwise
		# a moving player would drag the supposedly room-centered overview.
		var previous_world := camera.position + previous_player_position
		camera.position = previous_world.lerp(target + game.player.global_position, weight) - game.player.global_position
	else:
		camera.position = camera.position.lerp(target, weight)
	previous_player_position = game.player.global_position
	camera.size = lerpf(camera.size, target_size, weight)
	if not framing and camera.position.distance_to(OFFSET) < 0.015 and absf(camera.size - EXPLORE_SIZE) < 0.015:
		camera.position = OFFSET
		camera.size = EXPLORE_SIZE
		camera.cull_mask = original_mask
	game._update_compact_hud()

func _process(_delta: float) -> void:
	if game == null:
		return
	var devices: Array = game.a01_lab.mirrors.duplicate()
	devices.append(game.a01_lab.receiver)
	for index in range(markers.size()):
		var label := markers[index]
		label.visible = framing and not game.fullmap_overlay.visible and not game.help_panel.visible and not game.is_paused_overlay
		if not label.visible:
			continue
		var device: Node3D = devices[index]
		var point: Vector3 = device.global_position + Vector3.UP * 2.75
		label.position = Pointer.screen_position(game.camera, point) + Vector2(12, -12)
		label.modulate = Color("ffd075") if device == game.selected_device else Color.WHITE
		if game.optical_control != null and game.optical_control.authorized() and index < 3:
			label.text = "● M%d" % (index + 1)
			label.modulate = Color.WHITE
			label.add_theme_color_override("font_color", Color("ffd075") if device == game.optical_control.hovered or device == game.selected_device else Color("7df4e1"))
		else:
			label.text = "M%d" % (index + 1) if index < 3 else "R-A01"
			label.add_theme_color_override("font_color", Color("7df4e1"))
