extends CanvasLayer
## Preferences are separate from progression. Mode changes release every held touch.
var game: Node3D
var mode := "COMPUTER"
var settings_path := "user://reflection_input_preferences.cfg"
var settings_button: Button
var modal: Control
var box: PanelContainer
var fallback: CheckBox
var status: Label
var persistent := true
var observer_2d := false
var mode_buttons: Dictionary = {}

func setup(world: Node3D, save_preferences: bool) -> void:
	game = world
	persistent = save_preferences
	layer = 110
	mode = "MOBILE" if DisplayServer.is_touchscreen_available() or OS.has_feature("web") else "COMPUTER"
	var config := ConfigFile.new()
	var loaded: bool = persistent and config.load(settings_path) == OK
	if loaded:
		mode = str(config.get_value("input","mode",mode))
		observer_2d = bool(config.get_value("video","observer_2d",false))
	if mode not in ["COMPUTER","MOBILE"]: mode = "COMPUTER"
	settings_button = Button.new()
	settings_button.add_theme_font_override("font",ThemeDB.fallback_font)
	settings_button.text = "조작 / SETTINGS"
	settings_button.position = Vector2(24,190)
	settings_button.size = Vector2(240,52)
	settings_button.add_theme_font_size_override("font_size",24)
	settings_button.pressed.connect(open)
	add_child(settings_button)
	modal = ColorRect.new()
	modal.theme = game.hud_root.theme
	modal.color = Color(0.015,0.03,0.035,0.97)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	box = PanelContainer.new()
	modal.add_child(box)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",20)
	box.add_child(stack)
	stack.add_child(game._make_label("PROJECT: REFLECTION\n조작 방식 선택 / INPUT MODE",32,Color("a8efdf")))
	status = game._make_label("",24,Color.WHITE)
	stack.add_child(status)
	for choice in ["COMPUTER","MOBILE"]:
		var button := Button.new()
		button.text = choice+(" [C]" if choice == "COMPUTER" else " [M]")+ ("  ·  키보드 / 마우스" if choice == "COMPUTER" else "  ·  터치 조작")
		button.custom_minimum_size = Vector2(660,85)
		button.add_theme_font_size_override("font_size",30)
		mode_buttons[choice] = button
		button.pressed.connect(select_mode.bind(choice))
		stack.add_child(button)
	fallback = CheckBox.new()
	fallback.text = "저사양 관측: 3D 영상 대신 2D 경로 데이터"
	fallback.add_theme_font_size_override("font_size",24)
	fallback.button_pressed = observer_2d
	fallback.toggled.connect(set_observer_2d)
	stack.add_child(fallback)
	stack.add_child(game._make_label("언제든 조작 / SETTINGS에서 변경할 수 있습니다.\n선택한 방식은 게임 진행과 별도로 저장됩니다.",23,Color("b7cbc7")))
	modal.visible = persistent and not loaded
	apply()
	get_viewport().size_changed.connect(place)
	place()

func place() -> void:
	var view := get_viewport().get_visible_rect().size
	box.size = Vector2(760,510)
	box.position = (view-box.size)*0.5
	settings_button.position.y = maxf(190,game.hud_panel.get_global_rect().end.y+12)

func is_open() -> bool: return modal != null and modal.visible
func open() -> void:
	game.touch_controls.release_all()
	game.player.firing = false
	modal.visible = true
	apply()
func select_mode(value: String) -> void:
	if value not in ["COMPUTER","MOBILE"]: return
	mode = value
	print("INPUT MODE: " + mode)
	modal.visible = false
	game.restore_fire_state()
	apply()
	save()
func set_observer_2d(value: bool) -> void:
	observer_2d = value
	if game.beam_observer != null: game.beam_observer.set_fallback(value)
	save()
func apply() -> void:
	game.touch_controls.release_all()
	game.touch_controls.visible = mode == "MOBILE" and not is_open()
	if game.beam_observer != null: game.beam_observer.set_fallback(observer_2d)
	status.text = "현재: " + mode
	game.player.set_physics_process(not is_open() and not game.is_paused_overlay and game.ending_elapsed < 0)
func save() -> void:
	if not persistent: return
	var config := ConfigFile.new()
	config.set_value("input","mode",mode)
	config.set_value("video","observer_2d",observer_2d)
	var result := config.save(settings_path)
	if result != OK: status.text = "설정 저장 실패 (%d) · 현재 세션에는 적용됨" % result

func _input(event: InputEvent) -> void:
	if not is_open(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C: select_mode("COMPUTER")
		elif event.keycode == KEY_M: select_mode("MOBILE")
		else: return
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if game != null and settings_button != null:
		settings_button.position.y = maxf(190,game.hud_panel.get_global_rect().end.y+12)
