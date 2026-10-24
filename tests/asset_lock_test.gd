extends SceneTree

func _initialize() -> void:
	var source := FileAccess.get_file_as_string("res://data/asset_lock.json")
	var lock: Variant = JSON.parse_string(source)
	if not lock is Dictionary or not lock.has("files"):
		printerr("Asset lock missing or invalid.")
		quit(1)
		return
	var failures := 0
	for item in lock["files"]:
		var path: String = item["path"]
		if FileAccess.get_sha256("res://" + path).to_lower() != String(item["sha256"]).to_lower():
			printerr("Locked asset changed: " + path)
			failures += 1
	print("Asset lock checks: %d file(s), %d failure(s)." % [lock["files"].size(), failures])
	quit(0 if failures == 0 else 1)
