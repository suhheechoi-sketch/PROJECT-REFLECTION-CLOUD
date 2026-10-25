extends RefCounted
## Additive visual generation. All optical surfaces, bodies and source origins stay unchanged.
static func box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh
static func ring(parent: Node3D, at: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := TorusMesh.new()
	shape.inner_radius = radius-0.025
	shape.outer_radius = radius+0.025
	shape.rings = 12
	shape.ring_segments = 4
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh
static func emitter(game: Node3D, parent: Node3D) -> void:
	box(parent,Vector3(0,0.10,0.05),Vector3(0.25,0.06,0.42),game.materials.metal)
	for side in [-1,1]: box(parent,Vector3(side*0.12,0,0.02),Vector3(0.06,0.24,0.50),game.materials.dark)
	var lens := ring(parent,Vector3(0,0,-0.285),0.11,game._emissive_material(Color("f75d45"),1.8))
	lens.rotation_degrees.x = 90
	box(parent,Vector3(0,0.14,0.02),Vector3(0.10,0.03,0.12),game.materials.cyan)
static func build(game: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Presentation_v1"
	game.add_child(root)
	emitter(game,game.player.emitter)
	emitter(game,game.a02_lab.dock_mesh)
	var devices: Array = game.devices.values()+game.a02_lab.mirrors+[game.a02_lab.rail,game.a02_lab.control,game.a02_lab.receiver]
	for device in devices:
		if device.kind == "mirror":
			# Tick plates lie below the beam plane and add no ray/body collision.
			ring(device,Vector3(0,0.10,0),0.68,game.materials.metal)
			var ticks: Array[Transform3D] = []
			for index in range(12):
				var angle := TAU*index/12.0
				ticks.append(Transform3D(Basis(Vector3.UP,-angle+PI/2).scaled(Vector3(0.05,0.025,0.18)),Vector3(cos(angle)*0.68,0.14,sin(angle)*0.68)))
			batch(device,ticks,game.materials.yellow)
			box(device,Vector3(0,device.optical_size.y+0.05,0),Vector3(0.32,0.12,0.5),game.materials.metal)
			box(device,Vector3(-0.16,device.optical_size.y*0.6,0),Vector3(0.035,0.12,device.optical_size.z*0.85),game.materials.cyan)
		elif device.kind == "receiver":
			var mount := Node3D.new()
			device.add_child(mount)
			if not device.required_direction.is_zero_approx(): mount.rotation.y = atan2(-device.required_direction.x,-device.required_direction.z)
			var lens := ring(mount,Vector3(0,1.65,-0.38),0.26,game.materials.metal)
			lens.rotation_degrees.x = 90
			var lens_state: StandardMaterial3D = game._emissive_material(Color("245255"),0.8)
			box(mount,Vector3(0,1.65,-0.37),Vector3(0.38,0.38,0.025),lens_state)
			device.set_meta("presentation_lens",lens_state)
			for side in [-1,1]:
				var arrow := box(mount,Vector3(side*0.13,0.045,-0.88),Vector3(0.05,0.025,0.30),game.materials.yellow)
				arrow.rotation.y = side*PI/4
			# State ring remains owned by the original receiver refresh code.
			if device.state_ring != null: device.state_ring.scale *= 1.08
	for rail in [game.a02_lab.rail,game.devices["A03-RAIL"]]:
		box(rail,Vector3(0,0.18,0),Vector3(0.7,0.18,0.8),game.materials.metal)
		var clamp: StandardMaterial3D = game._emissive_material(Color("d69a43"),0.7)
		box(rail,Vector3(0,0.30,0.40),Vector3(0.5,0.12,0.12),clamp)
		rail.set_meta("rail_clamp",clamp)
		for x in [-0.25,0.25]: box(rail,Vector3(x,0.10,0),Vector3(0.12,0.12,0.65),game.materials.dark)
	# Sparse edge equipment, batched into MultiMesh so room count does not multiply draw calls.
	var steel: Array[Transform3D] = []
	var rust: Array[Transform3D] = []
	var hazard: Array[Transform3D] = []
	for room in game.layout.rooms:
		if room.get("corridor",false): continue
		var b: Array = room.bounds
		var clean: bool = room.zone == "T"
		for i in range(2 if clean else 4):
			var p := Vector3(b[0]+0.32,0.3+i*0.32,(b[1]+b[3])*0.5)
			var size := Vector3(0.10,0.10,b[3]-b[1]-2)
			(steel if clean else rust).append(Transform3D(Basis.from_scale(size),p))
		# Worn edge tiles and safety strips at room boundaries, away from beam plane.
		for i in range(6):
			var p := Vector3(b[0]+1.3+i*0.4,0.018,b[3]-0.5)
			hazard.append(Transform3D(Basis(Vector3.UP,-0.45).scaled(Vector3(0.18,0.014,0.65)),p))
		if not clean:
			for i in range(6):
				rust.append(Transform3D(Basis.from_scale(Vector3(0.4+i*0.03,0.01,0.25)),Vector3(b[2]-0.8-i*0.7,0.012,b[1]+0.8+(i%2)*0.35)))
	batch(root,steel,game.materials.metal)
	batch(root,rust,game.materials.rust)
	batch(root,hazard,game.materials.yellow)
static func batch(parent: Node3D, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty(): return
	var mesh := BoxMesh.new()
	mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in range(transforms.size()): multi.set_instance_transform(i,transforms[i])
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = multi
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
