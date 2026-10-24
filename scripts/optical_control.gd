extends Node
const Pointer = preload("res://scripts/camera_pointer.gd")
const ROOM_ID := "A01"
var game: Node3D
var permissions: Dictionary = {}
var control_mode := false
var restore_overview := false
var restore_manual_explore := false
var suppress_fire_until_release := false
var console: StaticBody3D
var hovered: OpticalDevice
var remote_selected: OpticalDevice
var console_label: Label3D
var led_material: StandardMaterial3D

func setup(world: Node3D) -> void:
	game = world
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 20
	# Reuse the existing room console and its collision; no new obstacle or beam source.
	console = game.get_node("CONTROL CONSOLE")
	console.set_meta("optical_control_room", ROOM_ID)
	console_label = Label3D.new()
	console_label.text = "광학 제어 콘솔\n가까이에서 E 연결"
	console_label.position = Vector3(0, 1.4, 0)
	console_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	console_label.font_size = 24
	console_label.pixel_size = 0.008
	console_label.layers = console.get_child(0).layers
	console.add_child(console_label)
	var led := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.12, 0.18)
	led.mesh = box
	led.position = Vector3(0.3, 0.85, 0)
	led.layers = console_label.layers
	led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	led_material = StandardMaterial3D.new()
	led_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	led.material_override = led_material
	console.add_child(led)
	_update_console()

func authorized() -> bool:
	return bool(permissions.get(ROOM_ID, false)) and game.puzzle_camera.in_room()

func active() -> bool:
	return control_mode and authorized() and game.puzzle_camera.overview and not game.is_paused_overlay and not game.fullmap_overlay.visible and not game.help_panel.visible and not game.log_panel.visible

func blocked_by_ui(pixel: Vector2) -> bool:
	if game.fullmap_overlay.visible or game.help_panel.visible or game.log_panel.visible or game.is_paused_overlay:
		return true
	for panel in [game.hud_panel, game.minimap_panel, game.prompt_panel, game.info_panel]:
		if panel.visible and panel.get_global_rect().has_point(pixel):
			return true
	return false

func near_console() -> bool:
	if not game.progression.tutorial_completed or not game.puzzle_camera.in_room():
		return false
	var distance := Vector2(game.player.position.x - console.position.x, game.player.position.z - console.position.z).length()
	var excluded: Array[RID] = [console.get_rid()]
	return distance <= 2.7 and game._visible_from_player(console.global_position + Vector3.UP * 0.5, excluded)

func interact() -> bool:
	if control_mode:
		return true
	if near_console():
		permissions[ROOM_ID] = true
		enter_control_mode()
		return true
	return false

func enter_control_mode() -> void:
	if not authorized():
		return
	restore_overview = game.puzzle_camera.overview
	restore_manual_explore = game.puzzle_camera.manual_explore
	control_mode = true
	game.puzzle_camera.overview = true
	game.puzzle_camera.manual_explore = false
	_update_console()
	game._show_status("A-01 광학 조작 모드 · 클릭: 거울 선택 · 휠: 회전 · Shift+휠: 정밀 회전 · Esc: 종료")

func exit_control_mode() -> void:
	if not control_mode:
		return
	clear_selection()
	control_mode = false
	restore_fire_state()
	game.puzzle_camera.overview = restore_overview
	game.puzzle_camera.manual_explore = restore_manual_explore
	game.puzzle_camera.last_selected = game.selected_device
	_update_console()
	game._show_status("A-01 광학 조작 종료")

func restore_fire_state() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		suppress_fire_until_release = true

func handle_pointer_click(pixel: Vector2) -> bool:
	if not control_mode:
		return false
	if not blocked_by_ui(pixel):
		select_at(pixel)
	return true

func pick_at(pixel: Vector2) -> OpticalDevice:
	if not active() or not game.get_viewport().get_visible_rect().has_point(pixel) or blocked_by_ui(pixel):
		return null
	var ray := Pointer.ray(game.camera, pixel)
	var query := PhysicsRayQueryParameters3D.create(ray.origin, ray.origin + ray.direction * game.camera.far, 6)
	query.exclude = [game.player.get_rid()]
	var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var device: Object = hit.collider
	if device is OpticalDevice and device.kind == "mirror" and device in game.a01_lab.mirrors and game.room_occlusion.is_accessible("a01"):
		return device
	return null

func select_at(pixel: Vector2) -> void:
	var mirror := pick_at(pixel)
	if mirror == null:
		clear_selection()
		return
	if game.selected_device == mirror:
		clear_selection()
		return
	if game.selected_device != null:
		game.selected_device.set_selected(false)
	game.selected_device = mirror
	remote_selected = mirror
	mirror.set_selected(true)

func owns_selection() -> bool:
	return remote_selected != null and remote_selected == game.selected_device and active() and remote_selected in game.a01_lab.mirrors

func clear_selection() -> void:
	var selected := remote_selected
	if selected == null and game.selected_device in game.a01_lab.mirrors:
		selected = game.selected_device
	if selected != null and game.selected_device == selected:
		selected.set_selected(false)
		game.selected_device = null
	remote_selected = null

func escape() -> bool:
	if control_mode:
		exit_control_mode()
		return true
	return false

func reset_permissions() -> void:
	control_mode = false
	clear_selection()
	permissions.clear()
	_update_console()

func _update_console() -> void:
	var connected := bool(permissions.get(ROOM_ID, false))
	console_label.text = "A-01 광학 제어 · 연결됨\nE: 광학 조작 시작" if connected else "광학 제어 콘솔\n가까이에서 E 연결"
	led_material.albedo_color = Color("55f0b0") if connected else Color("d69a43")

func _physics_process(_delta: float) -> void:
	if control_mode and not authorized():
		exit_control_mode()
	if remote_selected != null and (not control_mode or not authorized() or not game.puzzle_camera.overview or remote_selected != game.selected_device):
		clear_selection()
	hovered = pick_at(game.player.pointer_position) if active() else null
	if active():
		for mirror in game.a01_lab.mirrors:
			mirror.set_targeted(mirror == hovered or mirror == game.selected_device)
