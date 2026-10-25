extends Node3D

const ProgressionState = preload("res://scripts/progression_state.gd")
const DeviceArt = preload("res://assets/v5_1/device_visuals.gd")
const FacilityArt = preload("res://assets/v5_1/facility_visuals.gd")
const SurfaceFinish = preload("res://assets/v4_0/surface_finish.gd")
const MapView = preload("res://scripts/exploration_map.gd")
const RoomOcclusion = preload("res://scripts/room_occlusion.gd")

var player: ReflectionPlayer
var camera: Camera3D
var puzzle_camera: Node
var optical_control: Node
var hud_root: Control
var hud_panel: PanelContainer
var hud_details: VBoxContainer
var hud_summary: Label
var details_button: Button
var prompt_panel: PanelContainer
var info_panel: PanelContainer
var wall_visibility: Node3D
var laser: ReflectionLaser
var selected_device: OpticalDevice
var progression = ProgressionState.new()
var tutorial_start_position := Vector3.ZERO
var tutorial_move_completed := false
var tutorial_terminal: StaticBody3D
var tutorial_receiver: OpticalDevice
var tutorial_mirror: OpticalDevice
var tutorial_mirror_receiver: OpticalDevice
var tutorial_assessment_mirror_a: OpticalDevice
var tutorial_assessment_mirror_b: OpticalDevice
var tutorial_final_receiver: OpticalDevice
var tutorial_gate: StaticBody3D
var tutorial_gate_shape: CollisionShape3D
var tutorial_assessment_gate: StaticBody3D
var tutorial_assessment_gate_shape: CollisionShape3D
var hub_gate: StaticBody3D
var hub_gate_shape: CollisionShape3D
var area_gates: Dictionary = {}
var room_occlusion: RoomOcclusionSystem
var room_visibility_timer := 0.0
var spectrum_receivers: Array[OpticalDevice] = []
var status_label: Label
var tutorial_title_label: Label
var objective_label: Label
var navigation_label: Label
var prompt_label: Label
var map_panel: PanelContainer
var map_label: Label
var destination_panel: HBoxContainer
var destination_status: Label
var minimap_panel: PanelContainer
var minimap_view: ExplorationMapView
var fullmap_view: ExplorationMapView
var fullmap_overlay: ColorRect
var explored_cells: Dictionary = {}
var current_cells: Dictionary = {}
var discovered_areas: Dictionary = {}
var discovered_gates: Dictionary = {}
var discovered_devices: Dictionary = {}
var visited_gate_ids: Dictionary = {}
var visited_device_ids: Dictionary = {}
var nav_route: Array[Vector2i] = []
var nav_guidance := "주변 통로를 탐색하십시오."
var scan_timer := 0.0
var save_timer := 0.0
var selected_destination := "area_b"
var map_goal_position := Vector3.ZERO
var map_goal_known := false
var current_goal: Dictionary = {}
var exploration_save_path := "user://reflection_exploration_v51.json"
var help_panel: PanelContainer
var pause_panel: PanelContainer
var reticle: Label
var is_paused_overlay := false
var mirror_relay: OpticalDevice
var a02_lab: Node3D
var a01_lab: Node3D
var split_relay_a: OpticalDevice
var split_relay_b: OpticalDevice
var shutter_control_receiver: OpticalDevice
var test_shutter: OpticalDevice
var white_spectrum_source: OpticalDevice

var materials: Dictionary = {}
var facility_art: Node3D
var device_info_label: Label
var log_panel: PanelContainer
var log_label: Label
var system_logs: Array[String] = []
var intro_veil: ColorRect
var intro_elapsed := 0.0
var hub_discovered := false
var a_lobby_visited := false
const EMITTER_RACK := Vector3(-18.6, 0.0, -17.4)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_materials()
	_build_environment()
	_build_room()
	facility_art = FacilityArt.new()
	facility_art.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(facility_art)
	facility_art.build()
	_set_world_occluder_layers(facility_art)
	_disable_art_shadows(facility_art)
	_register_art_room_lights(facility_art)
	_build_devices()
	_build_player_and_camera()
	_build_laser()
	_build_ui()
	_build_room_occlusion()
	wall_visibility = preload("res://scripts/wall_visibility.gd").new()
	add_child(wall_visibility)
	wall_visibility.setup(self, player, camera)
	puzzle_camera = preload("res://scripts/puzzle_camera.gd").new()
	add_child(puzzle_camera)
	puzzle_camera.setup(self)
	optical_control = preload("res://scripts/optical_control.gd").new()
	add_child(optical_control)
	optical_control.setup(self)
	player.optical_control = optical_control
	player.station_control = a02_lab
	_load_exploration()
	progression.state_changed.connect(_on_progression_changed)
	tutorial_start_position = player.global_position
	_on_progression_changed()
	_update_room_visibility()
	_show_status("시스템 07: 장기 관찰 종료. 기억 검사 보류. 신원 단말기에 접근하십시오.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_exploration()


func _physics_process(delta: float) -> void:
	if player == null or is_paused_overlay:
		return
	var fixed_sources: Array[Dictionary] = a02_lab.sources()
	if white_spectrum_source != null and white_spectrum_source.source_active and _player_in_area("area_b"):
		fixed_sources.append({"origin": white_spectrum_source.global_position + Vector3(0.45, 1.15, 0), "direction": Vector3.RIGHT, "channel": "white", "energy": 1.0, "active": true})
	laser.update_beam(player.get_emitter_origin(), player.aim_position, player.firing and not is_paused_overlay, delta, player.emitter_channel, fixed_sources)
	intro_elapsed += delta
	intro_veil.color.a = maxf(0.0, 0.85 - intro_elapsed * 0.55)
	intro_veil.visible = intro_elapsed < 1.6
	if progression.tutorial_completed and not hub_discovered and player.position.x > -7.0 and absf(player.position.z) < 6.5:
		hub_discovered = true
		_show_status("시스템: 중앙 배광실. 회로 A 오프라인. 전력 복구 후 B·C를 원하는 순서로 탐색하십시오.")
	reticle.position = player.pointer_position - Vector2(8.0, 14.0)
	_process_tutorial()
	_update_objectives()
	_update_nearby_prompt()
	_sync_progression_gates()
	room_visibility_timer -= delta
	if room_visibility_timer <= 0.0:
		room_visibility_timer = 0.12
		_update_room_visibility()
	_update_exploration(delta)
	_update_map_views()
	save_timer += delta
	if save_timer >= 8.0:
		save_timer = 0.0
		_save_exploration()


func _input(event: InputEvent) -> void:
	if not is_paused_overlay and a02_lab != null and a02_lab.handle_input(event):
		return
	if is_paused_overlay and not (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				_interact()
			KEY_R:
				if event.shift_pressed:
					_reset_all_progress()
				else:
					_reset_current_puzzle()
			KEY_L:
				log_panel.visible = not log_panel.visible
			KEY_TAB:
				fullmap_overlay.visible = not fullmap_overlay.visible
			KEY_M:
				minimap_panel.visible = not minimap_panel.visible
			KEY_1:
				_select_destination("area_b")
			KEY_2:
				_select_destination("area_c")
			KEY_H, KEY_F1:
				help_panel.visible = not help_panel.visible
			KEY_V:
				if optical_control == null or not optical_control.control_mode:
					puzzle_camera.toggle()
			KEY_ESCAPE:
				if optical_control == null or not optical_control.escape():
					_toggle_pause()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and optical_control != null and optical_control.handle_pointer_click(event.position):
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_rotate_selected(1, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_rotate_selected(-1, event.shift_pressed)


func _build_materials() -> void:
	materials["floor"] = _material(Color(0.15, 0.165, 0.15), 0.18, 0.92)
	materials["wall"] = _material(Color(0.235, 0.245, 0.22), 0.12, 0.9)
	materials["dark"] = _material(Color(0.085, 0.095, 0.085), 0.4, 0.82)
	materials["rust"] = _material(Color(0.34, 0.17, 0.09), 0.32, 0.78)
	materials["yellow"] = _material(Color(0.85, 0.53, 0.12), 0.42, 0.48)
	materials["light"] = _emissive_material(Color(0.82, 0.12, 0.055), 1.3)
	materials["cyan"] = _emissive_material(Color(0.2, 0.64, 0.63), 0.9)
	materials["metal"] = _material(Color(0.31, 0.34, 0.32), 0.74, 0.3)
	materials["tutorial_floor"] = _material(Color(0.19, 0.24, 0.235), 0.1, 0.95)
	materials["hub_floor"] = _material(Color(0.22, 0.235, 0.205), 0.12, 0.9)
	materials["a_floor"] = _material(Color(0.26, 0.18, 0.12), 0.14, 0.92)
	materials["b_floor"] = _material(Color(0.11, 0.23, 0.25), 0.12, 0.9)
	materials["c_floor"] = _material(Color(0.27, 0.22, 0.12), 0.14, 0.92)
	materials["archive_floor"] = _material(Color(0.18, 0.16, 0.23), 0.12, 0.94)
	materials["sealed_floor"] = _material(Color(0.13, 0.16, 0.15), 0.12, 0.97)
	materials["control_floor"] = _material(Color(0.23, 0.14, 0.13), 0.18, 0.87)
	for key in ["floor", "wall", "dark", "rust", "metal"]:
		(materials[key] as StandardMaterial3D).albedo_texture = SurfaceFinish.texture(407, key != "wall")
		(materials[key] as StandardMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


func _material(color: Color, metal: float, rough: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = rough
	return material


func _emissive_material(color: Color, strength: float) -> StandardMaterial3D:
	var material := _material(color, 0.15, 0.55)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = strength
	return material


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.012, 0.018, 0.021)
	sky_material.sky_horizon_color = Color(0.06, 0.07, 0.065)
	sky_material.ground_bottom_color = Color(0.012, 0.014, 0.013)
	sky_material.ground_horizon_color = Color(0.04, 0.045, 0.04)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.39, 0.42, 0.38)
	environment.ambient_light_energy = 0.58
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	# Exploration blacking is room-driven; atmospheric fog must not reveal or obscure 3D spaces.
	environment.fog_enabled = false
	world.environment = environment
	add_child(world)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	key_light.light_color = Color(0.78, 0.82, 0.73)
	key_light.light_energy = 0.7
	key_light.shadow_enabled = true
	key_light.shadow_bias = 0.08
	key_light.shadow_normal_bias = 1.0
	key_light.directional_shadow_max_distance = 100.0
	add_child(key_light)


func _build_room() -> void:
	var facility_floor := _add_box("FACILITY FLOOR", Vector3(0, -0.22, -4), Vector3(190, 0.44, 180), materials["floor"], true, 1)
	facility_floor.set_meta("shared_backing_floor", true)
	_add_floor_zone("TUTORIAL FLOOR 45x24m", Vector3(-15, 0.035, -10), Vector3(45, 0.07, 24), materials["tutorial_floor"])
	_add_floor_zone("HUB FLOOR 38x34m", Vector3(0, 0.04, 0), Vector3(38, 0.08, 34), materials["hub_floor"])
	_add_floor_zone("A FLOOR 65x48m", Vector3(-51.5, 0.035, 17), Vector3(65, 0.07, 48), materials["a_floor"])
	_add_floor_zone("B FLOOR 70x50m", Vector3(54, 0.035, 0), Vector3(70, 0.07, 50), materials["b_floor"])
	_add_floor_zone("C FLOOR 75x56m", Vector3(0, 0.035, 53), Vector3(75, 0.07, 56), materials["c_floor"])
	_add_floor_zone("ARCHIVE FLOOR 40x30m", Vector3(0, 0.035, -38), Vector3(40, 0.07, 30), materials["archive_floor"])
	_add_floor_zone("SEALED FLOOR 45x34m", Vector3(-52, 0.035, -70), Vector3(45, 0.07, 34), materials["sealed_floor"])
	_add_floor_zone("CONTROL FLOOR 46x42m", Vector3(55, 0.035, -42), Vector3(46, 0.07, 42), materials["control_floor"])

	var wall_height := 4.5
	var wall_y := wall_height * 0.5
	_add_wall("NORTH PERIMETER", Vector3(0, 5, -94), Vector3(190, 10, 0.5))
	_add_wall("SOUTH PERIMETER", Vector3(0, 5, 86), Vector3(190, 10, 0.5))
	_add_wall("WEST PERIMETER", Vector3(-95, 5, -4), Vector3(0.5, 10, 180))
	_add_wall("EAST PERIMETER", Vector3(95, 5, -4), Vector3(0.5, 10, 180))

	# T rooms lead through a two-mirror assessment bay before entering the hub/A wing.
	_add_wall("TUTORIAL NORTH WALL", Vector3(-15, wall_y, -19), Vector3(15, wall_height, 0.45))
	_add_wall("TUTORIAL WEST WALL NORTH", Vector3(-22.5, wall_y, -17), Vector3(0.45, wall_height, 4))
	_add_wall("TUTORIAL WEST WALL SOUTH", Vector3(-22.5, wall_y, -10.8), Vector3(0.45, wall_height, 3.2))
	_add_wall("T ISOLATION BAY NORTH", Vector3(-30, wall_y, -19), Vector3(15, wall_height, 0.45))
	_add_wall("T ISOLATION BAY SOUTH", Vector3(-30, wall_y, -9.2), Vector3(15, wall_height, 0.45))
	_add_wall("T ISOLATION BAY WEST", Vector3(-37.5, wall_y, -14.1), Vector3(0.45, wall_height, 9.8))
	_register_open_map_gate("T MAINTENANCE ALCOVE GATE", "T-service", "정비실 출입문", "tutorial", Vector3(-22.5, 1.4, -14), Vector3(0.45, 2.8, 3.2))
	_add_wall("TUTORIAL EAST WALL", Vector3(-7.5, wall_y, -14.1), Vector3(0.45, wall_height, 9.8))
	_add_wall("T-04 WEST WALL", Vector3(-22.5, wall_y, -5.1), Vector3(0.45, wall_height, 8.2))
	_add_wall("TUTORIAL SOUTH WALL WEST", Vector3(-19.3, wall_y, -9.2), Vector3(5.4, wall_height, 0.45))
	_add_wall("TUTORIAL SOUTH WALL EAST", Vector3(-10.7, wall_y, -9.2), Vector3(5.4, wall_height, 0.45))
	tutorial_gate = _make_gate("T-03 TO T-04 TRAINING GATE", Vector3(-15, 1.4, -9.2), Vector3(3.4, 2.8, 0.45))
	tutorial_gate_shape = tutorial_gate.get_node("CollisionShape3D") as CollisionShape3D
	_add_wall("T-04 SOUTH WALL WEST", Vector3(-19.3, wall_y, -1), Vector3(5.4, wall_height, 0.45))
	_add_wall("T-04 SOUTH WALL EAST", Vector3(-10.7, wall_y, -1), Vector3(5.4, wall_height, 0.45))
	tutorial_assessment_gate = _make_gate("T-04 ASSESSMENT GATE", Vector3(-15, 1.4, -1), Vector3(3.4, 2.8, 0.45))
	tutorial_assessment_gate_shape = tutorial_assessment_gate.get_node("CollisionShape3D") as CollisionShape3D

	# A opens directly into the hub. The doorway is intentionally visible from both sides.
	_add_wall("HUB-A WEST WALL NORTH", Vector3(-19, wall_y, -11.5), Vector3(0.45, wall_height, 11))
	_add_wall("HUB-A WEST WALL SOUTH", Vector3(-19, wall_y, 11.5), Vector3(0.45, wall_height, 11))
	_add_wall("A WING EAST SOUTH", Vector3(-19, wall_y, 29), Vector3(0.45, wall_height, 24))
	_add_wall("A WING WEST", Vector3(-84, wall_y, 17), Vector3(0.45, wall_height, 48))
	_add_wall("A WING NORTH", Vector3(-51.5, wall_y, -7), Vector3(65, wall_height, 0.45))
	_add_wall("A WING SOUTH", Vector3(-51.5, wall_y, 41), Vector3(65, wall_height, 0.45))
	# Four-metre service openings connect the A optics cells without exposing shortcut doors.
	_add_wall("A LAB PARTITION 1 WEST", Vector3(-69, wall_y, 9), Vector3(30, wall_height, 0.25))
	_add_wall("A LAB PARTITION 1 EAST", Vector3(-34.5, wall_y, 9), Vector3(31, wall_height, 0.25))
	_add_wall("A LAB PARTITION 2 WEST", Vector3(-69.5, wall_y, 26), Vector3(29, wall_height, 0.25))
	_add_wall("A LAB PARTITION 2 EAST", Vector3(-35, wall_y, 26), Vector3(30, wall_height, 0.25))
	hub_gate = _make_gate("HUB TO A ENTRY GATE", Vector3(-19, 1.4, 0), Vector3(0.45, 2.8, 3.2))
	_register_map_gate(hub_gate, "H-A", "A / 중앙 배광실", "area_a")
	hub_gate_shape = hub_gate.get_node("CollisionShape3D") as CollisionShape3D
	_add_wall("A LOBBY HUB DIVIDER NORTH", Vector3(-10, wall_y, -9.3), Vector3(0.45, wall_height, 15.4))
	_add_wall("A LOBBY HUB DIVIDER SOUTH", Vector3(-10, wall_y, 9.3), Vector3(0.45, wall_height, 15.4))
	_register_area_gate("a_lobby_to_hub", "hub", "A LOBBY TO H ACCESS", Vector3(-10, 1.4, 0), Vector3(0.45, 2.8, 3.2))

	# B and C each have one physical progression door, opened by circuit A.
	_add_wall("HUB EAST WALL NORTH CAP", Vector3(19, wall_y, -16), Vector3(0.45, wall_height, 2))
	_add_wall("HUB EAST WALL F-B", Vector3(19, wall_y, -6.5), Vector3(0.45, wall_height, 9))
	_add_wall("HUB EAST WALL SOUTH", Vector3(19, wall_y, 9.5), Vector3(0.45, wall_height, 15))
	_register_area_gate("area_b", "area_b", "B SPECTRUM ACCESS", Vector3(19, 1.4, 0), Vector3(0.45, 2.8, 3.2))
	_register_area_gate("control", "control", "HUB TO CENTRAL CONTROL", Vector3(19, 1.4, -13), Vector3(0.45, 2.8, 4))
	_add_wall("HUB-C WALL WEST", Vector3(-10.3, wall_y, 17), Vector3(17.4, wall_height, 0.45))
	_add_wall("HUB-C WALL EAST", Vector3(10.3, wall_y, 17), Vector3(17.4, wall_height, 0.45))
	_register_area_gate("area_c", "area_c", "C POWER ACCESS", Vector3(0, 1.4, 17), Vector3(3.2, 2.8, 0.45))

	# The archive door sits apart from the tutorial route on the north side of the hub.
	_add_wall("HUB-ARCHIVE NORTH WEST", Vector3(-10.5, wall_y, -17), Vector3(17, wall_height, 0.45))
	_add_wall("HUB-ARCHIVE NORTH EAST", Vector3(10.5, wall_y, -17), Vector3(17, wall_height, 0.45))
	_register_area_gate("archive", "archive", "ARCHIVE SECURITY DOOR", Vector3(0, 1.4, -17), Vector3(4, 2.8, 0.45))

	# Locked wings above the hub become walkable in later acts.
	# Main rooms are independent, opaque volumes. The sealed wing is reached by an L-shaped 4m service hall.
	_add_wall("ARCHIVE SOUTH WEST", Vector3(-11.5, wall_y, -23), Vector3(17, wall_height, 0.45))
	_add_wall("ARCHIVE SOUTH EAST", Vector3(11.5, wall_y, -23), Vector3(17, wall_height, 0.45))
	_add_wall("ARCHIVE NORTH", Vector3(0, wall_y, -53), Vector3(40, wall_height, 0.45))
	_add_wall("ARCHIVE WEST NORTH", Vector3(-20, wall_y, -45.5), Vector3(0.45, wall_height, 15))
	_add_wall("ARCHIVE WEST SOUTH", Vector3(-20, wall_y, -30.5), Vector3(0.45, wall_height, 15))
	_add_wall("ARCHIVE EAST NORTH", Vector3(20, wall_y, -33), Vector3(0.45, wall_height, 20))
	_add_wall("ARCHIVE EAST SOUTH", Vector3(20, wall_y, -50), Vector3(0.45, wall_height, 6))
	_add_wall("SEALED WING WEST", Vector3(-74.5, wall_y, -70), Vector3(0.45, wall_height, 34))
	_add_wall("SEALED WING NORTH", Vector3(-52, wall_y, -87), Vector3(45, wall_height, 0.45))
	_add_wall("SEALED WING SOUTH", Vector3(-52, wall_y, -53), Vector3(45, wall_height, 0.45))
	_add_wall("SEALED WING EAST NORTH", Vector3(-29.5, wall_y, -79.5), Vector3(0.45, wall_height, 15))
	_add_wall("SEALED WING EAST SOUTH", Vector3(-29.5, wall_y, -60.5), Vector3(0.45, wall_height, 15))
	_register_area_gate("sealed_from_archive", "sealed", "SEALED WING SERVICE GATE", Vector3(-20, 1.4, -38), Vector3(0.45, 2.8, 4))
	_register_area_gate("sealed_entry", "sealed", "SEALED WING ENTRY", Vector3(-29.5, 1.4, -70), Vector3(0.45, 2.8, 4))
	# D/E service passage turns north; each 4m wall leaves the maintenance path legible.
	_add_floor_zone("ARCHIVE SEALED HALL", Vector3(-24.75, 0.03, -38), Vector3(9.5, 0.06, 4), materials["sealed_floor"])
	_add_floor_zone("SEALED APPROACH HALL", Vector3(-29.5, 0.03, -54), Vector3(4, 0.06, 32), materials["sealed_floor"])
	_add_wall("SEALED HALL SOUTH RAIL", Vector3(-25, wall_y, -40), Vector3(10, wall_height, 0.2))
	_add_wall("SEALED HALL NORTH RAIL", Vector3(-25, wall_y, -36), Vector3(10, wall_height, 0.2))
	_add_wall("SEALED APPROACH EAST RAIL", Vector3(-27.5, wall_y, -54), Vector3(0.2, wall_height, 32))
	_add_wall("SEALED APPROACH WEST RAIL", Vector3(-31.5, wall_y, -54), Vector3(0.2, wall_height, 32))
	# F is reached directly from H; a second later D/F link remains a separate optional door.
	_add_wall("CONTROL WEST ARCHIVE SIDE", Vector3(32, wall_y, -55), Vector3(0.45, wall_height, 16))
	_add_wall("CONTROL WEST LINK SOUTH", Vector3(32, wall_y, -35), Vector3(0.45, wall_height, 16))
	_add_wall("CONTROL WEST LOWER", Vector3(32, wall_y, -22), Vector3(0.45, wall_height, 2))
	_add_wall("CONTROL NORTH", Vector3(55, wall_y, -63), Vector3(46, wall_height, 0.45))
	_add_wall("CONTROL SOUTH", Vector3(55, wall_y, -21), Vector3(46, wall_height, 0.45))
	_add_wall("CONTROL EAST", Vector3(78, wall_y, -42), Vector3(0.45, wall_height, 42))
	_register_area_gate("control_entry", "control", "CENTRAL CONTROL ENTRY", Vector3(32, 1.4, -25), Vector3(0.45, 2.8, 4))
	_add_floor_zone("HUB TO CONTROL EAST HALL", Vector3(25.5, 0.03, -13), Vector3(13, 0.06, 4), materials["control_floor"])
	_add_floor_zone("HUB TO CONTROL NORTH HALL", Vector3(30, 0.03, -19), Vector3(4, 0.06, 12), materials["control_floor"])
	_add_wall("CONTROL CONNECTOR SOUTH", Vector3(25.5, wall_y, -15), Vector3(13, wall_height, 0.2))
	_add_wall("CONTROL CONNECTOR NORTH", Vector3(25.5, wall_y, -11), Vector3(13, wall_height, 0.2))
	_add_wall("CONTROL CONNECTOR WEST", Vector3(28, wall_y, -19), Vector3(0.2, wall_height, 12))
	_add_wall("CONTROL CONNECTOR EAST", Vector3(32, wall_y, -19), Vector3(0.2, wall_height, 8))
	_add_map_corridors()
	_add_zone_partitions(wall_y, wall_height)
	_register_map_gate(tutorial_gate, "T-03/T-04", "검사 통로", "hub")
	_register_map_gate(tutorial_assessment_gate, "T-04/H", "최종 검사 출구", "hub")

	_add_room_label("T-01  격리실", Vector3(-20.4, 2.35, -17.5))
	_add_room_label("T-02  교정실", Vector3(-15.1, 2.35, -17.5))
	_add_room_label("T-03  반사 교정 베이", Vector3(-10.1, 2.35, -17.5))
	_add_room_label("T-04  적합성 판정", Vector3(-15, 2.35, -5.4))
	_add_room_label("CENTRAL DISTRIBUTION HUB", Vector3(0, 2.25, 0))
	_add_room_label("ACT I  /  MIRROR ARRAY", Vector3(-19.2, 2.35, 3.5))
	_add_room_label("ACT II  /  SPECTRUM LAB", Vector3(10.5, 2.35, -5.5))
	_add_room_label("ACT II  /  POWER SERVICE", Vector3(0, 2.35, 8.5))
	_add_room_label("ACT III  /  ARCHIVE", Vector3(0, 2.35, -27.5))
	_add_room_label("SEALED WING", Vector3(-20, 2.35, -27.5))
	_add_room_label("ACT IV  /  CENTRAL CONTROL", Vector3(13, 2.35, -27.5))

	tutorial_terminal = _add_box("T-01 INTERACTION CONSOLE", Vector3(-18.6, 0.72, -15), Vector3(0.85, 1.44, 0.72), materials["cyan"], true, 4)
	_add_box("TUTORIAL EMITTER MARK", Vector3(-19.1, 0.025, -15), Vector3(1.8, 0.035, 1.1), materials["yellow"], false)
	_add_box("HUB WAYFINDING STRIPE", Vector3(-4.2, 0.09, 0), Vector3(0.24, 0.04, 5.6), materials["yellow"], false)
	_add_box("SEALED RELAY HOUSING", Vector3(-17.0, 0.8, -22.5), Vector3(1.0, 1.6, 1.2), materials["dark"], false)
	_add_box("CONTROL BANK", Vector3(17.0, 0.9, -22.5), Vector3(2.0, 1.8, 1.3), materials["dark"], false)

	_add_area_light(Vector3(0, 2.2, 0), Color(0.76, 0.84, 0.65), 0.72, 11.0)
	_add_area_light(Vector3(-15, 2.2, 3), Color(0.95, 0.51, 0.22), 0.6, 9.0)
	_add_area_light(Vector3(15, 2.2, 0), Color(0.24, 0.76, 0.84), 0.7, 9.0)
	_add_area_light(Vector3(0, 2.2, 15), Color(0.95, 0.62, 0.22), 0.68, 10.0)
	_add_area_light(Vector3(-15, 2.2, -13), Color(0.38, 0.75, 0.82), 0.82, 8.0)
	_add_area_light(Vector3(-15, 2.2, -5), Color(0.85, 0.67, 0.32), 0.7, 7.0)
	_add_area_light(Vector3(0, 2.2, -18), Color(0.48, 0.54, 0.82), 0.52, 8.0)
	_add_area_light(Vector3(0, 2.2, -24), Color(0.68, 0.25, 0.2), 0.38, 8.0)
	_add_area_light(Vector3(-52, 2.2, 17), Color(0.95, 0.51, 0.22), 0.7, 12.0)
	_add_area_light(Vector3(54, 2.2, 0), Color(0.24, 0.76, 0.84), 0.65, 14.0)
	_add_area_light(Vector3(0, 2.2, 53), Color(0.95, 0.62, 0.22), 0.65, 14.0)


func _add_floor_zone(label: String, position: Vector3, size: Vector3, material: Material) -> void:
	var floor_body := _add_box(label, position, size, material, false)
	# Slabs span multiple visibility rooms; a centroid cannot assign their ownership.
	floor_body.set_meta("shared_backing_floor", true)


func _add_area_light(position: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = false
	light.add_to_group("facility_room_lights")
	add_child(light)


func _register_art_room_lights(parent: Node) -> void:
	for child in parent.get_children():
		if child is OmniLight3D:
			(child as OmniLight3D).add_to_group("facility_room_lights")
		_register_art_room_lights(child)


func _set_world_occluder_layers(parent: Node) -> void:
	for child in parent.get_children():
		if child is StaticBody3D:
			(child as StaticBody3D).collision_layer = 4
		_set_world_occluder_layers(child)


func _disable_art_shadows(parent: Node) -> void:
	for child in parent.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_disable_art_shadows(child)


func _register_area_gate(gate_id: String, area_id: String, label: String, position: Vector3, size: Vector3) -> void:
	var gate := _make_gate(label, position, size)
	var shape := gate.get_node("CollisionShape3D") as CollisionShape3D
	area_gates[gate_id] = {"area_id": area_id, "gate": gate, "shape": shape}
	_register_map_gate(gate, gate_id, label, area_id)


func _register_map_gate(gate: StaticBody3D, gate_id: String, label: String, area_id: String) -> void:
	gate.add_to_group("facility_map_gates")
	gate.set_meta("map_id", gate_id)
	gate.set_meta("map_label", label)
	gate.set_meta("map_area", area_id)


func _register_open_map_gate(label: String, gate_id: String, map_label: String, area_id: String, position: Vector3, size: Vector3) -> void:
	var gate := _make_gate(label, position, size)
	var shape := gate.get_node("CollisionShape3D") as CollisionShape3D
	shape.disabled = true
	gate.visible = false
	_register_map_gate(gate, gate_id, map_label, area_id)


func _add_map_corridors() -> void:
	# B perimeter: the A gate opens into a subdivided optics wing.
	_add_wall("B WEST NORTH", Vector3(19, 2.25, -13.5), Vector3(0.45, 4.5, 23))
	_add_wall("B WEST SOUTH", Vector3(19, 2.25, 13.5), Vector3(0.45, 4.5, 23))
	_add_wall("B NORTH", Vector3(54, 2.25, -25), Vector3(70, 4.5, 0.45))
	_add_wall("B EAST", Vector3(89, 2.25, 0), Vector3(0.45, 4.5, 50))
	_add_wall("B SOUTH WEST", Vector3(23, 2.25, 25), Vector3(8, 4.5, 0.45))
	_add_wall("B SOUTH EAST", Vector3(60, 2.25, 25), Vector3(58, 4.5, 0.45))
	# C begins south of B; its northern opening connects back to H.
	_add_wall("C NORTH WEST", Vector3(-19.75, 2.25, 25), Vector3(35.5, 4.5, 0.45))
	_add_wall("C NORTH EAST", Vector3(19.75, 2.25, 25), Vector3(35.5, 4.5, 0.45))
	_add_wall("C WEST", Vector3(-37.5, 2.25, 53), Vector3(0.45, 4.5, 56))
	_add_wall("C SOUTH", Vector3(0, 2.25, 81), Vector3(75, 4.5, 0.45))
	_add_wall("C EAST SOUTH", Vector3(37.5, 2.25, 55), Vector3(0.45, 4.5, 52))
	_add_floor_zone("H-C ACCESS WALK", Vector3(0, 0.03, 21), Vector3(4, 0.06, 8), materials["c_floor"])
	_add_wall("H-C ACCESS WEST RAIL", Vector3(-2.2, 2.25, 21), Vector3(0.2, 4.5, 8))
	_add_wall("H-C ACCESS EAST RAIL", Vector3(2.2, 2.25, 21), Vector3(0.2, 4.5, 8))
	# The B-C maintenance shortcut is a short, gated connector between the wings.
	_add_floor_zone("B-C MAINTENANCE WALK", Vector3(33.5, 0.03, 27), Vector3(9, 0.06, 4), materials["dark"])
	_add_wall("SHORTCUT SOUTH RAIL", Vector3(33.5, 2.25, 29), Vector3(9, 4.5, 0.2))
	_register_area_gate("shortcut_b", "shortcut", "B SIDE MAINTENANCE GATE", Vector3(29, 1.4, 25), Vector3(4, 2.8, 0.45))
	_register_area_gate("shortcut_c", "shortcut", "C SIDE MAINTENANCE GATE", Vector3(37.5, 1.4, 27), Vector3(0.45, 2.8, 4))
	# D-F is reserved for a later unlock and remains physically closed for now.
	_add_floor_zone("D-F SEALED SERVICE HALL", Vector3(25.5, 0.03, -45), Vector3(11, 0.06, 4), materials["archive_floor"])
	_add_wall("D-F HALL NORTH RAIL", Vector3(25.5, 2.25, -43), Vector3(11, 4.5, 0.2))
	_add_wall("D-F HALL SOUTH RAIL", Vector3(25.5, 2.25, -47), Vector3(11, 4.5, 0.2))
	_register_area_gate("d_f_shortcut", "control", "D-F ARCHIVE LINK", Vector3(20, 1.4, -45), Vector3(0.45, 2.8, 4))
	_register_area_gate("d_f_shortcut_f", "control", "D-F CONTROL LINK", Vector3(32, 1.4, -45), Vector3(0.45, 2.8, 4))


func _add_zone_partitions(wall_y: float, wall_height: float) -> void:
	# Subdivide the two large eastern wings into connected preparation and test rooms.
	_add_wall("B PREP LAB PARTITION NORTH", Vector3(43, wall_y, -13.5), Vector3(0.3, wall_height, 23))
	_add_wall("B PREP LAB PARTITION SOUTH", Vector3(43, wall_y, 13.5), Vector3(0.3, wall_height, 23))
	_add_wall("B RECEIVER LAB PARTITION NORTH", Vector3(70, wall_y, -13.5), Vector3(0.3, wall_height, 23))
	_add_wall("B RECEIVER LAB PARTITION SOUTH", Vector3(70, wall_y, 13.5), Vector3(0.3, wall_height, 23))
	_add_wall("C SHUTTER LAB PARTITION WEST", Vector3(-18, wall_y, 45), Vector3(39, wall_height, 0.3))
	_add_wall("C SHUTTER LAB PARTITION EAST", Vector3(18, wall_y, 45), Vector3(39, wall_height, 0.3))

func _add_wall(label: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var wall := _add_box(label, position, size, materials["wall"], true, 4)
	wall.set_meta("room_structure", true)
	var visual := wall.get_child(0) as GeometryInstance3D
	# Structural walls still block movement and rays, but avoid oversized hard floor shadows.
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return wall


func _add_box(label: String, position: Vector3, size: Vector3, material: Material, collide: bool, layer: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = position
	body.collision_layer = layer
	body.collision_mask = 0
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh_instance)
	if collide:
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
	add_child(body)
	return body


func _make_gate(label: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var gate := _add_box(label, position, size, materials["rust"], true, 4)
	var stripe := MeshInstance3D.new()
	var stripe_mesh := BoxMesh.new()
	if size.x > size.z:
		stripe_mesh.size = Vector3(size.x * 0.82, size.y, 0.08)
		stripe.position = Vector3(0, 0, -size.z * 0.52)
	else:
		stripe_mesh.size = Vector3(0.08, size.y, size.z * 0.82)
		stripe.position = Vector3(-size.x * 0.52, 0, 0)
	stripe.mesh = stripe_mesh
	stripe.material_override = materials["yellow"]
	gate.add_child(stripe)
	return gate


func _add_room_label(text_value: String, position: Vector3) -> void:
	if text_value.begins_with("T-") or text_value == "CENTRAL DISTRIBUTION HUB" or text_value.begins_with("ACT I  /"):
		return # Replaced by human-scale floor lettering and wall signage in RF-FAC.
	var label := Label3D.new()
	label.text = text_value
	label.position = position
	label.rotation = Vector3(0.0, PI, 0.0)
	label.font_size = 36
	label.pixel_size = 0.006
	label.modulate = Color(0.55, 0.64, 0.59, 0.82)
	label.outline_size = 8
	label.outline_modulate = Color(0.025, 0.03, 0.027, 1)
	add_child(label)


func _build_room_occlusion() -> void:
	room_occlusion = RoomOcclusion.new()
	room_occlusion.name = "RoomOcclusion"
	add_child(room_occlusion)
	# Bounds follow the existing walls, doorways, and floor slabs. Overlapping
	# connector volumes are intentional; the smallest room wins point lookup.
	var definitions := [
		["t_main", Vector2(-22.5, -14.1), Vector2(30.0, 9.8)],
		["t04", Vector2(-15.0, -5.1), Vector2(15.0, 8.2)],
		["a_lobby", Vector2(-14.5, 0.0), Vector2(9.0, 3.2)],
		["a01", Vector2(-51.5, 17.0), Vector2(65.0, 48.0)],
		["hub", Vector2(4.5, 0.0), Vector2(29.0, 34.0)],
		["b01", Vector2(31.0, 0.0), Vector2(24.0, 50.0)],
		["b02", Vector2(56.5, 0.0), Vector2(27.0, 50.0)],
		["b03", Vector2(79.5, 0.0), Vector2(19.0, 50.0)],
		["c_access", Vector2(0.0, 21.0), Vector2(4.0, 8.0)],
		["c01", Vector2(-27.75, 53.0), Vector2(19.5, 56.0)],
		["c_corridor", Vector2(0.0, 53.0), Vector2(36.0, 56.0)],
		["c02", Vector2(27.75, 53.0), Vector2(19.5, 56.0)],
		["d_access", Vector2(0.0, -20.0), Vector2(4.0, 6.0)],
		["d", Vector2(0.0, -38.0), Vector2(40.0, 30.0)],
		["e_connector", Vector2(-24.75, -38.0), Vector2(9.5, 4.0)],
		["e_approach", Vector2(-29.5, -54.0), Vector2(4.0, 32.0)],
		["e", Vector2(-52.0, -70.0), Vector2(45.0, 34.0)],
		["f_access", Vector2(25.5, -18.0), Vector2(13.0, 14.0)],
		["f", Vector2(55.0, -42.0), Vector2(46.0, 42.0)],
		["bc_link", Vector2(33.5, 27.0), Vector2(9.0, 4.0)],
		["df_link", Vector2(25.5, -45.0), Vector2(11.0, 4.0)],
	]
	for definition in definitions:
		room_occlusion.add_room(String(definition[0]), definition[1], definition[2])
	room_occlusion.connect_rooms("t_main", "t04", "tutorial_gate", tutorial_gate_shape)
	room_occlusion.connect_rooms("t04", "a_lobby", "tutorial_assessment_gate", tutorial_assessment_gate_shape)
	room_occlusion.connect_rooms("a_lobby", "hub", "a_lobby_to_hub", area_gates["a_lobby_to_hub"]["shape"])
	room_occlusion.connect_rooms("a_lobby", "a01", "hub_gate", hub_gate_shape)
	room_occlusion.connect_rooms("hub", "b01", "area_b", area_gates["area_b"]["shape"])
	room_occlusion.connect_rooms("b01", "b02")
	room_occlusion.connect_rooms("b02", "b03")
	room_occlusion.connect_rooms("hub", "c_access", "area_c", area_gates["area_c"]["shape"])
	room_occlusion.connect_rooms("c_access", "c_corridor")
	room_occlusion.connect_rooms("c_corridor", "c01")
	room_occlusion.connect_rooms("c_corridor", "c02")
	room_occlusion.connect_rooms("hub", "d_access", "archive", area_gates["archive"]["shape"])
	room_occlusion.connect_rooms("d_access", "d")
	room_occlusion.connect_rooms("d", "e_connector", "sealed_from_archive", area_gates["sealed_from_archive"]["shape"])
	room_occlusion.connect_rooms("e_connector", "e_approach")
	room_occlusion.connect_rooms("e_approach", "e", "sealed_entry", area_gates["sealed_entry"]["shape"])
	room_occlusion.connect_rooms("hub", "f_access", "control", area_gates["control"]["shape"])
	room_occlusion.connect_rooms("f_access", "f", "control_entry", area_gates["control_entry"]["shape"])
	room_occlusion.connect_rooms("b01", "bc_link", "shortcut_b", area_gates["shortcut_b"]["shape"])
	room_occlusion.connect_rooms("bc_link", "c02", "shortcut_c", area_gates["shortcut_c"]["shape"])
	room_occlusion.connect_rooms("d", "df_link", "d_f_shortcut", area_gates["d_f_shortcut"]["shape"])
	room_occlusion.connect_rooms("df_link", "f", "d_f_shortcut_f", area_gates["d_f_shortcut_f"]["shape"])
	for light in get_tree().get_nodes_in_group("facility_room_lights"):
		if light is OmniLight3D:
			var light_room := room_occlusion.room_at((light as OmniLight3D).global_position)
			room_occlusion.register_room_light(light_room, light)
	_register_room_visuals(self)


func _register_room_visuals(parent: Node) -> void:
	for child in parent.get_children():
		if child is GeometryInstance3D and not _is_room_visibility_exempt(child):
			var room_id := room_occlusion.room_at((child as GeometryInstance3D).global_position)
			if not room_id.is_empty():
				room_occlusion.register_room_visual(room_id, child as GeometryInstance3D)
		_register_room_visuals(child)


func _is_room_visibility_exempt(visual: GeometryInstance3D) -> bool:
	var ancestor: Node = visual
	while ancestor != null and ancestor != self:
		if ancestor == player or ancestor == laser or ancestor == room_occlusion:
			return true
		if ancestor is StaticBody3D and (ancestor.has_meta("room_structure") or ancestor.has_meta("shared_backing_floor")):
			return true
		if ancestor.is_in_group("facility_map_gates"):
			return true
		ancestor = ancestor.get_parent()
	return false


func _room_gate_unlock_states() -> Dictionary:
	var result := {
		"tutorial_gate": progression.tutorial_step_index >= 3 or progression.tutorial_completed,
		"tutorial_assessment_gate": progression.tutorial_completed,
		"hub_gate": progression.is_area_unlocked("hub"),
		"a_lobby_to_hub": a_lobby_visited,
	}
	for gate_id in area_gates:
		var area_id: String = area_gates[gate_id]["area_id"]
		if gate_id in ["d_f_shortcut", "d_f_shortcut_f"]:
			result[gate_id] = progression.is_area_unlocked("archive") and progression.is_area_unlocked("control")
		else:
			result[gate_id] = progression.is_area_unlocked(area_id)
	return result


func _update_room_visibility() -> void:
	if room_occlusion != null and player != null:
		room_occlusion.refresh(player.global_position, _room_gate_unlock_states())


func _build_devices() -> void:
	tutorial_receiver = _create_device("receiver", "R-T02 일반 수신기", Vector3(-15, 0, -15), Vector3(0.72, 2.0, 0.8), 0.0, Color(0.88, 0.58, 0.12))
	tutorial_receiver.required_seconds = 0.65
	tutorial_mirror = _create_device("mirror", "M-T03 교정 거울", Vector3(-12.5, 0, -12), Vector3(0.26, 2.3, 2.4), 0.0, Color(0.36, 0.62, 0.65))
	tutorial_mirror_receiver = _create_device("receiver", "R-T03 반사 수신기", Vector3(-13.05, 0, -10.0), Vector3(0.72, 2.0, 0.8), 0.0, Color(0.89, 0.3, 0.12))
	tutorial_mirror_receiver.required_seconds = 0.8
	tutorial_mirror_receiver.minimum_reflections = 1
	tutorial_assessment_mirror_a = _create_device("mirror", "M-T04-A 적합성 거울", Vector3(-15, 0, -7), Vector3(0.26, 2.3, 2.4), 0.0, Color(0.42, 0.68, 0.65))
	tutorial_assessment_mirror_b = _create_device("mirror", "M-T04-B 적합성 거울", Vector3(-15.56, 0, -3.5), Vector3(0.26, 2.3, 2.4), 0.0, Color(0.42, 0.68, 0.65))
	tutorial_final_receiver = _create_device("receiver", "R-T04 적합성 판정 수신기", Vector3(-10.5, 0, -3.5), Vector3(0.72, 2.0, 0.8), 0.0, Color(0.89, 0.3, 0.12))
	tutorial_final_receiver.required_seconds = 0.8
	tutorial_final_receiver.required_direction = Vector3.RIGHT
	tutorial_final_receiver.minimum_direction_dot = 0.94
	tutorial_final_receiver.minimum_reflections = 2

	# A: v6.3 shielded three-mirror channel reuses the ordinary receiver and controls.
	a01_lab = preload("res://scripts/a01_lab.gd").new()
	add_child(a01_lab)
	a01_lab.build(self)
	mirror_relay = a01_lab.receiver
	a02_lab = preload("res://scripts/a02_lab.gd").new()
	add_child(a02_lab)
	a02_lab.build(self)

	# B: a slab and dispersive prism feed three color-coded receivers.
	var medium := _create_device("medium", "G-01 광증폭 매질", Vector3(12, 0, 0), Vector3(1.8, 2.0, 1.5), deg_to_rad(26), Color(0.22, 0.49, 0.52))
	medium.amplification = 2.0
	medium.refractive_indices = {"white": 1.48, "red": 1.46, "green": 1.49, "blue": 1.53}
	var prism := _create_device("prism", "P-01 분산 프리즘", Vector3(16, 0, 0), Vector3(1.7, 2.2, 1.4), 0.0, Color(0.43, 0.48, 0.57))
	prism.refractive_indices = {"white": 1.50, "red": 1.42, "green": 1.50, "blue": 1.60}
	var red_receiver := _create_device("receiver", "R-B 적색 채널", Vector3(21, 0, 2.9), Vector3(0.65, 2.0, 0.8), 0.0, Color(0.82, 0.14, 0.09))
	red_receiver.receiver_color = "red"
	red_receiver.simultaneous_group = "B-02-RGB"
	var green_receiver := _create_device("receiver", "R-B 녹색 채널", Vector3(21, 0, 3.6), Vector3(0.65, 2.0, 0.8), 0.0, Color(0.14, 0.75, 0.22))
	green_receiver.receiver_color = "green"
	green_receiver.simultaneous_group = "B-02-RGB"
	var blue_receiver := _create_device("receiver", "R-B 청색 채널", Vector3(21, 0, 4.7), Vector3(0.65, 2.0, 0.8), 0.0, Color(0.15, 0.35, 0.9))
	blue_receiver.receiver_color = "blue"
	blue_receiver.simultaneous_group = "B-02-RGB"
	spectrum_receivers = [red_receiver, green_receiver, blue_receiver]
	white_spectrum_source = _create_device("white_source", "W-B02 백색광 발생기", Vector3(8, 0, 0), Vector3(0.8, 1.8, 1.0), 0.0, Color(0.72, 0.69, 0.5))
	white_spectrum_source.rotatable = false

	# C: a splitter powers two relays at once; a separate shutter route introduces timing.
	var splitter := _create_device("splitter", "S-01 빔 스플리터", Vector3(0, 0, 12), Vector3(0.28, 2.2, 2.8), deg_to_rad(45), Color(0.7, 0.54, 0.26))
	split_relay_a = _create_device("receiver", "R-C1 병렬 수신기", Vector3(2.7, 0, 12), Vector3(0.7, 2.0, 0.9), 0.0, Color(0.88, 0.62, 0.11))
	split_relay_b = _create_device("receiver", "R-C2 병렬 수신기", Vector3(0, 0, 15), Vector3(0.7, 2.0, 0.9), 0.0, Color(0.88, 0.62, 0.11))
	test_shutter = _create_device("shutter", "T-01 회전 차단막", Vector3(4.6, 0, 19), Vector3(0.22, 2.5, 3.0), 0.0, Color(0.72, 0.3, 0.12))
	var timed_receiver := _create_device("receiver", "R-C3 시간 수신기", Vector3(6.8, 0, 19), Vector3(0.55, 2.0, 0.8), 0.0, Color(0.79, 0.23, 0.08))
	timed_receiver.required_seconds = 2.0
	var b01_amplifier := _create_device("medium", "G-B01 Basic Amplifier", Vector3(12, 0, -12), Vector3(1.8, 2.0, 1.5), 0.0, Color(0.22, 0.49, 0.52))
	b01_amplifier.amplification = 2.0
	var b01_receiver := _create_device("receiver", "R-B01 High Power Receiver", Vector3(18, 0, -12), Vector3(0.65, 2.0, 0.8), 0.0, Color(0.85, 0.48, 0.13))
	b01_receiver.minimum_energy = 2.0
	b01_receiver.required_seconds = 0.8
	var b03_amplifier := _create_device("medium", "G-HO-01 High Output Amplifier", Vector3(13, 0, -18), Vector3(2.2, 2.2, 1.8), deg_to_rad(18), Color(0.47, 0.38, 0.22))
	b03_amplifier.amplification = 3.0
	var b03_receiver := _create_device("receiver", "R-B03 High Output Receiver", Vector3(20, 0, -18), Vector3(0.65, 2.0, 0.8), 0.0, Color(0.85, 0.48, 0.13))
	b03_receiver.minimum_energy = 3.0
	b03_receiver.required_seconds = 0.8
	var wedge_amplifier := _create_device("wedge_medium", "G-WEDGE-01 경사형 광증폭기", Vector3(32, 0, -8), Vector3(2.2, 2.0, 1.8), 0.0, Color(0.27, 0.52, 0.51))
	wedge_amplifier.amplification = 2.0
	wedge_amplifier.refractive_indices = {"white": 1.5, "red": 1.5, "green": 1.5, "blue": 1.5}
	var wedge_receiver := _create_device("receiver", "R-B-WEDGE 방향 수신기", Vector3(42, 0, -10.5), Vector3(0.65, 2.0, 0.8), 0.0, Color(0.85, 0.48, 0.13))
	wedge_receiver.minimum_energy = 2.0
	wedge_receiver.required_direction = Vector3(1.0, 0.0, -0.26).normalized()
	wedge_receiver.minimum_direction_dot = 0.94
	wedge_receiver.required_seconds = 0.8
	shutter_control_receiver = _create_device("receiver", "R-C-CONTROL Shutter Control", Vector3(1.5, 0, 21), Vector3(0.65, 2.0, 0.8), 0.0, Color(0.79, 0.23, 0.08))
	shutter_control_receiver.required_seconds = 0.8
	split_relay_a.minimum_energy = 0.5
	split_relay_b.minimum_energy = 0.5
	split_relay_a.simultaneous_group = "C-01-PARALLEL"
	split_relay_b.simultaneous_group = "C-01-PARALLEL"

	for pos in [Vector3(-18.5, 0, 3.8), Vector3(10, 0, -5.5), Vector3(5.5, 0, 23)]:
		var console_position := _relocate_zone_position(pos)
		_add_box("CONTROL CONSOLE", console_position + Vector3(0, 0.7, 0), Vector3(0.9, 1.4, 1.4), materials["dark"], true, 4)
		_add_box("CONSOLE CRT", console_position + Vector3(0, 1.55, -0.2), Vector3(0.55, 0.36, 0.12), materials["cyan"], false)

func _create_device(kind: String, label: String, position: Vector3, size: Vector3, yaw: float, color: Color) -> OpticalDevice:
	position = _relocate_device_position(label, position)
	var device := OpticalDevice.new()
	device.process_mode = Node.PROCESS_MODE_PAUSABLE
	device.name = label
	device.optical_size = size
	device.configure(kind, label, color)
	device.position = position
	device.rotation = Vector3(0.0, yaw, 0.0)
	device.initial_rotation_y = yaw
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	if kind in ["prism", "wedge_medium"]:
		var prism_shape := ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		var half_height := size.y * 0.5
		var outline := _optical_outline(kind, size)
		for y in [-half_height, half_height]:
			for vertex in outline:
				points.append(Vector3(vertex.x, y, vertex.y))
		prism_shape.points = points
		shape.shape = prism_shape
	else:
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
	shape.position.y = size.y * 0.5
	device.add_child(shape)
	var visual := MeshInstance3D.new()
	if kind == "prism":
		# Match the visible prism to the exact triangular collision hull.
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a := Vector3(-size.x / 2, -size.y / 2, -size.z / 2)
		var b := Vector3(size.x / 2, -size.y / 2, -size.z / 2)
		var c := Vector3(0, -size.y / 2, size.z / 2)
		var up := Vector3.UP * size.y
		for triangle in [[a, b, c], [c + up, b + up, a + up], [a, a + up, b], [b, a + up, b + up], [b, b + up, c], [c, b + up, c + up], [c, c + up, a], [a, c + up, a + up]]:
			for vertex in triangle:
				tool.add_vertex(vertex)
		tool.generate_normals()
		visual.mesh = tool.commit()
	elif kind == "wedge_medium":
		visual.mesh = _build_extruded_optical_mesh(_optical_outline(kind, size), size)
	else:
		var box_mesh := BoxMesh.new()
		box_mesh.size = size
		visual.mesh = box_mesh
	visual.position.y = size.y * 0.5
	device.add_child(visual)
	device.set_visual(visual)
	if kind == "receiver":
		device.receiver_color = "white"
		device.required_seconds = 2.0
		device.receiver_activated.connect(_on_receiver_activated)
	if kind == "white_source":
		device.source_activated.connect(_on_source_activated)
	var marker := MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.14, 0.42, 0.14)
	marker.mesh = marker_mesh
	marker.position = Vector3(0, size.y + 0.2, 0)
	marker.material_override = _emissive_material(color, 1.1)
	device.add_child(marker)
	device.set_marker(marker)
	add_child(device)
	DeviceArt.decorate(device)
	if kind == "wedge_medium":
		DeviceArt.decorate_wedge(device)
	if kind == "white_source":
		DeviceArt.box(device, Vector3(0.14, 1.5, 0.14), Vector3(-0.33, 0.9, 0), DeviceArt.material(Color("485552")))
		DeviceArt.box(device, Vector3(0.14, 1.5, 0.14), Vector3(0.33, 0.9, 0), DeviceArt.material(Color("485552")))
		DeviceArt.box(device, Vector3(0.8, 0.12, 1.0), Vector3(0, 1.68, 0), DeviceArt.material(Color("192625")))
		DeviceArt.cylinder(device, 0.22, 0.24, Vector3(0.42, 1.15, 0), DeviceArt.material(Color("d4d0a0"), 1.3))
	_disable_device_shadows(device)
	device.set_meta("map_id", label)
	return device


func _disable_device_shadows(parent: Node) -> void:
	for child in parent.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_disable_device_shadows(child)


func _optical_outline(kind: String, size: Vector3) -> Array[Vector2]:
	if kind == "wedge_medium":
		return [
			Vector2(-size.x * 0.5, -size.z * 0.5),
			Vector2(size.x * 0.5, -size.z * 0.5),
			Vector2(size.x * 0.5, size.z * 0.5),
			Vector2(-size.x * 0.07, size.z * 0.5)
		]
	return [
		Vector2(-size.x * 0.5, -size.z * 0.5),
		Vector2(size.x * 0.5, -size.z * 0.5),
		Vector2(0.0, size.z * 0.5)
	]


func _build_extruded_optical_mesh(outline: Array[Vector2], size: Vector3) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bottom: Array[Vector3] = []
	var top: Array[Vector3] = []
	for vertex in outline:
		bottom.append(Vector3(vertex.x, -size.y * 0.5, vertex.y))
		top.append(Vector3(vertex.x, size.y * 0.5, vertex.y))
	for index in range(1, outline.size() - 1):
		surface.add_vertex(bottom[0])
		surface.add_vertex(bottom[index + 1])
		surface.add_vertex(bottom[index])
		surface.add_vertex(top[0])
		surface.add_vertex(top[index])
		surface.add_vertex(top[index + 1])
	for index in range(outline.size()):
		var next := (index + 1) % outline.size()
		surface.add_vertex(bottom[index])
		surface.add_vertex(bottom[next])
		surface.add_vertex(top[next])
		surface.add_vertex(bottom[index])
		surface.add_vertex(top[next])
		surface.add_vertex(top[index])
	surface.generate_normals()
	return surface.commit()


func _relocate_device_position(label: String, source: Vector3) -> Vector3:
	if label.begins_with("W-B02"):
		return source + Vector3(42.0, 0.0, 0.0)
	if label.begins_with("G-") or label.begins_with("P-01") or label.begins_with("R-B"):
		return source + Vector3(42.0, 0.0, 0.0)
	if label.begins_with("S-01") or label.begins_with("R-C") or label.begins_with("T-01 "):
		return source + Vector3(0.0, 0.0, 41.0)
	return source


func _relocate_zone_position(source: Vector3) -> Vector3:
	if source.x > 8.0:
		return source + Vector3(42.0, 0.0, 0.0)
	if source.z > 10.0:
		return source + Vector3(0.0, 0.0, 41.0)
	return source + Vector3(-36.5, 0.0, 14.0)


func _build_player_and_camera() -> void:
	player = ReflectionPlayer.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.name = "피험자 07"
	player.position = Vector3(-21.0, 0.03, -15.0)
	add_child(player)
	player.collision_mask |= 8 # A-01 optical apertures block bodies, not the laser mask 7.
	camera = Camera3D.new()
	camera.name = "QuarterViewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.0
	camera.near = 0.1
	camera.far = 140.0
	camera.current = true
	# One fixed, player-relative pose. Physics interpolation smooths the shared transform.
	camera.position = Vector3(0.0, 8.0, 8.0 / tan(deg_to_rad(70.0)))
	camera.rotation = Vector3(deg_to_rad(-70.0), 0.0, 0.0)
	player.add_child(camera)
	player.camera = camera
	player.aim_position = Vector3(-2, player.laser_height, -8.2)
	player.reset_physics_interpolation()


func _build_laser() -> void:
	laser = ReflectionLaser.new()
	laser.name = "LaserSystem"
	laser.ignore_rids = [player.get_rid()]
	add_child(laser)


func _build_ui() -> void:
	# Draw the low-bit finish before HUD so Korean text stays sharp.
	var finish_layer := CanvasLayer.new()
	finish_layer.layer = 1
	add_child(finish_layer)
	var finish := ColorRect.new()
	finish.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	finish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var finish_material := ShaderMaterial.new()
	finish_material.shader = preload("res://assets/v4_0/film_grain.gdshader")
	finish.material = finish_material
	finish_layer.add_child(finish)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	hud_root = root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	hud_panel = PanelContainer.new()
	hud_panel.position = Vector2(24, 20)
	hud_panel.custom_minimum_size = Vector2(420, 0)
	_style_panel(hud_panel, Color(0.29, 0.75, 0.72))
	root.add_child(hud_panel)
	var hud_stack := VBoxContainer.new()
	hud_stack.add_theme_constant_override("separation", 7)
	hud_panel.add_child(hud_stack)
	var header := HBoxContainer.new()
	hud_stack.add_child(header)
	header.add_child(_make_label("REFLECTION", 18, Color(0.84, 0.9, 0.82)))
	details_button = Button.new()
	details_button.focus_mode = Control.FOCUS_NONE
	details_button.text = "상세 ▾"
	details_button.pressed.connect(_toggle_hud_details)
	header.add_child(details_button)
	hud_summary = _make_label("격리실 · 탐색\n목표: 신원 확인\nH 도움말", 17, Color(0.84, 0.9, 0.82))
	hud_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_stack.add_child(hud_summary)
	hud_details = VBoxContainer.new()
	hud_details.visible = false
	hud_stack.add_child(hud_details)
	tutorial_title_label = _make_label("T-01  격리실", 18, Color(0.41, 0.9, 0.82))
	hud_details.add_child(tutorial_title_label)
	objective_label = _make_label("WASD로 주변을 살펴보세요.", 18, Color(0.88, 0.88, 0.77))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_details.add_child(objective_label)
	navigation_label = _make_label("구역: 격리실  /  안내: 바닥 표식을 따라 이동하십시오.", 15, Color(0.48, 0.84, 0.78))
	navigation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_details.add_child(navigation_label)
	destination_panel = HBoxContainer.new()
	destination_panel.add_theme_constant_override("separation", 8)
	hud_details.add_child(destination_panel)
	var destination_b := Button.new()
	destination_b.text = "B 먼저  [1]"
	destination_b.pressed.connect(_select_destination.bind("area_b"))
	destination_panel.add_child(destination_b)
	var destination_c := Button.new()
	destination_c.text = "C 먼저  [2]"
	destination_c.pressed.connect(_select_destination.bind("area_c"))
	destination_panel.add_child(destination_c)
	destination_status = _make_label("선택 경로: B 분광 실험동", 15, Color(0.7, 0.76, 0.68))
	destination_panel.add_child(destination_status)
	status_label = _make_label("DIRECTOR: 이동 반응을 확인하겠습니다.", 16, Color(0.95, 0.67, 0.36))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_details.add_child(status_label)

	prompt_panel = PanelContainer.new()
	prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt_panel.offset_left = 24
	prompt_panel.offset_right = -24
	prompt_panel.offset_top = -94
	prompt_panel.offset_bottom = -20
	_style_panel(prompt_panel, Color(0.68, 0.72, 0.52))
	root.add_child(prompt_panel)
	prompt_label = _make_label("WASD 이동", 18, Color(0.84, 0.88, 0.81))
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_panel.add_child(prompt_label)

	reticle = _make_label("+", 26, Color(1.0, 0.88, 0.55, 0.95))
	reticle.position = player.pointer_position - Vector2(8.0, 14.0)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(reticle)

	minimap_panel = PanelContainer.new()
	minimap_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap_panel.offset_left = -232
	minimap_panel.offset_right = -20
	minimap_panel.offset_top = 20
	minimap_panel.offset_bottom = 232
	_style_panel(minimap_panel, Color(0.42, 0.68, 0.78))
	root.add_child(minimap_panel)
	minimap_view = MapView.new()
	minimap_view.mini = true
	minimap_view.custom_minimum_size = Vector2(200, 200)
	minimap_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minimap_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	minimap_panel.add_child(minimap_view)

	help_panel = PanelContainer.new()
	help_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	help_panel.custom_minimum_size = Vector2(660, 430)
	help_panel.offset_left = -360
	help_panel.offset_right = 360
	help_panel.offset_top = -260
	help_panel.offset_bottom = 260
	help_panel.visible = false
	_style_panel(help_panel, Color(0.76, 0.61, 0.3))
	root.add_child(help_panel)
	var help_stack := VBoxContainer.new()
	help_stack.add_theme_constant_override("separation", 12)
	help_panel.add_child(help_stack)
	help_stack.add_child(_make_label("조작 안내  /  H 또는 F1 닫기", 22, Color(0.96, 0.79, 0.42)))
	var help_text := _make_label("WASD  이동\n마우스  바닥 조준 / 좌클릭 유지  획득한 광원 발사\nE  단말기·광원 획득·가까운 장치 선택 또는 정보 확인\n마우스 휠  선택한 회전 장치 15° 회전\nShift+휠  지원 장치 정밀 회전 1°\nV  A-01 퍼즐 전체 보기 / 탐색 전환\nM  미니맵 표시 전환 / Tab  전체 지도\n1·2  A 회로 복구 후 B 또는 C 우선 선택 / L  시스템 로그\nR  현재 구역 퍼즐 초기화 (완료 회로 보존)\nShift+R  전체 진행 초기화 / Esc  일시정지", 19, Color(0.84, 0.88, 0.81))
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_stack.add_child(help_text)

	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.custom_minimum_size = Vector2(460, 180)
	pause_panel.visible = false
	_style_panel(pause_panel, Color(0.85, 0.45, 0.25))
	root.add_child(pause_panel)
	var pause_text := _make_label("일시정지\n\nEsc를 눌러 계속", 22, Color(0.92, 0.89, 0.8))
	pause_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_panel.add_child(pause_text)

	info_panel = PanelContainer.new()
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	info_panel.offset_left = -490
	info_panel.offset_right = -24
	info_panel.offset_top = -115
	info_panel.offset_bottom = -20
	_style_panel(info_panel, Color(0.76, 0.61, 0.3))
	root.add_child(info_panel)
	device_info_label = _make_label("장치 가까이 이동하면 기능과 작동 조건이 표시됩니다.", 18, Color(0.84, 0.88, 0.81))
	device_info_label.add_theme_font_size_override("font_size", 16)
	device_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_panel.add_child(device_info_label)

	log_panel = PanelContainer.new()
	log_panel.position = Vector2(600, 240)
	log_panel.custom_minimum_size = Vector2(710, 430)
	_style_panel(log_panel, Color(0.29, 0.75, 0.72))
	root.add_child(log_panel)
	log_panel.visible = false
	log_label = _make_label("시스템 로그 / L 닫기", 19, Color(0.82, 0.88, 0.81))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var log_scroll := ScrollContainer.new()
	log_scroll.custom_minimum_size = Vector2(680, 400)
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_panel.add_child(log_scroll)
	log_scroll.add_child(log_label)

	intro_veil = ColorRect.new()
	intro_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_veil.color = Color(0.01, 0.018, 0.018, 0.85)
	intro_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(intro_veil)
	fullmap_overlay = ColorRect.new()
	fullmap_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fullmap_overlay.color = Color(0.008, 0.012, 0.012, 0.97)
	fullmap_overlay.visible = false
	fullmap_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fullmap_overlay)
	var fullmap_stack := VBoxContainer.new()
	fullmap_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fullmap_stack.offset_left = 44
	fullmap_stack.offset_top = 34
	fullmap_stack.offset_right = -44
	fullmap_stack.offset_bottom = -34
	fullmap_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fullmap_overlay.add_child(fullmap_stack)
	var fullmap_title := _make_label("연구 시설 지도  /  Tab 닫기 · 발견한 공간만 표시", 22, Color(0.75, 0.88, 0.82))
	fullmap_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fullmap_stack.add_child(fullmap_title)
	fullmap_view = MapView.new()
	fullmap_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fullmap_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fullmap_stack.add_child(fullmap_view)
	_update_compact_hud()


func _toggle_hud_details() -> void:
	hud_details.visible = not hud_details.visible
	details_button.text = "접기 ▴" if hud_details.visible else "상세 ▾"
	hud_panel.reset_size()


func _update_compact_hud() -> void:
	if hud_summary == null:
		return
	var in_a01: bool = puzzle_camera != null and puzzle_camera.in_room()
	var mode := "탐색"
	if in_a01:
		mode = "탐색 [V 전체 보기]"
	if puzzle_camera != null and puzzle_camera.framing:
		mode = "전체 보기 [V]" if puzzle_camera.overview else "거울 조작 [V 전체 보기]"
	var area := "A-01" if in_a01 else _area_name(_area_id_at(player.global_position))
	var goal := "세 거울로 수신기에 광선 전달" if in_a01 and not mirror_relay.receiver_active else String(current_goal.get("label", "신원 확인"))
	if not progression.tutorial_completed:
		goal = {"T-01": "이동 후 단말기에서 E" if tutorial_move_completed else "WASD로 주변 탐색", "T-02": "R-T02에 광선 조사" if player.has_emitter else "L-07 지급대에서 E", "T-03": "거울 조정 → R-T03", "T-04": "두 거울 조정 → R-T04"}.get(progression.get_current_tutorial_id(), goal)
	if in_a01 and mirror_relay.receiver_active:
		goal = "완료 · 통행문 개방"
	hud_summary.text = "%s · %s\n목표: %s\nA %s · B %s · C %s  |  H 도움말" % [area, mode, goal, "복구" if progression.restored_circuits.has("A") else "대기", "복구" if progression.restored_circuits.has("B") else "대기", "복구" if progression.restored_circuits.has("C") else "대기"]
	prompt_panel.visible = not progression.tutorial_completed or help_panel.visible
	info_panel.visible = selected_device != null and not help_panel.visible and not fullmap_overlay.visible
	if selected_device != null:
		device_info_label.text = "%s · %d°\nE 해제 · 휠 15° · Shift+휠 1°\n%s" % [selected_device.display_name, roundi(rad_to_deg(selected_device.rotation.y)), "V 퍼즐 전체 보기" if in_a01 else "H 도움말"]
	if optical_control != null:
		if optical_control.active():
			hud_summary.text = "A-01 · 광학 조작 모드\n목표: %s\n클릭: 선택 · 휠: 회전 · Shift+휠: 정밀 회전" % goal
		elif optical_control.near_console() and not optical_control.authorized():
			hud_summary.text = "A-01 · 광학 제어 콘솔\n목표: %s\nE: 원격 조작 연결" % goal
		elif optical_control.authorized():
			hud_summary.text += "\n콘솔 근처에서 E: 광학 조작"
		if optical_control.owns_selection():
			var index: int = a01_lab.mirrors.find(selected_device) + 1
			device_info_label.text = "선택 거울: M%d · %d°\n휠 회전 · Shift+휠 정밀 회전\n빈곳/재클릭 해제 · Esc 종료" % [index, roundi(rad_to_deg(selected_device.rotation.y))]
	hud_panel.reset_size()


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _style_panel(panel: PanelContainer, accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.026, 0.024, 0.91)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(14.0)
	panel.add_theme_stylebox_override("panel", style)

func _process_tutorial() -> void:
	var tutorial_id := progression.get_current_tutorial_id()
	if tutorial_id == "T-01" and not tutorial_move_completed:
		var moved := Vector2(player.global_position.x - tutorial_start_position.x, player.global_position.z - tutorial_start_position.z).length()
		if moved >= 1.4:
			tutorial_move_completed = true
			_show_status("DIRECTOR: 이동 확인. 단말기에서 다음 절차를 받으십시오.")


func _update_tutorial_ui() -> void:
	var step: Dictionary = progression.get_current_tutorial_step()
	if step.is_empty():
		tutorial_title_label.text = "1막  /  중앙 배광실"
		objective_label.text = "회로 A를 복구해 분광 실험동과 동력 정비동을 여세요."
		prompt_label.text = "WASD 이동   ·   마우스 조준   ·   좌클릭 유지: 광선   ·   E: 상호작용   ·   휠: 선택 장치 회전   ·   Tab: 지도   ·   H: 조작 안내"
		return
	var tutorial_id: String = step["id"]
	tutorial_title_label.text = "%s  /  %s" % [tutorial_id, step["title"]]
	match tutorial_id:
		"T-01":
			if tutorial_move_completed:
				objective_label.text = "이동을 확인했습니다. 가까운 청록색 단말기에서 E를 누르세요."
				prompt_label.text = "E  단말기 상호작용"
			else:
				objective_label.text = "격리실을 살펴보세요. WASD로 1.4m 이상 이동하면 다음 조작을 안내합니다."
				prompt_label.text = "WASD  이동"
		"T-02":
			if not player.has_emitter:
				objective_label.text = "신원 확인 완료. 단말기 북쪽 L-07 지급대에 접근해 E로 휴대 광원을 받으세요."
				prompt_label.text = "E  휴대 광원 획득 · 지급대까지 이동"
			else:
				objective_label.text = "획득한 광원을 노란 수신기 R-T02에 조준해 0.65초 유지하세요."
				prompt_label.text = "마우스  바닥 조준   ·   좌클릭 유지  광선 발사"
		"T-03":
			objective_label.text = "M-T03을 E로 선택하고 휠로 회전하세요. 반사된 광선이 R-T03에 닿아야 합니다."
			prompt_label.text = "E  가까운 거울 선택   ·   휠  15° 회전   ·   좌클릭 유지  발사"
		"T-04":
			objective_label.text = "M-T04-A와 M-T04-B를 각각 E로 선택해 45° 돌리세요. 두 번 반사된 광선을 R-T04에 전달하세요."
			prompt_label.text = "가까이 이동   ·   E 선택   ·   휠 3회 회전   ·   좌클릭 유지로 발사"


func _update_objectives() -> void:
	if not progression.tutorial_completed:
		_update_tutorial_ui()
	else:
		_update_tutorial_ui()
	var goal := _get_mission_goal()
	current_goal = goal
	map_goal_known = bool(goal.get("known", false))
	map_goal_position = goal.get("position", Vector3.ZERO)
	if goal.has("gate") and visited_gate_ids.has(String(goal["gate"])):
		map_goal_position = discovered_gates[String(goal["gate"])]["approach"]
	if progression.tutorial_completed:
		objective_label.text = "%s
A %s   B %s   C %s" % [
			goal.get("text", "시설 안내를 따라가십시오."),
			"복구" if progression.restored_circuits.has("A") else "대기",
			"복구" if progression.restored_circuits.has("B") else "대기",
			"복구" if progression.restored_circuits.has("C") else "대기"
		]
		destination_panel.visible = progression.restored_circuits.has("A") and not progression.is_area_unlocked("control")
		destination_status.text = "선택 경로: %s" % ("B 분광 실험동" if selected_destination == "area_b" else "C 동력 정비동")
	_update_navigation_label(goal)


func _get_mission_goal() -> Dictionary:
	var tutorial_id := progression.get_current_tutorial_id()
	if not progression.tutorial_completed:
		match tutorial_id:
			"T-01":
				return {"text": "목표: 격리실 단말기에서 시스템 로그를 확인하십시오.", "position": tutorial_terminal.global_position, "known": true, "label": "T-01"}
			"T-02":
				if not player.has_emitter:
					return {"text": "목표: 광원 보관대에서 L-07 발사기를 회수하십시오.", "position": EMITTER_RACK, "known": true, "label": "L-07"}
				return {"text": "목표: 광선을 R-T02 수신기에 맞추십시오.", "position": tutorial_receiver.global_position, "known": true, "label": "R-T02"}
			"T-03":
				return {"text": "목표: 거울을 회전해 R-T03에 광선을 반사하십시오.", "position": tutorial_mirror_receiver.global_position, "known": true, "label": "R-T03"}
			"T-04":
				return {"text": "목표: 두 번 반사한 광선을 R-T04에 전달하십시오.", "position": tutorial_final_receiver.global_position, "known": true, "label": "R-T04"}
	if not progression.restored_circuits.has("A"):
		if not _player_in_area("area_a") and not a_lobby_visited:
			return {"text": "목표: A 입구 로비를 지나 반사 실험동으로 이동하십시오. H 통로는 A에 들어간 뒤 열립니다.", "position": Vector3(-19, 0, 0), "known": visited_gate_ids.has("H-A"), "gate": "H-A", "label": "A 입구"}
		var id_a := String(mirror_relay.get_meta("map_id", "R-A01"))
		return {"text": "목표: A-01의 세 점검 거울을 조정해 광학 통로 끝 수신기에 전달하십시오.", "position": mirror_relay.global_position, "known": visited_device_ids.has(id_a), "label": "R-A01"}
	if progression.restored_circuits.size() >= 3:
		var f_known := visited_gate_ids.has("control_entry") or _player_in_area("control")
		return {"text": "목표: 중앙 제어실의 출입구를 찾으십시오.", "position": Vector3(32, 0, -25), "known": f_known, "gate": "control_entry", "label": "F"}
	if progression.restored_circuits.size() >= 2:
		var d_known := visited_gate_ids.has("archive") or _player_in_area("archive")
		return {"text": "목표: 기록 보관실 출입구를 찾으십시오. (선택 구역)", "position": Vector3(0, 0, -17), "known": d_known, "gate": "archive", "label": "D"}
	var target_area := selected_destination
	var target_circuit := "B" if target_area == "area_b" else "C"
	if progression.restored_circuits.has(target_circuit):
		target_area = "area_c" if target_area == "area_b" else "area_b"
		selected_destination = target_area
	target_circuit = "B" if target_area == "area_b" else "C"
	var area_name := "분광 실험동 B" if target_area == "area_b" else "동력 정비동 C"
	if not _player_in_area(target_area):
		var gate_position := Vector3(19, 0, 0) if target_area == "area_b" else Vector3(0, 0, 17)
		return {"text": "목표: %s로 이동하십시오. 안내는 발견한 출입문까지만 표시됩니다." % area_name, "position": gate_position, "known": visited_gate_ids.has(target_area), "gate": target_area, "label": area_name}
	if target_area == "area_b":
		if not white_spectrum_source.source_active:
			var source_id := String(white_spectrum_source.get_meta("map_id", "W-B02"))
			return {"text": "목표: 휴대 광선을 W-B02 입력부에 맞춰 고정 백색광원을 켜십시오.", "position": white_spectrum_source.global_position, "known": visited_device_ids.has(source_id), "label": "W-B02"}
		for receiver in spectrum_receivers:
			if not receiver.receiver_active:
				var receiver_id := String(receiver.get_meta("map_id", receiver.display_name))
				return {"text": "목표: B 실험동에서 RGB 수신기 조건을 맞추십시오.", "position": receiver.global_position, "known": visited_device_ids.has(receiver_id), "label": "R-B"}
	else:
		if not split_relay_a.receiver_active:
			var receiver_id := String(split_relay_a.get_meta("map_id", split_relay_a.display_name))
			return {"text": "목표: C 정비동에서 두 회로를 동시에 작동시키십시오.", "position": split_relay_a.global_position, "known": visited_device_ids.has(receiver_id), "label": "R-C"}
	return {"text": "%s 회로 복구를 확인했습니다. 중앙 배광실로 돌아가 다음 구역을 선택하십시오." % area_name, "position": Vector3.ZERO, "known": false}


func _player_in_area(area_id: String) -> bool:
	return _area_id_at(player.global_position) == area_id


func _update_navigation_label(goal: Dictionary) -> void:
	var area_id := _area_id_at(player.global_position)
	var area_name := String(discovered_areas.get(area_id, {}).get("label", "미확인 구역"))
	if nav_route.size() > 1:
		var next_cell: Vector2i = nav_route[1]
		var next_point := Vector3(float(next_cell.x) * 2.0 + 1.0, 0.0, float(next_cell.y) * 2.0 + 1.0)
		var delta := next_point - player.global_position
		var heading := "동쪽" if absf(delta.x) > absf(delta.z) and delta.x > 0.0 else ("서쪽" if absf(delta.x) > absf(delta.z) else ("남쪽" if delta.z > 0.0 else "북쪽"))
		nav_guidance = "안내: %s 방향 통로 · 목표까지 약 %.0fm" % [heading, player.global_position.distance_to(map_goal_position)]
	elif not bool(goal.get("known", false)):
		nav_guidance = "안내: 발견하지 않은 구역의 내부는 숨겨집니다. 출입문을 찾으십시오."
	else:
		nav_guidance = "안내: 발견한 통로에서 이동 경로를 확인 중입니다."
	navigation_label.text = "구역: %s
%s" % [area_name, nav_guidance]


func _select_destination(area_id: String) -> void:
	if area_id not in ["area_b", "area_c"]:
		return
	var circuit_id := "B" if area_id == "area_b" else "C"
	if progression.restored_circuits.has(circuit_id):
		return
	selected_destination = area_id
	_show_status("목적지 선택: %s" % ("B 분광 실험동" if area_id == "area_b" else "C 동력 정비동"))

func _area_id_at(position: Vector3) -> String:
	if position.x >= 32.0 and position.z >= -63.0 and position.z <= -21.0:
		return "control"
	if position.x >= 19.0 and position.z >= -25.0 and position.z <= 25.0:
		return "area_b"
	if position.z >= 25.0 and position.z <= 81.0 and position.x >= -37.5 and position.x <= 37.5:
		return "area_c"
	if position.x >= -20.0 and position.x <= 20.0 and position.z >= -53.0 and position.z <= -23.0:
		return "archive"
	if position.x <= -29.5 and position.x >= -74.5 and position.z >= -87.0 and position.z <= -53.0:
		return "sealed"
	if position.x >= 32.0 and position.x <= 78.0 and position.z >= -63.0 and position.z <= -21.0:
		return "control"
	if position.x >= -37.5 and position.x < -10.0 and position.z >= -22.0 and position.z < -1.0:
		return "tutorial"
	if position.x <= -19.0 and position.x >= -84.0 and position.z >= -7.0 and position.z <= 41.0:
		return "area_a"
	if position.x >= -19.0 and position.x < -10.0 and position.z >= -17.0 and position.z <= 17.0:
		return "area_a_lobby"
	if position.x >= -10.0 and position.x <= 19.0 and position.z >= -17.0 and position.z <= 17.0:
		return "hub"
	return ""


func _cell_for_position(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / 2.0), floori(position.z / 2.0))


func _position_for_cell(cell: Vector2i, height: float = 0.08) -> Vector3:
	return Vector3(float(cell.x) * 2.0 + 1.0, height, float(cell.y) * 2.0 + 1.0)


func _visible_from_player(point: Vector3, extra_exclude: Array[RID] = []) -> bool:
	var origin := player.global_position + Vector3.UP * 1.25
	var target := Vector3(point.x, maxf(point.y, 0.08), point.z)
	if origin.distance_squared_to(target) < 0.01:
		return true
	var query := PhysicsRayQueryParameters3D.create(origin, target, 4)
	query.exclude = [player.get_rid()] + extra_exclude
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_exploration(delta: float) -> void:
	scan_timer -= delta
	if scan_timer > 0.0:
		return
	scan_timer = 0.25
	current_cells.clear()
	var player_cell := _cell_for_position(player.global_position)
	for x in range(player_cell.x - 5, player_cell.x + 6):
		for z in range(player_cell.y - 5, player_cell.y + 6):
			var cell := Vector2i(x, z)
			var center := _position_for_cell(cell)
			var distance := Vector2(center.x - player.position.x, center.z - player.position.z).length()
			if distance > 10.0 or not _visible_from_player(center):
				continue
			explored_cells[cell] = true
			if distance <= 6.0:
				current_cells[cell] = true
	var area_id := _area_id_at(player.global_position)
	if not area_id.is_empty():
		if not discovered_areas.has(area_id):
			discovered_areas[area_id] = {"label": _area_name(area_id), "position": Vector3(player.position.x, 0.0, player.position.z)}
	if area_id == "area_a":
		a_lobby_visited = true
		_sync_progression_gates()
	for gate in get_tree().get_nodes_in_group("facility_map_gates"):
		if not gate is StaticBody3D:
			continue
		var gate_id := String(gate.get_meta("map_id", ""))
		if gate_id.is_empty():
			continue
		var horizontal := Vector2(player.position.x - gate.global_position.x, player.position.z - gate.global_position.z)
		if horizontal.length() > 13.0:
			continue
		var approach := Vector3(gate.global_position.x, 0.0, gate.global_position.z)
		if horizontal.length_squared() > 0.01:
			var offset := horizontal.normalized() * 1.8
			approach += Vector3(offset.x, 0.0, offset.y)
		if not _visible_from_player(approach, [gate.get_rid()]):
			continue
		visited_gate_ids[gate_id] = true
		var shape := gate.get_node_or_null("CollisionShape3D") as CollisionShape3D
		discovered_gates[gate_id] = {"position": Vector3(gate.global_position.x, 0.0, gate.global_position.z), "approach": approach, "name": String(gate.get_meta("map_label", gate.name)), "open": shape == null or shape.disabled, "area": String(gate.get_meta("map_area", ""))}
	for item in get_tree().get_nodes_in_group("optical_devices"):
		if not item is OpticalDevice:
			continue
		var device := item as OpticalDevice
		var device_id := String(device.get_meta("map_id", device.display_name))
		if Vector2(device.global_position.x - player.position.x, device.global_position.z - player.position.z).length() > 12.0:
			continue
		if _visible_from_player(device.global_position + Vector3.UP * float(device.get_meta("interaction_height", 0.9))):
			visited_device_ids[device_id] = true
	_refresh_navigation_route()
	_update_map_views()


func _area_name(area_id: String) -> String:
	return {"tutorial": "격리실 · 튜토리얼", "area_a_lobby": "A 입구 로비", "area_a": "A 반사 실험동", "hub": "H 중앙 배광실", "area_b": "B 분광 실험동", "area_c": "C 동력 정비동", "archive": "D 기록 보관실", "sealed": "E 폐쇄 구역", "control": "F 중앙 제어실"}.get(area_id, "연구 시설")


func _edge_is_clear(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var from_point := _position_for_cell(from_cell, 0.95)
	var to_point := _position_for_cell(to_cell, 0.95)
	var query := PhysicsRayQueryParameters3D.create(from_point, to_point, 12)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _refresh_navigation_route() -> void:
	nav_route.clear()
	if not map_goal_known or not current_goal.has("position"):
		return
	var goal_position: Vector3 = map_goal_position
	if current_goal.has("gate") and discovered_gates.has(String(current_goal["gate"])):
		goal_position = discovered_gates[String(current_goal["gate"])]["approach"]
	var start_cell := _cell_for_position(player.global_position)
	var end_cell := _cell_for_position(goal_position)
	if not explored_cells.has(start_cell) or not explored_cells.has(end_cell):
		return
	var queue: Array[Vector2i] = [start_cell]
	var parents: Dictionary = {start_cell: start_cell}
	var found := start_cell == end_cell
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i(0, 1), Vector2i(0, -1)]
	var cursor := 0
	while cursor < queue.size() and not found:
		var cell := queue[cursor]
		cursor += 1
		for direction in directions:
			var neighbor := cell + direction
			if parents.has(neighbor) or not explored_cells.has(neighbor) or not _edge_is_clear(cell, neighbor):
				continue
			parents[neighbor] = cell
			queue.append(neighbor)
			if neighbor == end_cell:
				found = true
				break
	if not found:
		return
	var cursor_cell := end_cell
	while cursor_cell != start_cell:
		nav_route.push_front(cursor_cell)
		cursor_cell = parents[cursor_cell]
	nav_route.push_front(start_cell)


func _update_map_views() -> void:
	if minimap_view == null or fullmap_view == null:
		return
	var direction := player.aim_position - player.global_position
	var facing := Vector2(direction.x, direction.z).normalized()
	if facing.is_zero_approx():
		facing = Vector2.UP
	var area_map: Dictionary = {}
	for area_id in discovered_areas:
		area_map[area_id] = discovered_areas[area_id]
	var door_map: Dictionary = {}
	for gate_id in discovered_gates:
		var gate_record: Dictionary = discovered_gates[gate_id]
		var shape_open := bool(gate_record.get("open", false))
		for gate_node in get_tree().get_nodes_in_group("facility_map_gates"):
			if String(gate_node.get_meta("map_id", "")) == String(gate_id):
				var gate_shape := gate_node.get_node_or_null("CollisionShape3D") as CollisionShape3D
				shape_open = gate_shape == null or gate_shape.disabled
				break
		gate_record["open"] = shape_open
		door_map[gate_id] = gate_record
	var device_map: Dictionary = {}
	for item in get_tree().get_nodes_in_group("optical_devices"):
		if not item is OpticalDevice:
			continue
		var device := item as OpticalDevice
		var device_id := String(device.get_meta("map_id", device.display_name))
		if not visited_device_ids.has(device_id):
			continue
		device_map[device_id] = {"position": Vector3(device.global_position.x, 0.0, device.global_position.z), "id": device_id.get_slice(" ", 0), "label": device.display_name.get_slice(" ", 0), "kind": device.kind, "color": device.receiver_color, "active": device.receiver_active or device.source_active}
	var goal := map_goal_position if map_goal_known else Vector3.ZERO
	for view in [minimap_view, fullmap_view]:
		view.cells = explored_cells
		view.current_cells = current_cells
		view.doors = door_map
		view.devices = device_map
		view.named_areas = area_map
		view.route = nav_route
		view.player_position = player.global_position
		view.facing = facing
		view.goal_position = goal
		view.goal_known = map_goal_known
		view.goal_label = String(current_goal.get("label", ""))
		view.queue_redraw()


func _save_exploration() -> void:
	var data := {"version": 1, "cells": [], "areas": {}, "gates": {}, "devices": []}
	for cell in explored_cells:
		data["cells"].append("%d:%d" % [cell.x, cell.y])
	for area_id in discovered_areas:
		var area: Dictionary = discovered_areas[area_id]
		var p: Vector3 = area["position"]
		data["areas"][area_id] = {"label": area["label"], "position": [p.x, p.z]}
	for gate_id in discovered_gates:
		var gate: Dictionary = discovered_gates[gate_id]
		var p: Vector3 = gate["position"]
		var a: Vector3 = gate["approach"]
		data["gates"][gate_id] = {"position": [p.x, p.z], "approach": [a.x, a.z], "name": gate["name"], "open": gate["open"], "area": gate["area"]}
	for device_id in visited_device_ids:
		data["devices"].append(String(device_id))
	var file := FileAccess.open(exploration_save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


func _load_exploration() -> void:
	var path := exploration_save_path
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("version", 0)) != 1:
		return
	for raw_cell in parsed.get("cells", []):
		var parts := String(raw_cell).split(":")
		if parts.size() == 2:
			explored_cells[Vector2i(int(parts[0]), int(parts[1]))] = true
	for area_id in parsed.get("areas", {}):
		var record: Dictionary = parsed["areas"][area_id]
		var p: Array = record.get("position", [0.0, 0.0])
		discovered_areas[String(area_id)] = {"label": record.get("label", _area_name(String(area_id))), "position": Vector3(float(p[0]), 0.0, float(p[1]))}
	for gate_id in parsed.get("gates", {}):
		var record: Dictionary = parsed["gates"][gate_id]
		var p: Array = record.get("position", [0.0, 0.0])
		var a: Array = record.get("approach", p)
		visited_gate_ids[String(gate_id)] = true
		discovered_gates[String(gate_id)] = {"position": Vector3(float(p[0]), 0.0, float(p[1])), "approach": Vector3(float(a[0]), 0.0, float(a[1])), "name": record.get("name", String(gate_id)), "open": bool(record.get("open", false)), "area": record.get("area", "")}
	for device_id in parsed.get("devices", []):
		visited_device_ids[String(device_id)] = true
	a_lobby_visited = discovered_areas.has("area_a")


func _update_nearby_prompt() -> void:
	var nearest := _nearest_device()
	device_info_label.text = "L-07 광원: %s
E: 가까운 장치 선택 또는 정보 확인 · L: 시스템 로그 · H: 조작 안내" % ("보유" if player.has_emitter else "미획득")
	for item in get_tree().get_nodes_in_group("optical_devices"):
		if item is OpticalDevice:
			item.set_targeted(item == nearest or item == selected_device)
	if nearest != null:
		device_info_label.text = "%s
%s
%s" % [nearest.display_name, nearest.get_function_text(), nearest.get_status_text()]
	if not progression.tutorial_completed:
		return
	if nearest == null:
		prompt_label.text = "WASD 이동 · 마우스 조준 · 좌클릭 유지: 광선 발사 · M: 미니맵 · Tab: 전체 지도"
	elif nearest.kind == "shutter":
		prompt_label.text = "%s · 자동 회전 중 · 제어 수신기로 작동 상태를 변경하십시오." % nearest.display_name
	elif nearest.kind == "receiver":
		prompt_label.text = "%s · E: 입력 조건과 상태 확인" % nearest.display_name
	elif nearest.rotatable:
		prompt_label.text = "E: %s 선택/해제 · 휠: 15° 회전 · Shift+휠: 1° 정밀 회전" % nearest.display_name
	else:
		prompt_label.text = "%s · 광선 입력 시 자동 작동 · E: 정보 확인" % nearest.display_name


func _nearest_device() -> OpticalDevice:
	var nearest: OpticalDevice
	var best_distance := 2.7
	for item in get_tree().get_nodes_in_group("optical_devices"):
		if not item is OpticalDevice:
			continue
		var device := item as OpticalDevice
		var distance := Vector2(device.global_position.x - player.global_position.x, device.global_position.z - player.global_position.z).length()
		if distance < best_distance and _visible_from_player(device.global_position + Vector3.UP * float(device.get_meta("interaction_height", 0.8))):
			best_distance = distance
			nearest = device
	return nearest


func _interact() -> void:
	if optical_control != null and optical_control.interact():
		return
	if a02_lab != null and a02_lab.interact():
		return
	var tutorial_id := progression.get_current_tutorial_id()
	if tutorial_id == "T-01":
		if not tutorial_move_completed:
			_show_status("먼저 WASD로 이동해 움직임을 확인하십시오.")
			return
		var terminal_distance := Vector2(tutorial_terminal.global_position.x - player.global_position.x, tutorial_terminal.global_position.z - player.global_position.z).length()
		if terminal_distance <= 2.8 and _visible_from_player(tutorial_terminal.global_position, [tutorial_terminal.get_rid()]):
			if progression.advance_tutorial("T-01"):
				_show_status("단말기 인증 완료. 광원 보관대 L-07에 접근할 수 있습니다.")
		else:
			_show_status("격리실 단말기 가까이 이동하십시오.")
		return
	if tutorial_id == "T-02" and not player.has_emitter:
		if Vector2(player.position.x - EMITTER_RACK.x, player.position.z - EMITTER_RACK.z).length() <= 1.8:
			player.set_emitter_acquired(true)
			_on_progression_changed()
			_show_status("L-07 획득 완료 · 출력 100%. 바닥 조준으로 수신기를 확인하십시오.")
		else:
			_show_status("광원 보관대 L-07 가까이 이동하십시오.")
		return
	var nearest := _nearest_device()
	if nearest == null:
		_show_status("가까운 장치 앞으로 이동하십시오.")
		return
	if selected_device == nearest:
		selected_device.set_selected(false)
		selected_device = null
		_show_status("%s 선택 해제" % nearest.display_name)
		return
	if selected_device != null:
		selected_device.set_selected(false)
	selected_device = null
	if nearest.rotatable and nearest.kind in ["mirror", "medium", "wedge_medium", "prism", "splitter"]:
		selected_device = nearest
		selected_device.set_selected(true)
		_show_status(nearest.interact())
	else:
		_show_status(nearest.interact())


func _rotate_selected(steps: int, fine: bool = false) -> void:
	if selected_device == null or not selected_device.rotatable:
		return
	if optical_control != null and optical_control.blocked_by_ui(player.pointer_position):
		return
	var distance := Vector2(selected_device.global_position.x - player.global_position.x, selected_device.global_position.z - player.global_position.z).length()
	var remote: bool = optical_control != null and optical_control.owns_selection()
	if optical_control != null and optical_control.control_mode and not remote:
		return
	if not remote and (distance > 4.5 or not _visible_from_player(selected_device.global_position + Vector3.UP * float(selected_device.get_meta("interaction_height", 0.8)))):
		selected_device.set_selected(false)
		selected_device = null
		_show_status("장치가 멀거나 시야에서 가려졌습니다. 가까이 이동해 다시 선택하십시오.")
		return
	if fine:
		selected_device.rotate_fine_steps(steps)
	else:
		selected_device.rotate_steps(steps)
	_show_status("%s · %d°" % [selected_device.display_name, int(rad_to_deg(wrapf(selected_device.rotation.y, 0.0, TAU)))])

func _reset_current_puzzle() -> void:
	if a02_lab != null and a02_lab.in_room():
		a02_lab.reset_lab()
		player.position = preload("res://scripts/a02_lab.gd").CONSOLE + Vector3(0, 0.1, 0)
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		return
	if not progression.tutorial_completed:
		_reset_all_progress()
		return
	var area_id := _area_id_at(player.global_position)
	if area_id not in ["area_a", "area_b", "area_c"]:
		area_id = "area_a"
	for item in get_tree().get_nodes_in_group("optical_devices"):
		if not item is OpticalDevice:
			continue
		if item in a02_lab.mirrors or item in [a02_lab.rail, a02_lab.control, a02_lab.receiver]:
			continue
		if _area_id_at(item.global_position) == area_id and (item.kind != "receiver" or not item.receiver_active):
			item.reset_device()
	if selected_device != null:
		selected_device.set_selected(false)
	selected_device = null
	var spawn: Vector3 = {"area_a": preload("res://scripts/a01_lab.gd").SPAWN, "area_b": Vector3(51, 0.03, 0), "area_c": Vector3(-3, 0.03, 58)}.get(area_id, player.position)
	player.position = spawn
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	_update_room_visibility()
	_show_status("%s 구역 장치를 초기 배치로 복원했습니다. 완료 회로는 유지됩니다." % area_id)

func _reset_all_progress() -> void:
	if a02_lab != null:
		a02_lab.reset_lab(true)
	if optical_control != null:
		optical_control.reset_permissions()
	for item in get_tree().get_nodes_in_group("optical_devices"):
		if item is OpticalDevice:
			item.reset_device()
	if selected_device != null:
		selected_device.set_selected(false)
	selected_device = null
	tutorial_move_completed = false
	tutorial_receiver.receiver_enabled = false
	tutorial_mirror_receiver.receiver_enabled = false
	player.position = Vector3(-21.0, 0.03, -15.0)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	player.set_emitter_acquired(false)
	tutorial_start_position = player.position
	hub_discovered = false
	a_lobby_visited = false
	intro_elapsed = 0.0
	system_logs.clear()
	progression.reset()
	_show_status("실험과 진행 상태를 처음부터 다시 시작합니다.")


func _sync_progression_gates() -> void:
	if a01_lab != null:
		a01_lab.sync()
	if tutorial_gate != null:
		var tutorial_open: bool = progression.tutorial_step_index >= 3 or progression.tutorial_completed
		if tutorial_gate_shape.disabled != tutorial_open:
			tutorial_gate_shape.set_deferred("disabled", tutorial_open)
		tutorial_gate.visible = not tutorial_open
	if tutorial_assessment_gate != null:
		var assessment_open: bool = progression.tutorial_completed
		if tutorial_assessment_gate_shape.disabled != assessment_open:
			tutorial_assessment_gate_shape.set_deferred("disabled", assessment_open)
		tutorial_assessment_gate.visible = not assessment_open
	if hub_gate != null:
		var hub_open: bool = progression.is_area_unlocked("hub")
		if hub_gate_shape.disabled != hub_open:
			hub_gate_shape.set_deferred("disabled", hub_open)
		hub_gate.visible = not hub_open
	for gate_record in area_gates.values():
		var gate_id := String((gate_record["gate"] as StaticBody3D).get_meta("map_id", ""))
		var area_id: String = gate_record["area_id"]
		var gate: StaticBody3D = gate_record["gate"]
		var shape: CollisionShape3D = gate_record["shape"]
		var is_open := progression.is_area_unlocked(area_id)
		if gate_id == "a_lobby_to_hub":
			is_open = a_lobby_visited
		elif gate_id in ["d_f_shortcut", "d_f_shortcut_f"]:
			is_open = progression.is_area_unlocked("archive") and progression.is_area_unlocked("control")
		if shape.disabled != is_open:
			shape.set_deferred("disabled", is_open)
		gate.visible = not is_open


func _on_progression_changed() -> void:
	tutorial_receiver.receiver_enabled = progression.get_current_tutorial_id() == "T-02" and player.has_emitter
	tutorial_mirror_receiver.receiver_enabled = progression.get_current_tutorial_id() == "T-03"
	tutorial_final_receiver.receiver_enabled = progression.get_current_tutorial_id() == "T-04"
	_sync_progression_gates()
	_update_tutorial_ui()
	facility_art.update_power(progression.restored_circuits, player.has_emitter)


func _on_receiver_activated(device: OpticalDevice) -> void:
	if device == tutorial_receiver and progression.get_current_tutorial_id() == "T-02":
		progression.advance_tutorial("T-02")
		_show_status("DIRECTOR: 발사 정확도 양호. 반사 교정 베이로 이동하십시오.")
	elif device == tutorial_mirror_receiver and progression.get_current_tutorial_id() == "T-03":
		progression.advance_tutorial("T-03")
		_show_status("DIRECTOR: 단일 반사 확인. 최종 적합성 검사를 시작합니다.")
	elif device == tutorial_final_receiver and progression.get_current_tutorial_id() == "T-04":
		progression.advance_tutorial("T-04")
		_show_status("DIRECTOR: 두 번의 반사 확인. 기초 적합성 검사가 완료되었습니다.")
	elif device == mirror_relay:
		if not progression.completed_stage_ids.has("A-01"):
			progression.completed_stage_ids.append("A-01")
		if progression.restore_circuit("A"):
			_show_status("주 회로 A 복구. 분광 실험동과 동력 정비동이 개방되었습니다.")
	elif spectrum_receivers.has(device):
		if progression.activate_spectrum_channel(device.receiver_color):
			progression.restore_circuit("B")
			_show_status("주 회로 B 복구. 기록 보관실 보안이 약화되었습니다.")
		else:
			_show_status("분광 채널 확인: %s" % device.receiver_color)
	elif device == shutter_control_receiver:
		test_shutter.shutter_running = false
		_show_status("차단막 제어 수신 완료 · 열린 위치에서 정지했습니다.")
	elif device == split_relay_a or device == split_relay_b:
		if split_relay_a.receiver_active and split_relay_b.receiver_active:
			if progression.restore_circuit("C"):
				_show_status("주 회로 C 복구. 동력 정비 기록이 갱신되었습니다.")
		else:
			_show_status("병렬 수신 확인. 두 수신기를 동시에 유지하세요.")
	else:
		_show_status("수신기 활성화: %s" % device.display_name)
	_update_objectives()


func _on_source_activated(device: OpticalDevice) -> void:
	_show_status("%s 입력 감지 · 고정 방향 백색광 출력이 시작되었습니다." % device.display_name)


func _show_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
		if system_logs.is_empty() or system_logs.back() != message:
			system_logs.append(message)
			if system_logs.size() > 10:
				system_logs.pop_front()
		log_label.text = "시스템 로그 / L 닫기\n\n" + "\n\n".join(system_logs)

func _toggle_pause() -> void:
	is_paused_overlay = not is_paused_overlay
	get_tree().paused = is_paused_overlay
	pause_panel.visible = is_paused_overlay

