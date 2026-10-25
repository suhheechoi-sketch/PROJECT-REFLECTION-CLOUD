extends "res://scripts/main.gd"
## Dedicated T/A entry point; the existing facility scene remains available unchanged.
const Pointer = preload("res://scripts/camera_pointer.gd")
const SAVE_VERSION := 1
const ConsoleView = preload("res://scripts/ta_console_view.gd")
var touch_controls: Control
var layout: Dictionary
var devices: Dictionary = {}
var demo_doors: Dictionary = {}
var terminals: Dictionary = {}
var completed: Array[String] = []
var sequence := 0
var sequence_last_hit := ""
var accepted_receiver_this_frame := ""
var circuit_ready := false
var restored := false
var ending_elapsed := -1.0
var control_mode := false
var console_preview := false
var suppress_fire_until_release := false
var console_stage := ""
var rail_selected := false
var save_path := "user://reflection_ta_demo_v1.json"
var loaded_checkpoint := false
var checkpoint_enabled := true
var room_id := "T-01"
var overview := false
var camera_saved: Transform3D
var camera_saved_size := 17.0
var message_timer := 0.0
var ending_label: Label
var overlay: ColorRect
var history: Array[String] = []
var demo_geometry: RefCounted
var tone: AudioStreamPlayer
var hum: AudioStreamPlayer
var visited: Dictionary = {}
var map_scan_timer := 0.0
var demo_lights: Array[OmniLight3D] = []
var atmosphere_time := 0.0

func _ready() -> void:
	ThemeDB.fallback_font = preload("res://assets/fonts/NotoSansKR.ttf")
	set_meta("ta_demo", true)
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/ta_demo/layout.json"))
	_build_materials()
	materials.a_floor = _material(Color("28382c"),0.2,0.95)
	materials.tutorial_floor = _material(Color("a4b8b3"),0.15,0.9)
	_build_environment()
	demo_geometry = preload("res://scripts/ta_geometry.gd").new()
	demo_geometry.build(self)
	_build_player_and_camera()
	player.position = Vector3(5,0.03,8)
	tutorial_start_position = player.position
	player.collision_mask = 1 | 2 | 4 | 8
	optical_control = self
	player.optical_control = self
	puzzle_camera = preload("res://scripts/ta_camera_adapter.gd").new()
	add_child(puzzle_camera)
	_build_laser()
	build_demo_devices()
	preload("res://assets/ta_demo_details.gd").build(self)
	build_console_stations()
	build_demo_ui()
	var korean_theme := Theme.new()
	korean_theme.default_font = preload("res://assets/fonts/NotoSansKR.ttf")
	hud_root.theme = korean_theme
	for label in find_children("*", "Label3D", true, false):
		label.font = korean_theme.default_font
	wall_visibility = preload("res://scripts/wall_visibility.gd").new()
	add_child(wall_visibility)
	wall_visibility.setup(self,player,camera)
	load_checkpoint()
	sync_demo()
	_show_status("DIRECTOR: 피험자 07. 광학 적합성 검사를 시작합니다. 신원 단말기에서 E.")
	build_audio()
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 100
	add_child(touch_layer)
	var touch := preload("res://scripts/touch_controls.gd").new()
	touch_controls = touch
	touch_layer.add_child(touch)
	touch.setup(self)

func _relocate_device_position(_label: String, source: Vector3) -> Vector3:
	return source

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and player != null:
		save_checkpoint()

func sign_at(text: String, point: Vector3, floor_text := false) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = point
	label.font_size = 28
	label.pixel_size = 0.008
	label.modulate = Color("d4e5ce")
	if floor_text: label.rotation_degrees.x = -90
	else: label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func build_demo_devices() -> void:
	for stage in layout.stages:
		for item in layout.stages[stage].devices:
			if stage == "A-02": continue # Existing tested docking implementation owns these devices.
			var point := Vector3(item.p[0],0,item.p[1])
			if item.type in ["M","rail_M"] or item.type.begins_with("R-"):
				var kind := "mirror" if item.type in ["M","rail_M"] else "receiver"
				var size := Vector3(0.26,2.3,2.2) if kind == "mirror" else Vector3(0.72,2.1,0.7)
				var yaw := 0.0
				if item.type == "rail_M": yaw = deg_to_rad(-46)
				var device := _create_device(kind,item.id,point,size,yaw,Color("55b7b0"))
				device.set_meta("stage",stage)
				device.set_meta("interaction_height",0.4)
				device.rotatable = item.type != "rail_M"
				if kind == "receiver":
					device.required_seconds = 1.2
					if stage == "T-02": device.required_seconds = 0.65
					if stage in ["T-03","T-04"]: device.required_seconds = 0.8
					if item.id == "T03-RN": device.minimum_reflections = 1
					if item.id == "T04-RN":
						device.minimum_reflections = 2
						device.required_direction = Vector3.BACK
				devices[item.id] = device
				sign_at(item.id,point+Vector3.UP*2.75)
			else:
				terminals[item.id] = point
				_add_box(item.id,point+Vector3.UP*0.45,Vector3(0.65,0.9,0.5),materials.cyan,true,4)
				sign_at(item.id+" / E",point+Vector3.UP*1.8)
	# Keep A01 API used by the shared A02 prerequisite check.
	mirror_relay = devices["A01-RN"]
	a02_lab = preload("res://scripts/a02_lab.gd").new()
	add_child(a02_lab)
	a02_lab.build(self)
	player.station_control = a02_lab
	terminals["A03-HANDLE"] = Vector3(29.5,0,66)
	_add_box("A03 RAIL HANDLE",Vector3(29.5,0.5,66),Vector3(0.4,1,0.4),materials.yellow,true,4)
	sign_at("A03 레일 / E · 휠 0.25m",Vector3(29.5,1.8,66))
	_add_box("A03 RAIL TRACK",Vector3(25.5,0.1,66),Vector3(3.4,0.1,0.15),materials.yellow,false)
	# Metre coordinates of recommended firing pads; no scripted solution activation.
	for stage in ["T-02","T-03","T-04","A-01"]:
		var p: Array = layout.stages[stage].source
		pad(Vector3(p[0]-0.34,0.02,p[1]+0.38),stage+" L-07")
	for phase in layout.stages["A-03"].sources:
		var p: Array = layout.stages["A-03"].sources[phase]
		pad(Vector3(p[0]-0.34,0.02,p[1]+0.38),phase)

func build_console_stations() -> void:
	terminals["A03-CONSOLE"] = Vector3(9,0,75)
	_add_box("A03 CONSOLE BODY",terminals["A03-CONSOLE"]+Vector3.UP*0.45,Vector3(0.65,0.9,0.5),materials.metal,true,4)
	for item in [["A-01",terminals["A01-CONSOLE"]],["A-02",a02_lab.console_point],["A-03",terminals["A03-CONSOLE"]]]:
		var station: Node3D = preload("res://scenes/optical_console.tscn").instantiate()
		add_child(station)
		station.setup(self,item[0],item[1])
	var console_mirrors: Array = a02_lab.mirrors.duplicate()
	for device in devices.values():
		if device.kind == "mirror" and String(device.get_meta("stage")).begins_with("A-") and device.rotatable: console_mirrors.append(device)
	for device in console_mirrors:
		var outline := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = device.optical_size+Vector3(0.1,0.1,0.1)
		outline.mesh = mesh
		outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		outline.position.y = device.optical_size.y*0.5
		var mat := _emissive_material(Color("ffd075"),1.5)
		mat.cull_mode = BaseMaterial3D.CULL_FRONT
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		outline.material_override = mat
		outline.visible = false
		device.add_child(outline)
		device.selection_outline = outline
	for label in find_children("*","Label3D",true,false):
		if label.text == "A01-CONSOLE / E" or label.text.begins_with("A-02 광학 콘솔 /"): label.visible = false

func pad(at: Vector3,text: String) -> void:
	_add_box("FIRING PAD",at,Vector3(0.7,0.025,0.7),materials.yellow,false)
	sign_at(text,at+Vector3(0,0.03,0.65),true)

func build_demo_ui() -> void:
	var finish_layer := CanvasLayer.new()
	finish_layer.layer = 1
	add_child(finish_layer)
	var finish := ColorRect.new()
	finish.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	finish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var film := ShaderMaterial.new()
	film.shader = preload("res://assets/v4_0/film_grain.gdshader")
	finish.material = film
	finish_layer.add_child(finish)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_root)
	hud_panel = PanelContainer.new()
	hud_panel.position = Vector2(24,20)
	hud_panel.custom_minimum_size = Vector2(770,140)
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(hud_panel)
	hud_summary = _make_label("",22,Color("a8e9e2"))
	hud_panel.add_child(hud_summary)
	status_label = _make_label("",23,Color("ffd075"))
	status_label.position = Vector2(24,920)
	status_label.size = Vector2(1800,130)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_root.add_child(status_label)
	device_info_label = _make_label("",21,Color.WHITE)
	device_info_label.position = Vector2(24,810)
	device_info_label.size = Vector2(1700,100)
	hud_root.add_child(device_info_label)
	help_panel = PanelContainer.new()
	help_panel.position = Vector2(380,230)
	help_panel.size = Vector2(1100,500)
	help_panel.visible = false
	hud_root.add_child(help_panel)
	help_panel.add_child(_make_label("SUBJECT 07 / 조작 안내\n터치: 화살표 이동 · 화면 터치/드래그 조준 · 발사 유지\n조작=E · ±=회전/레일 · 1°=정밀 전환 · 출력=F · 종료=Esc\nWASD 이동 · 마우스 조준 · 좌클릭 유지 발사\nE 단말기 / 가까운 거울 선택 · 휠 15° / Shift+휠 1°\nA01/A02 콘솔 E → 클릭 거울 선택 → 휠 → Esc 종료\nA02 거치대 E 장착/회수 · F 조사 정지/재개\n레일 손잡이 E → 현장 휠 0.25m\nR 현재 퍼즐 재시도 · Shift+R 전체 초기화\nTab 탐색 지도 · M 미니맵 · L 기록 · H/F1 도움말\nEsc 일시 정지 / 창 닫기: 완료 단계 체크포인트 자동 저장",24,Color.WHITE))
	log_panel = PanelContainer.new()
	log_panel.position = Vector2(400,250)
	log_panel.size = Vector2(1100,550)
	log_panel.visible = false
	hud_root.add_child(log_panel)
	log_label = _make_label("",22,Color("a8e9e2"))
	log_panel.add_child(log_label)
	fullmap_overlay = ColorRect.new()
	fullmap_overlay.color = Color(0.02,0.04,0.035,0.95)
	fullmap_overlay.position = Vector2(360,180)
	fullmap_overlay.size = Vector2(1200,700)
	fullmap_overlay.visible = false
	hud_root.add_child(fullmap_overlay)
	map_label = _make_label("",22,Color.WHITE)
	map_label.position = Vector2(20,20)
	fullmap_overlay.add_child(map_label)
	fullmap_view = MapView.new()
	fullmap_view.position = Vector2(20,90)
	fullmap_view.size = Vector2(1160,580)
	fullmap_overlay.add_child(fullmap_view)
	minimap_panel = PanelContainer.new()
	minimap_panel.position = Vector2(1540,20)
	minimap_panel.size = Vector2(350,320)
	hud_root.add_child(minimap_panel)
	map_panel = minimap_panel
	objective_label = _make_label("",20,Color("a8e9e2"))
	var mini_stack := VBoxContainer.new()
	minimap_panel.add_child(mini_stack)
	mini_stack.add_child(objective_label)
	minimap_view = MapView.new()
	minimap_view.mini = true
	minimap_view.custom_minimum_size = Vector2(330,210)
	mini_stack.add_child(minimap_view)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0,0,0,0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(overlay)
	ending_label = _make_label("",42,Color("a8e9e2"))
	ending_label.position = Vector2(430,400)
	ending_label.size = Vector2(1100,300)
	ending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_root.add_child(ending_label)

func _physics_process(delta: float) -> void:
	if is_paused_overlay: return
	room_id = current_room()
	if room_id == "A-LOBBY" and not visited.has(room_id):
		_show_status("DIRECTOR: 반사 실험동. A 회로를 복구하십시오. [기록 07: 입장 기록 없음]")
	visited[room_id] = true
	atmosphere_time += delta
	for i in range(demo_lights.size()):
		if i % 3 == 0: demo_lights[i].light_energy = 0.7 + sin(atmosphere_time*3.1+i)*0.1
		if ending_elapsed >= 0 and ending_elapsed < 2: demo_lights[i].light_energy = 0.15 if int(ending_elapsed*4)%2 == 0 else 0.85
	var sources: Array[Dictionary] = a02_lab.sources()
	accepted_receiver_this_frame = ""
	laser.update_beam(player.get_emitter_origin(),player.aim_position,((player.firing and not control_mode and not a02_lab.control_mode) or (control_mode and console_preview and player.has_emitter and not blocked_by_ui(Vector2(-1,-1)))) and ending_elapsed < 0,delta,"red",sources)
	check_sequence_reentry()
	if progression.completed_stage_ids.has("A-02") and not completed.has("A-02"):
		complete("A-02")
	sync_demo()
	if control_mode: ConsoleView.fit(self,console_stage)
	elif a02_lab.control_mode: ConsoleView.fit(self,"A-02")
	else:
		if overview and room_id == "A-01":
			ConsoleView.fit(self,"A-01")
		else:
			ConsoleView.restore_walls(self)
			overview = false
			camera.position = Vector3(0,11,4.0)
			camera.rotation_degrees = Vector3(-70,0,0)
			camera.size = 18
	if selected_device != null and not control_mode and player.position.distance_to(selected_device.position) > 4.5:
		clear_demo_selection()
	if not near_point(terminals["A03-HANDLE"],2.0): rail_selected = false
	update_demo_map(delta)
	update_demo_hud(delta)
	if ending_elapsed >= 0:
		ending_elapsed += delta
		overlay.color = Color(0,0,0,clampf(ending_elapsed-2,0,1))
		if ending_elapsed < 2: overlay.color = Color(0.6,0.85,0.75,0.15 if int(ending_elapsed*4)%2 == 0 else 0.0)
		ending_label.text = "PROJECT: REFLECTION\nT/A DEMO END\n피험자 07 / 입장 기록 없음\nShift+R: 다시 시작" if ending_elapsed >= 3 else "DIRECTOR: 검사가 완료되었습니다.\n…해당 피험자의 입장 기록이 없습니다."

func current_room() -> String:
	for room in layout.rooms:
		var b: Array = room.bounds
		if Rect2(b[0],b[1],b[2]-b[0],b[3]-b[1]).has_point(Vector2(player.position.x,player.position.z)):
			return room.id
	return "시설 통로"

func sync_demo() -> void:
	progression.tutorial_completed = completed.has("T-04_TERMINAL_E")
	progression.tutorial_step_index = 0
	for stage in completed:
		if not progression.completed_stage_ids.has(stage): progression.completed_stage_ids.append(stage)
		if stage in ["T-01","T-02","T-03","T-04"]: progression.tutorial_step_index += 1
	for id in devices:
		var d: OpticalDevice = devices[id]
		if d.kind != "receiver": continue
		var stage: String = d.get_meta("stage")
		d.receiver_enabled = stage == next_stage() or stage == "A-03" and completed.has("A-02")
	for door in layout.doors:
		var open: bool = door.unlock == "START" or completed.has(door.unlock)
		var body: StaticBody3D = demo_doors[door.id]
		body.visible = not open
		body.get_node("CollisionShape3D").set_deferred("disabled",open)
	if not completed.has("A-03") and sequence == 0: circuit_ready = false

func next_stage() -> String:
	for id in ["T-01","T-02","T-03","T-04","T-04_TERMINAL_E","A-01","A-02","A-03"]:
		if not completed.has(id): return id
	return "A-REST"

func _on_receiver_activated(device: OpticalDevice) -> void:
	if not devices.values().has(device): return # A02 is managed by its original lab.
	var id := String(device.name)
	var stage := String(device.get_meta("stage"))
	if id == "A03-RU":
		progression.activate_unauthorized_receiver(id)
		_show_status("기록 07: 입장 기록 없음. 검사 기록은 이미 존재합니다.")
		return
	if stage == "A-03":
		var expected: String = ["A03-RO1","A03-RO2","A03-RN"][mini(sequence,2)]
		if id != expected:
			reset_sequence()
			_show_status("DIRECTOR: 순서 오류. R-O1 → R-O2 → R-N으로 재시도하십시오.")
			return
		accepted_receiver_this_frame = id
		sequence += 1
		if sequence == 3:
			circuit_ready = true
			complete("A-03")
			_show_status("A 회로 READY · 복구실 단말기에서 E로 복구하십시오.")
		else:
			_show_status("순서 %d/3 승인 · 다음 수신기로 이동하십시오." % sequence)
		chime()
		return
	if stage == next_stage():
		complete(stage)
		chime()

func check_sequence_reentry() -> void:
	if completed.has("A-03") or not completed.has("A-02"): return
	var hit_id := ""
	for id in ["A03-RO1","A03-RO2","A03-RN"]:
		if devices[id]._hit_this_frame:
			hit_id = id
			break
	if not hit_id.is_empty() and hit_id != sequence_last_hit and hit_id != accepted_receiver_this_frame:
		var expected: String = ["A03-RO1","A03-RO2","A03-RN"][mini(sequence,2)]
		if hit_id != expected and devices[hit_id].receiver_active:
			reset_sequence()
			_show_status("DIRECTOR: 순서 오류. R-O1부터 재시도하십시오.")
	sequence_last_hit = hit_id

func reset_sequence() -> void:
	if completed.has("A-03"): return
	sequence = 0
	for id in ["A03-RO1","A03-RO2","A03-RN"]:
		devices[id].reset_device()

func complete(stage: String) -> void:
	if completed.has(stage): return
	completed.append(stage)
	if stage == "A-02" and not progression.completed_stage_ids.has(stage): progression.completed_stage_ids.append(stage)
	_show_status("DIRECTOR: %s 승인. 다음 검사 구역이 해금되었습니다." % stage)
	sync_demo()
	save_checkpoint()

func near_point(point: Vector3,distance := 2.7) -> bool:
	return Vector2(player.position.x-point.x,player.position.z-point.z).length() <= distance

func _visible_from_player(point: Vector3,extra_exclude: Array[RID] = []) -> bool:
	var query := PhysicsRayQueryParameters3D.create(player.position+Vector3.UP*0.4,point,4)
	query.exclude = [player.get_rid()]+extra_exclude
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func blocked_by_ui(pixel: Vector2) -> bool:
	if touch_controls != null and touch_controls.visible and touch_controls.button_at(pixel) != "": return true
	return help_panel.visible or log_panel.visible or fullmap_overlay.visible or is_paused_overlay or hud_panel.get_global_rect().has_point(pixel) or minimap_panel.visible and minimap_panel.get_global_rect().has_point(pixel)

func restore_fire_state() -> void:
	suppress_fire_until_release = player.touch_firing or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _interact() -> void:
	if ending_elapsed >= 0 or control_mode: return
	if a02_lab.interact(): return
	for id in terminals:
		var point: Vector3 = terminals[id]
		if not near_point(point): continue
		match id:
			"T-ID":
				if not completed.has("T-01"):
					if player.position.distance_to(tutorial_start_position) < 2:
						_show_status("WASD로 2m 이상 이동한 뒤 단말기에서 E를 누르십시오.")
						return
					complete("T-01")
				_show_status("DIRECTOR: 피험자 07 신원 승인. T-02에서 L-07을 수령하십시오.")
			"L-07-PICKUP":
				if completed.has("T-01") and not a02_lab.docked:
					player.set_emitter_acquired(true)
					_show_status("L-07 수령 · 마우스로 수신기를 조준하고 좌클릭을 유지하십시오.")
			"T-EXIT":
				if completed.has("T-04"): complete("T-04_TERMINAL_E")
				else: _show_status("적합성 수신기를 먼저 활성화하십시오.")
			"A01-CONSOLE":
				if completed.has("T-04_TERMINAL_E"): enter_demo_console()
			"A03-CONSOLE":
				if completed.has("A-02"): enter_demo_console("A-03")
				else: _show_status("A-02를 먼저 완료하십시오.")
			"A03-HANDLE":
				rail_selected = not rail_selected and completed.has("A-02")
				_show_status("레일 선택 · 휠 0.25m 이동" if rail_selected else "레일 선택 해제")
			"A-RESTORE":
				if circuit_ready:
					restored = true
					progression.restore_circuit("A")
					ending_elapsed = 0.0
					player.firing = false
					player.set_physics_process(false)
					_show_status("DIRECTOR: 회로 A 복구 완료. 검사 기록 대조 중…")
					save_checkpoint()
				else: _show_status("A 회로 NOT READY · A-03을 완료하십시오.")
			"A-LOG": _show_status("실험 기록 07: 검사는 17회 완료됨. 입장 기록: 없음. DIRECTOR: 기록을 무시하십시오.")
		return
	var nearest: OpticalDevice
	var best := 2.7
	for d in devices.values():
		if d.kind != "mirror" or String(d.get_meta("stage")).begins_with("A-") or not d.rotatable: continue
		var distance: float = player.position.distance_to(d.position)
		if distance < best:
			nearest = d
			best = distance
	if nearest != null:
		var same := nearest == selected_device
		clear_demo_selection()
		if not same:
			selected_device = nearest
			selected_device.set_selected(true)

func enter_demo_console(stage := "A-01") -> void:
	clear_demo_selection()
	control_mode = true
	console_preview = false
	console_stage = stage
	camera_saved = camera.global_transform
	camera_saved_size = camera.size
	ConsoleView.enter(self)
	ConsoleView.fit(self,stage)
	player.firing = false
	player.velocity = Vector3.ZERO

func exit_demo_console() -> void:
	clear_demo_selection()
	control_mode = false
	console_preview = false
	ConsoleView.restore_walls(self)
	camera.global_transform = camera_saved
	camera.size = camera_saved_size
	camera.reset_physics_interpolation()
	restore_fire_state()

func clear_demo_selection() -> void:
	if selected_device != null: selected_device.set_selected(false)
	selected_device = null

func _input(event: InputEvent) -> void:
	if player == null: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if control_mode: exit_demo_console()
			elif a02_lab.control_mode: a02_lab.exit_control()
			else:
				is_paused_overlay = not is_paused_overlay
				player.set_physics_process(not is_paused_overlay and ending_elapsed < 0)
				player.firing = false
				_show_status("일시 정지 · Esc 재개" if is_paused_overlay else "검사 재개")
			return
		if event.keycode == KEY_F and control_mode:
			console_preview = not console_preview and player.has_emitter
			_show_status("콘솔 위치의 실제 L-07 출력 " + ("ON" if console_preview else "OFF"))
			return
		if event.keycode == KEY_R:
			if event.shift_pressed: reset_demo(true)
			else: reset_demo(false)
			return
		if is_paused_overlay or ending_elapsed >= 0: return
		match event.keycode:
			KEY_H,KEY_F1: help_panel.visible = not help_panel.visible
			KEY_L: log_panel.visible = not log_panel.visible
			KEY_TAB: fullmap_overlay.visible = not fullmap_overlay.visible
			KEY_M: minimap_panel.visible = not minimap_panel.visible
			KEY_V: overview = not overview and room_id == "A-01" and not control_mode
			KEY_E:
				if not blocked_by_ui(Vector2(-1,-1)): _interact()
	if is_paused_overlay or ending_elapsed >= 0 or blocked_by_ui(Vector2(-1,-1)): return
	if a02_lab.handle_input(event): return
	if event is InputEventMouseButton and event.pressed and not blocked_by_ui(event.position):
		if control_mode and event.button_index == MOUSE_BUTTON_LEFT:
			var allowed: Array = []
			for device in devices.values():
				if device.kind == "mirror" and device.rotatable and device.get_meta("stage") == console_stage: allowed.append(device)
			var picked: OpticalDevice = ConsoleView.pick(self,event.position,allowed,bool(event.get_meta("console_touch",false)))
			var same := picked == selected_device
			clear_demo_selection()
			if picked != null and picked.get_meta("stage","") == console_stage and picked.kind == "mirror" and picked.rotatable and not same:
				selected_device = picked
				picked.set_selected(true)
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var steps := 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			if rail_selected and near_point(terminals["A03-HANDLE"],2):
				devices["A03-RAIL"].position.x = clampf(devices["A03-RAIL"].position.x+steps*0.25,24,27)
				devices["A03-RAIL"]._sync_physics_transform()
			elif selected_device != null:
				if event.shift_pressed: selected_device.rotate_fine_steps(steps)
				else: selected_device.rotate_steps(steps)

func reset_demo(full: bool) -> void:
	if control_mode: exit_demo_console()
	a02_lab.exit_control()
	clear_demo_selection()
	rail_selected = false
	var location := current_room()
	var stage := location if location in layout.stages else next_stage()
	if full:
		completed.clear()
		progression.reset()
		circuit_ready = false
		restored = false
		sequence = 0
		ending_elapsed = -1
		ending_label.text = ""
		overlay.color.a = 0
		visited.clear()
		explored_cells.clear()
		current_cells.clear()
		for d in devices.values(): d.reset_device()
		devices["A03-RAIL"].position.x = 24
		a02_lab.reset_lab(true)
		player.set_emitter_acquired(false)
		player.position = Vector3(5,0.03,8)
	elif not completed.has(stage):
		if stage == "A-02": a02_lab.reset_lab()
		for d in devices.values():
			if d.get_meta("stage") == stage: d.reset_device()
		if stage == "A-03":
			reset_sequence()
			devices["A03-RAIL"].position.x = 24
		player.position = checkpoint_position(stage)
	else:
		_show_status("완료 상태를 유지합니다. Shift+R은 전체 초기화입니다.")
		return
	is_paused_overlay = false
	player.set_physics_process(true)
	player.firing = false
	player.reset_physics_interpolation()
	sync_demo()
	save_checkpoint()
	_show_status("검사 장치를 초기화했습니다. 완료 단계는 보존됩니다.")

func checkpoint_position(stage: String) -> Vector3:
	return {"T-01":Vector3(5,0.03,8),"T-02":Vector3(21,0.03,14),"T-03":Vector3(35,0.03,14),"T-04":Vector3(47,0.03,14),"T-04_TERMINAL_E":Vector3(47,0.03,14),"A-01":Vector3(35,0.03,45),"A-02":Vector3(12,0.03,48),"A-03":Vector3(10,0.03,73),"A-REST":Vector3(47,0.03,64)}.get(stage,Vector3(5,0.03,8))

func save_checkpoint() -> void:
	if not checkpoint_enabled: return
	var temp := save_path+".tmp"
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file == null:
		_show_status("체크포인트 저장 실패 · 저장 권한을 확인하십시오.")
		return
	var explored: Array = []
	for c in explored_cells: explored.append([c.x,c.y])
	file.store_string(JSON.stringify({"cells":explored,"version":SAVE_VERSION,"completed":completed,"restored":restored,"emitter":player.has_emitter or a02_lab.docked}))
	file.close()
	var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(save_path))
	if result != OK: _show_status("체크포인트 교체 실패 · 오류 %s" % result)

func load_checkpoint() -> void:
	if not checkpoint_enabled or not FileAccess.file_exists(save_path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or data.get("version",0) != SAVE_VERSION: return
	for c in data.get("cells",[]):
		if c is Array and c.size() == 2: explored_cells[Vector2i(int(c[0]),int(c[1]))] = true
	# Only accept an ordered prefix; corrupt/out-of-order flags cannot unlock doors.
	for id in ["T-01","T-02","T-03","T-04","T-04_TERMINAL_E","A-01","A-02","A-03"]:
		if not data.get("completed",[]).has(id): break
		completed.append(id)
	for d in devices.values():
		var stage: String = d.get_meta("stage")
		if d.kind == "receiver" and completed.has(stage):
			d.receiver_active = true
			d._refresh_visual()
	if completed.has("A-02"):
		progression.completed_stage_ids.append("A-02")
		a02_lab.control.receiver_active = true
		a02_lab.receiver.receiver_active = true
		a02_lab.control._refresh_visual()
		a02_lab.receiver._refresh_visual()
	circuit_ready = completed.has("A-03")
	sequence = 3 if circuit_ready else 0
	restored = circuit_ready and bool(data.get("restored",false))
	player.set_emitter_acquired(completed.has("T-01") and bool(data.get("emitter",false)))
	player.position = checkpoint_position(next_stage())
	if restored:
		progression.restore_circuit("A")
		ending_elapsed = 3
		player.set_physics_process(false)
	loaded_checkpoint = true

func update_demo_hud(delta: float) -> void:
	message_timer -= delta
	var goal: String = {"T-01":"신원 단말기 E","T-02":"L-07 지급대 E → R-N 직사","T-03":"거울 E/휠 → 1회 반사","T-04":"거울 2개 E/휠 → 2회 반사","T-04_TERMINAL_E":"T-04 검사 종료 단말기 E","A-01":"콘솔 E → 거울 3개 설정 → 발사 패드","A-02":"콘솔 → L-07 거치 E → 제어 R → 현장 레일 → 발사기 회수","A-03":"광학 콘솔 E: 거울 설정 → RO1 → RO2 → RN / 현장 레일 E","A-REST":"A 회로 READY → 복구 단말기 E"}.get(next_stage(),"")
	var mode := "휴대 / 좌클릭 조사" if player.has_emitter else "L-07 미보유"
	if a02_lab.docked: mode = "L-07 거치 / "+("지속 조사" if a02_lab.emitting else "정지")
	if control_mode or a02_lab.control_mode: mode = "광학 콘솔 / 클릭 선택 · 휠 15° · Shift+휠 1° · Esc 종료"
	hud_summary.text = "PROJECT: REFLECTION / T·A DEMO v1.0\n%s · %s\n목표: %s\nWASD · E 상호작용 · R 재시도 · H 도움말" % [room_id,mode,goal]
	status_label.position.y = get_viewport().get_visible_rect().size.y-240 if control_mode or a02_lab.control_mode else 920
	device_info_label.position.y = get_viewport().get_visible_rect().size.y-190 if control_mode or a02_lab.control_mode else 810
	var selected: OpticalDevice = a02_lab.selected if a02_lab.control_mode else selected_device
	device_info_label.text = "%s · %.0f°" % [selected.display_name,rad_to_deg(selected.rotation.y)] if selected != null else ""
	if control_mode: device_info_label.text += "\nF / 출력: 실제 L-07 광선 · " + ("ON" if console_preview else "OFF")
	if rail_selected: device_info_label.text = "A03 레일 %.2fm / 3m · 휠 0.25m" % (devices["A03-RAIL"].position.x-24)
	if room_id == "A-03" and not control_mode: device_info_label.text += "\n순서 %d/3 · R-U 선택 사항" % sequence
	if room_id == "A-02": device_info_label.text += "\n제어 R %s · 최종 R %s · 레일 %.2f / 4m" % ["활성" if a02_lab.control.receiver_active else "대기","활성" if a02_lab.receiver.receiver_active else "대기",a02_lab.rail.position.x-19]
	if selected == null and not control_mode and not a02_lab.control_mode:
		for id in terminals:
			if near_point(terminals[id]):
				device_info_label.text += "\n%s · E" % id
		for d in devices.values():
			if player.position.distance_to(d.position) < 3:
				device_info_label.text += "\n"+d.get_status_text()+" · E / 휠"
	for door in layout.doors:
		if near_point(Vector3(door.x,0,door.z),2):
			device_info_label.text += "\n%s · %s" % [door.id,"해금 / 통과 가능" if not demo_doors[door.id].visible else "잠김 / 필요: "+door.unlock]
	for station in [["A02 광학 제어 콘솔",a02_lab.console_point],["L-07 거치대",a02_lab.dock_point],["A02 레일 손잡이",a02_lab.handle_point]]:
		if a02_lab.near(station[1]): device_info_label.text += "\n%s · E / 조작" % station[0]
	var known: Array[String] = []
	for room in layout.rooms:
		if visited.has(room.id): known.append(room.id)
	map_label.text = "방문한 구역\n"+" → ".join(known)
	objective_label.text = "체크포인트 %d/8\nA 회로 %s\nTab 방문 구역" % [completed.size(),"RESTORED" if restored else ("READY" if circuit_ready else "OFFLINE")]
	log_label.text = "DIRECTOR / FACILITY 17\n"+"\n".join(history.slice(maxi(0,history.size()-12)))
	# Overlays safely stop movement and held firing without stopping the UI.
	if ending_elapsed < 0: player.set_physics_process(not (help_panel.visible or log_panel.visible or fullmap_overlay.visible))
	if help_panel.visible or log_panel.visible or fullmap_overlay.visible: player.firing = false

func _show_status(message: String) -> void:
	if status_label != null: status_label.text = message
	message_timer = 7
	history.append(message)

func build_audio() -> void:
	tone = AudioStreamPlayer.new()
	add_child(tone)
	hum = AudioStreamPlayer.new()
	add_child(hum)
	if DisplayServer.get_name() == "headless": return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 22050
	var bytes := PackedByteArray()
	bytes.resize(44100)
	for i in range(22050): bytes.encode_s16(i*2,int(sin(TAU*50*i/22050.0)*350+sin(TAU*101*i/22050.0)*100))
	stream.data = bytes
	hum.stream = stream
	hum.volume_db = -18
	hum.play()

func chime() -> void:
	if tone == null: return
	if DisplayServer.get_name() == "headless": return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(11024)
	for i in range(5512): bytes.encode_s16(i*2,int(sin(TAU*660*i/22050.0)*2500*(1-i/5512.0)))
	stream.data = bytes
	tone.stream = stream
	tone.play()

func _exit_tree() -> void:
	if hum != null:
		hum.stop()
		hum.stream = null
	if tone != null:
		tone.stop()
		tone.stream = null

func update_demo_map(delta: float) -> void:
	map_scan_timer -= delta
	if map_scan_timer > 0: return
	map_scan_timer = 0.25
	current_cells.clear()
	var center := Vector2i(floori(player.position.x/2),floori(player.position.z/2))
	for x in range(center.x-5,center.x+6):
		for z in range(center.y-5,center.y+6):
			var c := Vector2i(x,z)
			var point := Vector3(x*2+1,1.65,z*2+1)
			if point.distance_to(player.position+Vector3.UP*1.65) > 10: continue
			var on_floor := false
			for room in layout.rooms:
				var b: Array = room.bounds
				if Rect2(b[0],b[1],b[2]-b[0],b[3]-b[1]).has_point(Vector2(point.x,point.z)): on_floor = true
			if not on_floor: continue
			var query := PhysicsRayQueryParameters3D.create(player.position+Vector3.UP*1.65,point,4|8)
			query.exclude = [player.get_rid()]
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				explored_cells[c] = true
				current_cells[c] = true
	var known_doors := {}
	for door in layout.doors:
		var p := Vector3(door.x,0,door.z)
		if not explored_cells.has(Vector2i(floori(p.x/2),floori(p.z/2))): continue
		known_doors[door.id] = {"position":p,"approach":p,"name":door.id,"open":not demo_doors[door.id].visible}
	var known_devices := {}
	for d in devices.values():
		if explored_cells.has(Vector2i(floori(d.position.x/2),floori(d.position.z/2))):
			known_devices[d.name] = {"position":d.position,"active":d.receiver_active,"kind":d.kind,"color":"white","id":d.name}
	for view in [minimap_view,fullmap_view]:
		view.cells = explored_cells
		view.current_cells = current_cells
		view.player_position = player.position
		view.facing = Vector2(player.aim_position.x-player.position.x,player.aim_position.z-player.position.z)
		view.doors = known_doors
		view.devices = known_devices
		view.queue_redraw()

func _add_area_light(at: Vector3,color: Color,energy: float,radius: float) -> void:
	super._add_area_light(at,color,energy,radius)
	var light := get_child(get_child_count()-1) as OmniLight3D
	if light != null and at.z >= 26: demo_lights.append(light)
