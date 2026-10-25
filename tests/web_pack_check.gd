extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL PACK: " + message)
func _initialize() -> void:
	var expected := "res://scenes/ta_demo.tscn"
	check(ProjectSettings.get_setting("application/run/main_scene") == expected, "Web pack must boot the T/A scene")
	check(ResourceLoader.exists(expected), "Missing T/A main scene")
	for source in ["res://scripts/ta_geometry.gd", "res://scripts/ta_console_view.gd", "res://scripts/ta_console_station.gd", "res://scenes/optical_console.tscn", "res://scripts/beam_observer.gd", "res://scripts/input_preferences.gd", "res://scripts/puzzle_feedback.gd", "res://assets/presentation_v1/industrial_details.gd", "res://scenes/beam_observer.tscn", "res://scenes/input_preferences.tscn"]:
		check(ResourceLoader.exists(source), "Missing gameplay resource: " + source)
	var info = JSON.parse_string(FileAccess.get_file_as_string("res://data/build_info.json"))
	check(info is Dictionary and str(info.get("commit", "")).length() == 40, "Missing actual commit stamp")
	if info is Dictionary:
		check(info.get("main_scene", "") == expected, "Build manifest scene mismatch")
		var args := OS.get_cmdline_user_args()
		if not args.is_empty(): check(info.get("commit", "") == args[0], "PCK commit differs from actual checkout")
		if failures == 0: print("PASS: packed main scene, PR5 and observer resources; Build: " + str(info.commit))
	quit(0 if failures == 0 else 1)
