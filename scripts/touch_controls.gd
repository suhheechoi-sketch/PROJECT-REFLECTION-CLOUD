extends Control
# Independent touch IDs allow movement, aiming and firing at the same time.
var game: Node3D
var contacts: Dictionary = {}
var buttons: Dictionary = {}
var fine := false

func setup(world: Node3D) -> void:
	game = world
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("web")
	get_viewport().size_changed.connect(release_all)
	_layout()

func _layout() -> void:
	var s := get_viewport_rect().size
	buttons = {
		"W": Rect2(100, s.y-440, 90, 80), "A": Rect2(10, s.y-350, 90, 80),
		"S": Rect2(100, s.y-350, 90, 80), "D": Rect2(190, s.y-350, 90, 80),
		"FIRE": Rect2(s.x-150, s.y-340, 130, 90),
		"E": Rect2(s.x-290, s.y-340, 120, 90),
		"-": Rect2(s.x-420, s.y-440, 90, 80), "+": Rect2(s.x-320, s.y-440, 90, 80),
		"FINE": Rect2(s.x-220, s.y-440, 100, 80), "F": Rect2(s.x-110, s.y-440, 90, 80),
		"ESC": Rect2(s.x-120, 360, 100, 70), "MAP": Rect2(s.x-230, 360, 100, 70),
		"HELP": Rect2(s.x-340, 360, 100, 70), "R": Rect2(s.x-450, 360, 100, 70), "LOG": Rect2(s.x-560, 360, 100, 70)
	}

func _draw() -> void:
	for label in buttons:
		var rect: Rect2 = buttons[label]
		draw_style_box(_style(label == "FINE" and fine or label in contacts.values()), rect)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 45), {"W":"↑", "A":"←", "S":"↓", "D":"→", "FIRE":"발사", "E":"조작", "FINE":"1°", "F":"출력", "ESC":"종료", "MAP":"지도", "HELP":"도움", "R":"재시도", "LOG":"기록"}.get(label,label), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)

func _style(on: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.5, 0.45, 0.85) if on else Color(0.03, 0.09, 0.09, 0.78)
	style.set_border_width_all(2)
	style.border_color = Color(0.4, 0.7, 0.65)
	return style

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var label := "AIM"
			for candidate in buttons:
				if buttons[candidate].has_point(event.position):
					label = candidate
					break
			contacts[event.index] = label
			if label == "AIM":
				_aim(event.position, true)
			elif label == "FINE":
				fine = not fine
			elif label not in ["W", "A", "S", "D", "FIRE"]:
				_activate(label)
		else:
			contacts.erase(event.index)
		_sync()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if contacts.get(event.index) == "AIM":
			_aim(event.position, false)
		get_viewport().set_input_as_handled()

func _aim(pixel: Vector2, select: bool) -> void:
	game.player.pointer_position = pixel
	if select and (game.optical_control.control_mode or game.a02_lab.control_mode):
		var event := InputEventMouseButton.new()
		event.position = pixel
		event.pressed = true
		event.button_index = MOUSE_BUTTON_LEFT
		game._input(event)

func _activate(label: String) -> void:
	if label in ["-", "+"]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_UP if label == "+" else MOUSE_BUTTON_WHEEL_DOWN
		event.position = game.player.pointer_position
		event.pressed = true
		event.shift_pressed = fine
		game._input(event)
	else:
		var event := InputEventKey.new()
		event.keycode = {"E": KEY_E, "F": KEY_F, "ESC": KEY_ESCAPE, "MAP": KEY_TAB, "HELP": KEY_H, "R": KEY_R, "LOG": KEY_L}[label]
		event.pressed = true
		game._input(event)

func _sync() -> void:
	var held := contacts.values()
	game.player.touch_movement = Vector2(float("D" in held)-float("A" in held), float("S" in held)-float("W" in held))
	game.player.touch_firing = "FIRE" in held
	queue_redraw()

func release_all() -> void:
	contacts.clear()
	_sync()
	_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and game != null:
		release_all()
