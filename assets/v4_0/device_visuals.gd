extends RefCounted
## Locked procedural asset family RF-DEV v4.0. See ASSET_MANIFEST.md.

static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = 0.55
	result.roughness = 0.78
	if glow > 0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = glow
	return result


static func box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	parent.add_child(node)
	return node


static func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	parent.add_child(node)
	return node


static func ring(parent: Node3D, radius: float, thickness: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius
	mesh.rings = 16
	mesh.ring_segments = 6
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	parent.add_child(node)
	return node


static func decorate(device: OpticalDevice) -> void:
	var steel := material(Color("485552"))
	var dark := material(Color("192625"))
	var amber := material(Color("d69a43"), 0.4)
	var cyan := material(Color("55b7b0"), 0.7)
	var size := device.optical_size
	# All trim is visual-only. The existing optical surface owns collision.
	cylinder(device, 0.48 if device.kind != "medium" else 0.9, 0.16, Vector3(0, 0.12, 0), dark)
	match device.kind:
		"mirror", "splitter":
			for side in [-1.0, 1.0]:
				box(device, Vector3(0.19, size.y + 0.12, 0.13), Vector3(0, size.y / 2, side * (size.z / 2 + 0.04)), steel)
				box(device, Vector3(size.x + 0.09, 0.12, size.z + 0.18), Vector3(0, 0.12 if side < 0 else size.y, 0), steel)
			cylinder(device, 0.13, 0.24, Vector3(0, size.y + 0.12, 0), amber)
			for tick in range(24):
				var angle := deg_to_rad(tick * 15.0)
				var mark := box(device, Vector3(0.035, 0.025, 0.14 if tick % 3 == 0 else 0.07), Vector3(sin(angle) * 0.65, 0.09, cos(angle) * 0.65), amber)
				mark.rotation.y = angle
			if device.kind == "splitter":
				for sign_value in [-1.0, 1.0]:
					var fork := box(device, Vector3(0.12, 0.16, 0.9), Vector3(sign_value * 0.42, size.y + 0.15, 0), amber)
					fork.rotation.y = sign_value * PI / 4.0
		"medium":
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					box(device, Vector3(0.1, size.y, 0.1), Vector3(x * size.x * 0.5, size.y / 2, z * size.z * 0.5), steel)
			box(device, Vector3(size.x + 0.14, 0.16, size.z + 0.14), Vector3(0, size.y, 0), dark)
			cylinder(device, 0.2, 1.0, Vector3(0, size.y / 2, 0), cyan)
			for index in range(3):
				box(device, Vector3(0.08, 0.17, 0.18), Vector3(size.x / 2 + 0.06, 0.45 + index * 0.3, 0), cyan if index < 2 else dark)
		"prism":
			# Optical triangle is also the visible triangle, avoiding the old mesh mismatch.
			var points := PackedVector3Array([
				Vector3(-size.x / 2, 0, -size.z / 2), Vector3(size.x / 2, 0, -size.z / 2), Vector3(0, 0, size.z / 2)])
			for point in points:
				box(device, Vector3(0.08, size.y + 0.1, 0.08), point + Vector3.UP * size.y / 2, steel)
			for index in range(3):
				var a := points[index]
				var b := points[(index + 1) % 3]
				for height in [0.12, size.y]:
					var rail := box(device, Vector3(0.09, 0.1, a.distance_to(b)), (a + b) / 2 + Vector3.UP * height, cyan)
					rail.rotation.y = atan2((b - a).x, (b - a).z)
		"shutter":
			for side in [-1.0, 1.0]:
				box(device, Vector3(0.17, size.y + 0.1, 0.14), Vector3(0, size.y / 2, side * size.z / 2), steel)
			for height in range(6):
				box(device, Vector3(size.x + 0.03, 0.09, size.z * 0.9), Vector3(0, 0.25 + height * 0.32, 0), amber)
			cylinder(device, 0.22, 0.32, Vector3(0, size.y + 0.12, 0), steel)
		"receiver":
			box(device, Vector3(size.x + 0.16, 0.3, size.z + 0.16), Vector3(0, 0.24, 0), dark)
			device.state_ring = ring(device, 0.49, 0.09, Vector3(0, size.y + 0.05, 0), amber)
			var symbol := Label3D.new()
			symbol.text = "R"
			symbol.font_size = 44
			symbol.pixel_size = 0.008
			symbol.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			symbol.position = Vector3(0, size.y + 0.28, 0)
			device.add_child(symbol)
			device.type_mark = symbol
	device.set_targeted(false)
