extends Node3D
## Visual-only alpha; physics bodies and optical surfaces are never touched.
var enabled := true
var console_room := Rect2()
var target: Node3D
var camera: Camera3D
var walls: Array[Dictionary] = []

func setup(world: Node, player: Node3D, view: Camera3D) -> void:
	target = player
	camera = view
	collect(world)

func collect(node: Node) -> void:
	if node is MeshInstance3D and node.mesh is BoxMesh:
		var size: Vector3 = node.mesh.size
		var parent := node.get_parent()
		# Structural walls and tall solid partitions; exclude optical devices and props.
		if (parent is StaticBody3D and parent.has_meta("room_structure")) or (parent.name == "FacilityArt_v5_1" and size.y >= 2.4 and maxf(size.x, size.z) >= 2.0 and minf(size.x, size.z) <= 0.7):
			var source: Material = node.material_override
			if source == null:
				source = node.mesh.surface_get_material(0)
			if source is StandardMaterial3D:
				var material := source.duplicate() as StandardMaterial3D
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				node.material_override = material
				walls.append({"visual": node, "material": material, "alpha": material.albedo_color.a})
	for child in node.get_children():
		collect(child)

func _process(delta: float) -> void:
	if target == null:
		return
	var pose := target.get_global_transform_interpolated()
	var toward_camera := camera.global_basis.z * 100.0
	for record in walls:
		var visual: MeshInstance3D = record.visual
		var blocked := false
		if enabled:
			var inverse := visual.global_transform.affine_inverse()
			for height in [0.4, 1.0, 1.65]:
				for side in [-0.24, 0.0, 0.24]:
					var point := pose.origin + Vector3(side, height, 0)
					if visual.get_aabb().intersects_segment(inverse * point, inverse * (point + toward_camera)):
						blocked = true
		var material: StandardMaterial3D = record.material
		var color := material.albedo_color
		var in_console: bool = console_room.has_area() and console_room.grow(0.25).has_point(Vector2(visual.global_position.x,visual.global_position.z))
		var goal := 0.15 if blocked or in_console else float(record.alpha)
		color.a = lerpf(color.a, goal, 1.0 - exp(-16.0 * delta))
		material.albedo_color = color
