extends RefCounted
## Reuses the A01 V-view direction, fitting the same room into unobstructed HUD space.
static func room_rect(stage: String) -> Rect2:
	return {"A-01":Rect2(32,28,22,20),"A-02":Rect2(6,28,24,22),"A-03":Rect2(6,54,28,24)}[stage]

static func enter(game: Node3D) -> void:
	game.set_meta("console_minimap_visible",game.minimap_panel.visible)
	game.minimap_panel.visible = false

static func fit(game: Node3D, stage: String) -> void:
	var rect: Rect2 = {"A-01":Rect2(34.5,31.5,18,15),"A-02":Rect2(8,33.5,22,15.5),"A-03":Rect2(8.5,56.5,24,20)}[stage]
	var view: Camera3D = game.camera
	var focus := Vector3(rect.get_center().x,1.4,rect.get_center().y)
	var offset := Vector3(0,32,11)
	view.global_position = focus+offset
	view.look_at(focus,Vector3.UP)
	var viewport: Vector2 = game.get_viewport().get_visible_rect().size
	var top: float = game.hud_panel.get_global_rect().end.y+20
	if game.minimap_panel.visible: top = maxf(top,game.minimap_panel.get_global_rect().end.y+20)
	var safe := Rect2(40,top,viewport.x-80,maxf(120,viewport.y-260-top))
	var right := view.global_basis.x
	var up := view.global_basis.y
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for x in [rect.position.x,rect.end.x]:
		for z in [rect.position.y,rect.end.y]:
			for y in [0.0,3.2]:
				var p := Vector3(x,y,z)
				var projected := Vector2(p.dot(right),p.dot(up))
				low = low.min(projected)
				high = high.max(projected)
	var projection := view.get_camera_projection()
	var k: float = absf(projection.x.x)*viewport.x*0.5*view.size
	view.size = maxf(18,maxf((high.x-low.x)*k/safe.size.x,(high.y-low.y)*k/safe.size.y)*1.04)
	var center := (low+high)*0.5
	focus += right*(center.x-focus.dot(right))+up*(center.y-focus.dot(up))
	var bias := safe.get_center()-viewport*0.5
	focus += -right*bias.x*view.size/k+up*bias.y*view.size/k
	view.global_position = focus+offset
	view.reset_physics_interpolation()
	if game.wall_visibility != null: game.wall_visibility.console_room = room_rect(stage)

static func restore_walls(game: Node3D) -> void:
	if game.has_meta("console_minimap_visible"):
		game.minimap_panel.visible = game.get_meta("console_minimap_visible")
		game.remove_meta("console_minimap_visible")
	if game.wall_visibility != null: game.wall_visibility.console_room = Rect2()

static func pick(game: Node3D, pixel: Vector2, allowed: Array, touch := false) -> OpticalDevice:
	var pointer = preload("res://scripts/camera_pointer.gd")
	var ray: Dictionary = pointer.ray(game.camera,pixel)
	var query := PhysicsRayQueryParameters3D.create(ray.origin,ray.origin+ray.direction*100,2)
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var device: OpticalDevice = hit.get("collider") as OpticalDevice
		return device if device in allowed else null
	if not touch: return null
	# Touch target in screen pixels only: never enlarge the physical optical surface.
	var radius: float = 28.0/maxf(game.get_viewport().get_screen_transform().get_scale().x,0.1)
	var closest: OpticalDevice
	for mirror in allowed:
		var distance: float = pointer.screen_position(game.camera,mirror.position+Vector3.UP*1.4).distance_to(pixel)
		if distance < radius:
			radius = distance
			closest = mirror
	return closest
