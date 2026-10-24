extends RefCounted
class_name StageCatalog

const DATA_PATH := "res://data/stages.json"

var _stages_by_id: Dictionary = {}


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not (parsed is Dictionary):
		push_error("Stage catalog could not be read: %s" % DATA_PATH)
		return
	for stage_value in parsed.get("stages", []):
		if stage_value is Dictionary:
			var stage_id := String(stage_value.get("id", ""))
			if not stage_id.is_empty():
				_stages_by_id[stage_id] = stage_value


func get_stage(stage_id: String) -> Dictionary:
	if not _stages_by_id.has(stage_id):
		return {}
	return (_stages_by_id[stage_id] as Dictionary).duplicate(true)


func get_all_stages() -> Array[Dictionary]:
	var stages: Array[Dictionary] = []
	for stage_value in _stages_by_id.values():
		stages.append((stage_value as Dictionary).duplicate(true))
	return stages


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not (parsed is Dictionary):
		errors.append("Stage catalog root must be a JSON object.")
		return errors
	var expected_count := int(parsed.get("stage_count", -1))
	if expected_count != _stages_by_id.size():
		errors.append("Stage count metadata does not match unique stage IDs.")
	for stage in get_all_stages():
		for requirement in stage.get("requires_all", []):
			var token := String(requirement)
			if token.begins_with("stage:") and not _stages_by_id.has(token.trim_prefix("stage:")):
				errors.append("%s refers to missing prerequisite %s." % [stage["id"], token])
	return errors
