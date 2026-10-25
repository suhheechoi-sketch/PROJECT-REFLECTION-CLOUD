extends PanelContainer
## One real low-resolution view of the terminal segment; never traces its own beam.
const WIDTH := 352.0
const HOLD_SECONDS := 0.8
const SAMPLE_SECONDS := 1.0/12.0
var game: Node3D
var viewport: SubViewport
var observer_camera: Camera3D
const MAIN_ONLY := 1 << 18
const OBSERVER_ONLY := 1 << 19
var known_devices := {}
var proxy_nodes: Array[Dictionary] = []
var proxy_ids: Array[int] = []
var observed_beam: MeshInstance3D
var contact: MeshInstance3D
var image: TextureRect
var caption: Label
var title: Label
var selected: Dictionary = {}
var retained := 0.0
var offscreen_time := 0.0
var onscreen_time := 0.0
var target_lock := 0.0
var sample_timer := 0.0
var render_requests := 0
var compact_map_hidden := false
var previous_map_visible := false
var fallback_2d := false
var active_source := false

func setup(world: Node3D) -> void:
	game = world
	name = "BeamObserver"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(WIDTH,0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("091b20")
	style.border_color = Color("70d7ce")
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel",style)
	var stack := VBoxContainer.new()
	add_child(stack)
	title = game._make_label("BEAM OBSERVER / LIVE",22,Color("a8efdf"))
	stack.add_child(title)
	viewport = SubViewport.new()
	viewport.name = "ObserverRenderTarget"
	viewport.size = Vector2i(320,180)
	viewport.world_3d = game.get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size = 0
	add_child(viewport)
	observer_camera = Camera3D.new()
	observer_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	observer_camera.near = 0.1
	observer_camera.far = 100
	viewport.add_child(observer_camera)
	observer_camera.current = true
	# This marker uses the actual endpoint and is visible only to the observer camera.
	game.camera.cull_mask &= ~(1 << 19)
	game.puzzle_camera.original_mask = game.camera.cull_mask
	observer_camera.cull_mask = 1 | (1 << 19)
	contact = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	sphere.radial_segments = 8
	sphere.rings = 4
	contact.mesh = sphere
	contact.layers = 1 << 19
	contact.material_override = game._emissive_material(Color("ffbd73"),1.3)
	contact.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	contact.material_override.no_depth_test = true
	contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(contact)
	observed_beam = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.035
	cylinder.bottom_radius = 0.035
	cylinder.radial_segments = 5
	observed_beam.mesh = cylinder
	observed_beam.layers = OBSERVER_ONLY
	observed_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(observed_beam)
	game.laser.set_meta("observer_layers",true)
	for label in game.find_children("*","Label3D",true,false): label.layers = MAIN_ONLY
	for station in game.get_children():
		if String(station.name).contains("Optical Control Console"): main_only(station)
	main_only(game.player.emitter)
	main_only(game.a02_lab.dock_mesh)
	ensure_device_layers()
	image = TextureRect.new()
	image.texture = viewport.get_texture()
	image.custom_minimum_size = Vector2(320,180)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(image)
	caption = game._make_label("",21,Color.WHITE)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size = Vector2(320,56)
	stack.add_child(caption)
	visible = false
	game.get_viewport().size_changed.connect(place)
	place()

func place() -> void:
	if game == null: return
	var screen := game.get_viewport().get_visible_rect().size
	var map: Rect2 = game.minimap_panel.get_global_rect()
	position = Vector2(screen.x-WIDTH-24,20)
	# On wide screens place beside, rather than over, the minimap.
	if position.x-WIDTH-24 > game.hud_panel.get_global_rect().end.x:
		position.x = map.position.x-WIDTH-16
	elif visible and not compact_map_hidden:
		previous_map_visible = game.minimap_panel.visible
		compact_map_hidden = true
		game.minimap_panel.visible = false

func offscreen(point: Vector3) -> bool:
	var view: Camera3D = game.camera
	if view.is_position_behind(point): return true
	var pixel := view.unproject_position(point)
	var rect := view.get_viewport().get_visible_rect().grow(-20)
	return not rect.has_point(pixel)

func priority(segment: Dictionary) -> float:
	return (100000.0 if segment.source_id == "player" else 0.0) + (10000.0 if segment.collision_type == "receiver" else 0.0) + (1000.0 if segment.did_hit else 0.0) + float(segment.energy)*10

func choose(snapshot: Array[Dictionary], allow_dock: bool) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for segment in snapshot:
		if not segment.terminal or (segment.to as Vector3).distance_squared_to(segment.from) < 0.001: continue
		if segment.source_id != "player" and not (allow_dock and segment.source_id == "a02-dock"): continue
		if offscreen(segment.to): candidates.append(segment)
	candidates.sort_custom(func(a,b):
		if priority(a) == priority(b):
			if not is_equal_approx(float(a.get("path_length",0)),float(b.get("path_length",0))): return float(a.get("path_length",0)) > float(b.get("path_length",0))
			return str(a.source_id)+str(a.branch_id) < str(b.source_id)+str(b.branch_id)
		return priority(a)>priority(b))
	if candidates.is_empty(): return {}
	# Keep a still-valid branch briefly; never freeze an obsolete endpoint.
	if target_lock > 0 and not selected.is_empty():
		for item in candidates:
			if item.source_id == selected.source_id and item.branch_id == selected.branch_id and priority(item) == priority(candidates[0]): return item
	return candidates[0]

func set_fallback(enabled: bool) -> void:
	fallback_2d = enabled
	image.visible = not enabled
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if enabled: queue_redraw()

func hide_now() -> void:
	visible = false
	retained = 0
	offscreen_time = 0
	onscreen_time = 0
	selected = {}
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if compact_map_hidden:
		game.minimap_panel.visible = previous_map_visible
		compact_map_hidden = false

func blocked() -> bool:
	return game.is_paused_overlay or game.control_mode or game.a02_lab.control_mode or game.ending_elapsed >= 0 or game.help_panel.visible or game.log_panel.visible or game.fullmap_overlay.visible or (game.platform_ui != null and game.platform_ui.is_open())

func _process(delta: float) -> void:
	if game == null: return
	if blocked():
		hide_now()
		return
	target_lock = maxf(0,target_lock-delta)
	sample_timer -= delta
	var dock: bool = game.a02_lab.docked and game.a02_lab.emitting and game.current_room() == "A-02"
	active_source = game.player.firing or dock
	if not active_source:
		if visible:
			retained -= delta
			modulate.a = clampf(retained/0.25,0,1)
			title.text = "BEAM OBSERVER / LAST FRAME"
			if retained <= 0: hide_now()
		return
	if sample_timer > 0: return
	var elapsed := maxf(delta,SAMPLE_SECONDS)
	sample_timer = SAMPLE_SECONDS
	ensure_device_layers()
	var snapshot: Array[Dictionary] = game.laser.observation_snapshot()
	if snapshot.is_empty():
		hide_now()
		return
	var next := choose(snapshot,dock)
	if next.is_empty():
		offscreen_time = 0
		onscreen_time += elapsed
		if onscreen_time >= 0.15: hide_now()
		return
	onscreen_time = 0
	offscreen_time += elapsed
	if offscreen_time < 0.10: return
	if selected.is_empty() or selected.source_id != next.source_id or selected.branch_id != next.branch_id: target_lock = 0.35
	selected = next
	retained = HOLD_SECONDS
	modulate.a = 1
	visible = true
	place()
	title.text = "BEAM OBSERVER / " + ("2D DATA" if fallback_2d else "LIVE")
	var status: String = {"wall":"WALL CONTACT","mirror":"MIRROR CONTACT","receiver":"RECEIVER CONTACT","range_limit":"RANGE LIMIT / NO CONTACT"}.get(selected.collision_type,str(selected.collision_type).to_upper()+" CONTACT")
	if selected.collision_type == "receiver":
		status = "RECEIVER ACTIVE" if selected.receiver_active else ("RECEIVER CHARGING" if selected.receiver_accepted else "RECEIVER / REJECTED")
	caption.text = "%s\n%s · %.0f%% · RFL %d" % [status,str(selected.channel).to_upper(),float(selected.energy)*100,int(selected.reflection_count)]
	if fallback_2d:
		caption.text += "\nXYZ %.1f / %.1f / %.1f\nLAST SEGMENT %.1fm" % [selected.to.x,selected.to.y,selected.to.z,selected.from.distance_to(selected.to)]
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		frame_segment(selected)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		render_requests += 1

func frame_segment(segment: Dictionary) -> void:
	var endpoint: Vector3 = segment.to
	contact.position = endpoint
	update_proxies(segment)
	var beam_offset: Vector3 = endpoint-segment.from
	observed_beam.position = (endpoint+segment.from)*0.5
	observed_beam.quaternion = Quaternion(Vector3.UP,beam_offset.normalized())
	observed_beam.mesh.height = maxf(0.01,beam_offset.length())
	observed_beam.material_override = game.laser.channel_materials.get(segment.channel)

	var start: Vector3 = segment.from
	# Entire last segment is used, with the endpoint favored in the composition.
	var focus := endpoint*0.65+start*0.35
	observer_camera.global_position = focus+Vector3(0,22,8)
	observer_camera.look_at(focus,Vector3.UP)
	var right := observer_camera.global_basis.x
	var up := observer_camera.global_basis.y
	var extent := endpoint-start
	observer_camera.size = maxf(6,maxf(absf(extent.dot(up))*1.8,absf(extent.dot(right))*1.0)+3)
	observer_camera.reset_physics_interpolation()

func main_only(node: Node) -> void:
	if node is GeometryInstance3D: node.layers = MAIN_ONLY
	for child in node.get_children(): main_only(child)

func ensure_device_layers() -> void:
	for device in get_tree().get_nodes_in_group("optical_devices"):
		var id := device.get_instance_id()
		if known_devices.has(id): continue
		main_only(device)
		known_devices[id] = true

func update_proxies(segment: Dictionary) -> void:
	var wanted: Array[int] = []
	if segment.collider_id != 0 and instance_from_id(segment.collider_id) is OpticalDevice: wanted.append(segment.collider_id)
	# The preceding real contact can be on an ancestor of a split/spectral branch.
	for item in game.laser.observation_snapshot():
		if item.source_id != segment.source_id or not str(segment.branch_id).begins_with(item.branch_id): continue
		if item.collider_id == 0 or not instance_from_id(item.collider_id) is OpticalDevice: continue
		if (item.to as Vector3).distance_to(segment.from) < 0.15 and not wanted.has(item.collider_id): wanted.append(item.collider_id)
	wanted.sort()
	if wanted != proxy_ids:
		for record in proxy_nodes: record.proxy.queue_free()
		proxy_nodes.clear()
		proxy_ids = wanted
		for id in wanted:
			var device = instance_from_id(id)
			if is_instance_valid(device): copy_visuals(device)
	for record in proxy_nodes:
		if not is_instance_valid(record.source):
			record.proxy.visible = false
			continue
		record.proxy.global_transform = record.source.global_transform
		record.proxy.visible = record.source.is_visible_in_tree()
		record.proxy.material_override = record.source.material_override

func copy_visuals(source: Node) -> void:
	var proxy: GeometryInstance3D
	if source is MeshInstance3D:
		proxy = MeshInstance3D.new()
		proxy.mesh = source.mesh
	elif source is MultiMeshInstance3D:
		proxy = MultiMeshInstance3D.new()
		proxy.multimesh = source.multimesh
	if proxy != null:
		proxy.layers = OBSERVER_ONLY
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		viewport.add_child(proxy)
		proxy_nodes.append({"source":source,"proxy":proxy})
	for child in source.get_children(): copy_visuals(child)
