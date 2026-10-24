extends "res://assets/v4_0/device_visuals.gd"
## RF-DEV v5.1: nonparallel powered amplifier housing and status core.

static func decorate_wedge(device: OpticalDevice) -> void:
	var size := device.optical_size
	var outline: Array[Vector2] = [
		Vector2(-size.x * 0.5, -size.z * 0.5),
		Vector2(size.x * 0.5, -size.z * 0.5),
		Vector2(size.x * 0.5, size.z * 0.5),
		Vector2(-size.x * 0.07, size.z * 0.5)
	]
	var steel := material(Color("485552"))
	var cyan := material(Color("55b7b0"), 0.85)
	for vertex in outline:
		box(device, Vector3(0.1, size.y + 0.1, 0.1), Vector3(vertex.x, size.y * 0.5, vertex.y), steel)
	for index in range(outline.size()):
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var edge := b - a
		for height in [0.08, size.y - 0.08]:
			var rail := box(device, Vector3(0.09, 0.09, edge.length()), Vector3((a.x + b.x) * 0.5, height, (a.y + b.y) * 0.5), steel)
			rail.rotation.y = atan2(edge.x, edge.y)
	cylinder(device, 0.2, size.y * 0.6, Vector3(0, size.y * 0.5, 0), cyan)
	for index in range(3):
		box(device, Vector3(0.08, 0.15, 0.16), Vector3(size.x * 0.5 + 0.09, 0.42 + index * 0.3, 0), cyan if index < 2 else steel)
