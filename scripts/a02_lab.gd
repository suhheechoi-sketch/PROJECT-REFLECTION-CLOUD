extends Node3D
## One portable emitter, two console mirrors, one physically translated rail mirror.
const Pointer = preload("res://scripts/camera_pointer.gd")
const ORIGIN := Vector3(-82, 0, 27)
const DOCK := Vector3(-78, 0, 39)
const CONSOLE := Vector3(-81, 0, 38)
const HANDLE := Vector3(-70, 0, 40.2)
const CHANNELS := [Rect2(2.5, 1.5, 3, 10), Rect2(2.5, 1.5, 11, 3), Rect2(10.5, 1.5, 3, 11), Rect2(7.5, 6.5, 11, 3)]
var game: Node3D
var mirrors: Array[OpticalDevice] = []
var rail: OpticalDevice
var control: OpticalDevice
var receiver: OpticalDevice
var dock_mesh: MeshInstance3D
var docked := false
var emitting := false
var control_mode := false
var rail_selected := false
var selected: OpticalDevice
var camera_pose: Transform3D
var camera_size: float
var camera_mask: int
var channel := "red"

func build(world: Node3D) -> void:
	game = world
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 30
	name = "A02_docking_lab"
	for i in range(2):
		mirrors.append(game._create_device("mirror", "M-A02-%d" % (i + 1), ORIGIN + Vector3(4 if i == 0 else 12, 0, 3), Vector3(0.26, 2.3, 2.2), 0, Color("55b7b0")))
	rail = game._create_device("mirror", "M-A02-rail", ORIGIN + Vector3(9, 0, 8), Vector3(0.26, 2.3, 2.2), PI / 4, Color("d69a43"))
	rail.rotatable = false
	control = game._create_device("receiver", "R-A02-control", ORIGIN + Vector3(12, 0, 11.5), Vector3(0.72, 2.1, 0.7), 0, Color("d69a43"))
	receiver = game._create_device("receiver", "R-A02-final", ORIGIN + Vector3(17, 0, 8), Vector3(0.72, 2.1, 0.7), 0, Color("55b7b0"))
	control.required_seconds = 0.7
	receiver.required_seconds = 1.2
	_build_channel()
	for entry in [[CONSOLE, "A-02 광학 콘솔 / E\n클릭 선택 · 휠 회전 · Esc 종료"], [DOCK, "L-07 거치대 / E 탈착\nF 지속 조사 ON/OFF"], [HANDLE, "레일 손잡이 / E 선택\n휠: 현장 이동 (제어 R 필요)"]]:
		game._add_box("A02 STATION", entry[0] + Vector3(0, 0.35, 0), Vector3(0.55, 0.7, 0.55), game.materials["metal"], false)
		var label := Label3D.new()
		label.text = entry[1]
		label.position = entry[0] + Vector3(0, 1.8, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 22
		label.pixel_size = 0.008
		add_child(label)
	dock_mesh = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16, 0.16, 0.55)
	dock_mesh.mesh = mesh
	dock_mesh.position = DOCK + Vector3.UP * 1.15
	dock_mesh.material_override = game.materials["cyan"]
	dock_mesh.visible = false
	add_child(dock_mesh)
	game._add_box("A02 RAIL TRACK", ORIGIN + Vector3(10.5, 0.12, 8), Vector3(3.4, 0.08, 0.2), game.materials["yellow"], false)
	game._add_area_light(ORIGIN + Vector3(9, 2.5, 7), Color("d69a43"), 0.8, 15)

func _inside(p: Vector2) -> bool:
	for rect in CHANNELS:
		if rect.has_point(p):
			return true
	return false

func _build_channel() -> void:
	# Half-metre union boundary: no internal duplicate walls. Only the dock slit passes light.
	for x in range(5, 37):
		for z in range(3, 25):
			var cell := Vector2(x * 0.5 + 0.25, z * 0.5 + 0.25)
			if not _inside(cell):
				continue
			for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				if _inside(cell + d * 0.5):
					continue
				var p: Vector2 = cell + d * 0.25
				var slit: bool = is_equal_approx(p.y, 11.5) and absf(p.x - 4) < 0.3
				var size := Vector3(0.2, 2.8, 0.5) if d.x != 0 else Vector3(0.5, 2.8, 0.2)
				var body: StaticBody3D = game._add_box("A02 CHANNEL", ORIGIN + Vector3(p.x, 1.4, p.y), size, game.materials["wall"], true, 8 if slit else 4)
				if slit:
					(body.get_child(0) as MeshInstance3D).visible = false

func in_room() -> bool:
	return Rect2(-83, 26.3, 25, 14.5).has_point(Vector2(game.player.position.x, game.player.position.z))

func near(point: Vector3) -> bool:
	return game.player.position.distance_to(point) < 1.6 and game._visible_from_player(point + Vector3.UP * 0.5)

func ready_to_use() -> bool:
	return game.progression.tutorial_completed and game.mirror_relay.receiver_active

func interact() -> bool:
	if not in_room():
		return false
	if not ready_to_use():
		game._show_status("A-01 수신기를 먼저 활성화하십시오.")
		return true
	if control_mode:
		return true
	if near(CONSOLE):
		enter_control()
		return true
	if near(DOCK):
		if docked:
			retrieve()
		elif game.player.has_emitter:
			channel = game.player.emitter_channel
			docked = true
			emitting = true
			dock_mesh.visible = true
			game.player.set_emitter_acquired(false)
			game._show_status("L-07 거치 완료 · 지속 조사 중 · F 중지 · E 회수")
		return true
	if near(HANDLE):
		rail_selected = not rail_selected and control.receiver_active
		game._show_status("레일 선택 · 휠로 이동" if rail_selected else "레일 잠금 / 선택 해제")
		return true
	return false

func retrieve() -> void:
	docked = false
	emitting = false
	dock_mesh.visible = false
	game.player.set_emitter_acquired(true)
	game.optical_control.restore_fire_state()

func sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if docked and emitting and ready_to_use():
		result.append({"origin": DOCK + Vector3.UP * 1.15, "direction": Vector3.FORWARD, "channel": channel, "energy": 1.0, "active": true})
	return result

func enter_control() -> void:
	rail_selected = false
	if game.selected_device != null:
		game.selected_device.set_selected(false)
		game.selected_device = null
	camera_pose = game.camera.global_transform
	camera_size = game.camera.size
	camera_mask = game.camera.cull_mask
	control_mode = true
	game.puzzle_camera.set_physics_process(false)
	game.camera.cull_mask = game.puzzle_camera.original_mask
	game.camera.global_position = ORIGIN + Vector3(10, 24, 13)
	game.camera.look_at(ORIGIN + Vector3(10, 0, 6), Vector3.UP)
	game.camera.size = 31
	game.player.firing = false
	game.player.velocity = Vector3.ZERO

func exit_control() -> void:
	if not control_mode:
		return
	if selected != null:
		selected.set_selected(false)
	selected = null
	control_mode = false
	game.camera.global_transform = camera_pose
	game.camera.size = camera_size
	game.camera.cull_mask = camera_mask
	game.puzzle_camera.set_physics_process(true)
	game.optical_control.restore_fire_state()

func handle_input(event: InputEvent) -> bool:
	if control_mode:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			exit_control()
		elif event is InputEventMouseButton and event.pressed and not game.optical_control.blocked_by_ui(event.position):
			if event.button_index == MOUSE_BUTTON_LEFT:
				var ray := Pointer.ray(game.camera, event.position)
				var hit := game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray.origin, ray.origin + ray.direction * 100, 6))
				var picked: OpticalDevice = hit.get("collider") as OpticalDevice
				if selected != null:
					selected.set_selected(false)
				selected = picked if picked in mirrors and picked != selected else null
				if selected != null:
					selected.set_selected(true)
			elif selected != null and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				var steps := 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
				if event.shift_pressed:
					selected.rotate_fine_steps(steps)
				else:
					selected.rotate_steps(steps)
		# Reset and map/help still route through the normal input handler.
		return not (event is InputEventKey and event.keycode in [KEY_R, KEY_H, KEY_F1, KEY_TAB, KEY_L])
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F and near(DOCK) and docked:
		emitting = not emitting
		return true
	if rail_selected and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not game.optical_control.blocked_by_ui(event.position):
		move_rail(0.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.25)
		return true
	return false

func move_rail(distance: float) -> void:
	if control.receiver_active and near(HANDLE):
		rail.position.x = clampf(rail.position.x + distance, ORIGIN.x + 9, ORIGIN.x + 12)
		rail.reset_physics_interpolation()

func reset_lab(full: bool = false) -> void:
	exit_control()
	rail_selected = false
	if docked:
		retrieve()
	if full or not receiver.receiver_active:
		for device in mirrors + [rail, control, receiver]:
			device.reset_device()
		rail.position = ORIGIN + Vector3(9, 0, 8)
		rail.reset_physics_interpolation()

func _physics_process(_delta: float) -> void:
	if game == null or game.player == null:
		return
	control.receiver_enabled = ready_to_use()
	receiver.receiver_enabled = ready_to_use() and control.receiver_active
	if receiver.receiver_active and not game.progression.completed_stage_ids.has("A-02"):
		game.progression.completed_stage_ids.append("A-02")
		game._show_status("A-02 완료 · A-03은 개발 예정입니다. 발사기를 회수하십시오.")
	if not near(HANDLE):
		rail_selected = false
	if control_mode:
		if not in_room():
			exit_control()
		else:
			game.hud_summary.text = "A-02 광학 콘솔 · 클릭: 선택 · 휠: 회전 · Esc: 종료\n%s" % ("%s · %.0f°" % [selected.display_name, rad_to_deg(selected.rotation.y)] if selected != null else "M1 / M2 선택")
	elif in_room():
		game.hud_summary.text = "A-02 · %s\nE: 콘솔/거치/레일 · 거치대 F: 조사 ON/OFF\n제어 R %s · 최종 R %s · L-07 %s" % ["완료" if receiver.receiver_active else "거울 설정 → 거치 → 현장 레일 이동", "해금" if control.receiver_active else "잠금", "활성" if receiver.receiver_active else "대기", "거치/조사" if docked and emitting else ("거치/중지" if docked else "휴대")]
