extends SceneTree

const StageCatalogScript = preload("res://scripts/stage_catalog.gd")

var failures: int = 0


func _initialize() -> void:
	var catalog: StageCatalog = StageCatalogScript.new()
	var stages := catalog.get_all_stages()
	_check(stages.size() == 19, "The stage catalog contains all 19 planned stages.")
	_check(catalog.get_stage("T-04").get("devices", []).size() == 2, "T-04 defines its two mirrors as data.")
	_check(catalog.get_stage("B-01").get("devices", []).has("G-B01"), "B-01 declares its implemented fixed ×2 amplifier.")
	_check(catalog.get_stage("B-02").get("devices", []).has("W-B02") and catalog.get_stage("B-02").get("implementation") == "playable", "B-02 declares its fixed white source and playable RGB path.")
	_check(catalog.get_stage("C-01").get("implementation") == "playable", "C-01 declares its tested simultaneous 50:50 relay path.")
	_check(catalog.get_stage("F-02").get("success", {}).get("type") == "four_phase_optical_boss", "F-02 retains the four-phase optical boss design.")
	for error_message in catalog.validate():
		_check(false, error_message)

	if failures == 0:
		print("Stage catalog checks passed.")
		quit(0)
	else:
		printerr("Stage catalog checks failed: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: %s" % message)
		failures += 1
