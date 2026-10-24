extends Control
class_name ExplorationMapView

var cells: Dictionary = {}
var current_cells: Dictionary = {}
var doors: Dictionary = {}
var devices: Dictionary = {}
var named_areas: Dictionary = {}
var route: Array[Vector2i] = []
var player_position := Vector3.ZERO
var facing := Vector2.UP
var goal_position := Vector3.ZERO
var goal_known := false
var goal_label := ""
var mini := false

const SIZE_METERS := 2.0

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("020506"), true)
	var scale_value: float
	var center := player_position
	if mini:
		scale_value = minf(size.x, size.y) / 52.0
	else:
		if cells.is_empty():
			return
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for cell in cells:
			low.x = minf(low.x, float(cell.x) * SIZE_METERS)
			low.y = minf(low.y, float(cell.y) * SIZE_METERS)
			high.x = maxf(high.x, float(cell.x + 1) * SIZE_METERS)
			high.y = maxf(high.y, float(cell.y + 1) * SIZE_METERS)
		var content_size := size - Vector2(32, 32)
		scale_value = maxf(2.0, minf(content_size.x / maxf(high.x - low.x, 1), content_size.y / maxf(high.y - low.y, 1)))
		center = Vector3((low.x + high.x) * 0.5, 0, (low.y + high.y) * 0.5)
	if mini:
		center.x = player_position.x
		center.z = player_position.z
	for cell in cells:
		if mini and Vector2(float(cell.x * 2 + 1) - center.x, float(cell.y * 2 + 1) - center.z).length() > 25.0:
			continue
		var color := Color("444d4b")
		if current_cells.has(cell):
			color = Color("82918a")
		var at := _point(Vector2(float(cell.x) * 2.0, float(cell.y) * 2.0), center, scale_value)
		draw_rect(Rect2(at, Vector2(2, 2) * scale_value - Vector2(1, 1)), color, true)
		if current_cells.has(cell):
			draw_rect(Rect2(at, Vector2(2, 2) * scale_value - Vector2(1, 1)), Color(0.9, 0.97, 0.93, 0.2), false, 1)
	for area_id in named_areas:
		var area: Dictionary = named_areas[area_id]
		if not cells.has(_cell(area["position"])):
			continue
		var text_at := _point(Vector2(area["position"].x, area["position"].z), center, scale_value)
		if not mini:
			draw_string(ThemeDB.fallback_font, text_at, String(area["label"]), HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color("d4d4ba"))
	for door_id in doors:
		var door: Dictionary = doors[door_id]
		if not mini and not cells.has(_cell(door["approach"])):
			continue
		if mini and Vector2(door["position"].x - center.x, door["position"].z - center.z).length() > 25.0:
			continue
		var p := _point(Vector2(door["position"].x, door["position"].z), center, scale_value)
		var c: Color = Color("65c8bd") if door["open"] else Color("db7255")
		draw_circle(p, maxf(3.0, scale_value * 0.48), c)
		if not mini:
			draw_string(ThemeDB.fallback_font, p + Vector2(5, -5), String(door["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
	for device_id in devices:
		var device: Dictionary = devices[device_id]
		if not cells.has(_cell(device["position"])):
			continue
		var p := _point(Vector2(device["position"].x, device["position"].z), center, scale_value)
		var c: Color = Color("62e083") if device["active"] else Color("f2ce73")
		if device["kind"] == "receiver" and device["color"] != "white":
			c = {"red": Color("f06059"), "green": Color("62e083"), "blue": Color("6597f0")}.get(device["color"], c)
		draw_circle(p, maxf(2.5, scale_value * 0.3), c)
		if not mini:
			draw_string(ThemeDB.fallback_font, p + Vector2(4, -3), String(device["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c)
	if goal_known and cells.has(_cell(goal_position)):
		var goal_point := _point(Vector2(goal_position.x, goal_position.z), center, scale_value)
		draw_circle(goal_point, maxf(4.0, scale_value * 0.62), Color("ffd166"), false, 2.0)
		if not mini and not goal_label.is_empty():
			draw_string(ThemeDB.fallback_font, goal_point + Vector2(7, 14), goal_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffe5a0"))
	if not mini:
		for cell in route:
			var p := _point(Vector2(cell.x * 2.0 + 1.0, cell.y * 2.0 + 1.0), center, scale_value)
			draw_circle(p, maxf(2.0, scale_value * 0.2), Color("f3c766"))
	var player_point := _point(Vector2(player_position.x, player_position.z), center, scale_value)
	var direction := facing.normalized()
	if direction.is_zero_approx():
		direction = Vector2.UP
	var forward := Vector2(direction.x, direction.y) * maxf(7.0, scale_value * 1.1)
	var side := Vector2(-direction.y, direction.x) * maxf(3.5, scale_value * 0.48)
	draw_colored_polygon(PackedVector2Array([player_point + forward, player_point - forward * 0.65 + side, player_point - forward * 0.65 - side]), Color("fff3a0"))

func _point(world: Vector2, center: Vector3, scale_value: float) -> Vector2:
	return size * 0.5 + Vector2(world.x - center.x, world.y - center.z) * scale_value

func _cell(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / SIZE_METERS), floori(position.z / SIZE_METERS))
