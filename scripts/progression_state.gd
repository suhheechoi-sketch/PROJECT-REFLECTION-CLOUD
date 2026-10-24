extends RefCounted
class_name FacilityProgression

const StageCatalogScript = preload("res://scripts/stage_catalog.gd")

signal state_changed

const TUTORIAL_STAGE_IDS: Array[String] = ["T-01", "T-02", "T-03", "T-04"]

const AREA_DEFINITIONS: Dictionary = {
	"hub": {"name": "중앙 배광실", "act": 1},
	"area_a": {"name": "반사 실험동", "act": 1},
	"area_b": {"name": "분광 실험동", "act": 2},
	"area_c": {"name": "동력 정비동", "act": 2},
	"archive": {"name": "기록 보관실", "act": 3},
	"sealed": {"name": "폐쇄 구역", "act": 3},
	"control": {"name": "중앙 제어실", "act": 4},
	"shortcut": {"name": "B–C 정비 지름길", "act": 2}
}

var tutorial_step_index: int = 0
var tutorial_completed: bool = false
var restored_circuits: Array[String] = []
var spectrum_channels: Array[String] = []
var discovered_records: Array[String] = []
var unauthorized_receivers_activated: Array[String] = []
var emergency_control_record_found: bool = false
var completed_stage_ids: Array[String] = []
var stage_catalog: StageCatalog = StageCatalogScript.new()


func get_current_tutorial_step() -> Dictionary:
	if tutorial_completed or tutorial_step_index >= TUTORIAL_STAGE_IDS.size():
		return {}
	return stage_catalog.get_stage(TUTORIAL_STAGE_IDS[tutorial_step_index])


func get_current_tutorial_id() -> String:
	var step := get_current_tutorial_step()
	return String(step.get("id", "COMPLETE"))


func advance_tutorial(expected_id: String) -> bool:
	if get_current_tutorial_id() != expected_id:
		return false
	if not completed_stage_ids.has(expected_id):
		completed_stage_ids.append(expected_id)
	tutorial_step_index += 1
	if tutorial_step_index >= TUTORIAL_STAGE_IDS.size():
		tutorial_completed = true
	state_changed.emit()
	return true


func restore_circuit(circuit_id: String) -> bool:
	if not ["A", "B", "C"].has(circuit_id) or restored_circuits.has(circuit_id):
		return false
	restored_circuits.append(circuit_id)
	state_changed.emit()
	return true


func activate_spectrum_channel(channel: String) -> bool:
	if not ["red", "green", "blue"].has(channel) or spectrum_channels.has(channel):
		return false
	spectrum_channels.append(channel)
	state_changed.emit()
	return spectrum_channels.size() == 3


func discover_record(record_id: String) -> bool:
	if record_id.is_empty() or discovered_records.has(record_id):
		return false
	discovered_records.append(record_id)
	if record_id == "D-EMERGENCY_CONTROL":
		emergency_control_record_found = true
	state_changed.emit()
	return true


func activate_unauthorized_receiver(receiver_id: String) -> bool:
	if receiver_id not in ["A-UNAUTHORIZED", "B-UNAUTHORIZED", "C-UNAUTHORIZED"]:
		return false
	if unauthorized_receivers_activated.has(receiver_id):
		return false
	unauthorized_receivers_activated.append(receiver_id)
	state_changed.emit()
	return true


func get_unauthorized_receiver_count() -> int:
	return unauthorized_receivers_activated.size()


func is_area_unlocked(area_id: String) -> bool:
	match area_id:
		"hub", "area_a":
			return tutorial_completed
		"area_b", "area_c":
			return restored_circuits.has("A")
		"archive":
			return restored_circuits.size() >= 2
		"sealed":
			return unauthorized_receivers_activated.size() >= 2 and emergency_control_record_found
		"control":
			return restored_circuits.has("A") and restored_circuits.has("B") and restored_circuits.has("C")
		"shortcut":
			return restored_circuits.has("B") or restored_circuits.has("C")
		_:
			return false


func get_area_status(area_id: String) -> String:
	if is_area_unlocked(area_id):
		return "개방"
	match area_id:
		"hub", "area_a":
			return "T-04 완료 필요"
		"area_b", "area_c":
			return "주 회로 A 복구 필요"
		"archive":
			return "주 회로 2개 복구 필요"
		"sealed":
			return "비인가 수신기 2개와 비상 제어 기록 필요"
		"control":
			return "주 회로 A·B·C 복구 필요"
		"shortcut":
			return "B 또는 C 회로 복구 필요"
		_:
			return "정보 없음"


func get_restored_circuit_count() -> int:
	return restored_circuits.size()


func reset() -> void:
	tutorial_step_index = 0
	tutorial_completed = false
	restored_circuits.clear()
	spectrum_channels.clear()
	discovered_records.clear()
	unauthorized_receivers_activated.clear()
	emergency_control_record_found = false
	completed_stage_ids.clear()
	state_changed.emit()
