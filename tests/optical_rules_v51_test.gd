extends SceneTree
## Exercises the v5.1 device laws through the same physical ray tracer used in play.

var failures := 0
var world: Node3D
var laser: ReflectionLaser


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL v5.1 optics: " + message)
		failures += 1


func _box_device(kind: String, at: Vector3, size: Vector3, yaw: float = 0.0) -> OpticalDevice:
	var device := OpticalDevice.new()
	device.configure(kind, kind, Color.CYAN)
	device.position = at
	device.rotation.y = yaw
	device.optical_size = size
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	device.add_child(shape)
	world.add_child(device)
	return device


func _prism(at: Vector3, yaw: float = 0.0) -> OpticalDevice:
	var size := Vector3(1.7, 2.2, 1.4)
	var device := OpticalDevice.new()
	device.configure("prism", "P-test", Color.CYAN)
	device.position = at
	device.rotation.y = yaw
	device.optical_size = size
	var points := PackedVector3Array()
	for y in [-size.y * 0.5, size.y * 0.5]:
		points.append(Vector3(-size.x * 0.5, y, -size.z * 0.5))
		points.append(Vector3(size.x * 0.5, y, -size.z * 0.5))
		points.append(Vector3(0.0, y, size.z * 0.5))
	var shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	shape.shape = hull
	shape.position.y = size.y * 0.5
	device.add_child(shape)
	world.add_child(device)
	return device


func _wedge_amplifier(at: Vector3) -> OpticalDevice:
	var size := Vector3(2.2, 2.0, 1.8)
	var device := OpticalDevice.new()
	device.configure("wedge_medium", "G-WEDGE-test", Color.CYAN)
	device.position = at
	device.optical_size = size
	device.amplification = 2.0
	device.refractive_indices = {"white": 1.5, "red": 1.5, "green": 1.5, "blue": 1.5}
	var shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	var half_height := size.y * 0.5
	hull.points = PackedVector3Array([
		Vector3(-size.x * 0.5, -half_height, -size.z * 0.5),
		Vector3(size.x * 0.5, -half_height, -size.z * 0.5),
		Vector3(size.x * 0.5, -half_height, size.z * 0.5),
		Vector3(-size.x * 0.07, -half_height, size.z * 0.5),
		Vector3(-size.x * 0.5, half_height, -size.z * 0.5),
		Vector3(size.x * 0.5, half_height, -size.z * 0.5),
		Vector3(size.x * 0.5, half_height, size.z * 0.5),
		Vector3(-size.x * 0.07, half_height, size.z * 0.5)
	])
	shape.shape = hull
	shape.position.y = size.y * 0.5
	device.add_child(shape)
	world.add_child(device)
	return device


func _trace(start: Vector3, direction: Vector3, channel: String = "white", energy: float = 1.0) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	laser._trace(start, direction, channel, energy, segments)
	return segments


func _tail_for_channel(segments: Array[Dictionary], channel: String) -> Dictionary:
	var found: Dictionary = {}
	for segment in segments:
		if String(segment.get("channel", "")) == channel:
			found = segment
	return found


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	laser = ReflectionLaser.new()
	world.add_child(laser)
	await physics_frame
	await physics_frame

	var normal_amp := _box_device("medium", Vector3.ZERO, Vector3(1.0, 2.0, 3.0))
	normal_amp.amplification = 2.0
	var normal_segments := _trace(Vector3(-3, 1, 0), Vector3.RIGHT)
	_check(normal_segments.size() >= 3 and is_equal_approx(float(normal_segments[2].energy), 2.0), "The fixed basic amplifier automatically doubles power once on entry.")
	_check(is_equal_approx(normal_amp.amplifier_input_energy, 1.0), "The amplifier reports its incoming power without offering a multiplier control.")
	_check(normal_amp.get_function_text().contains("통과 시 자동 작동"), "The interaction text describes automatic amplification.")
	_check(not normal_amp.get_function_text().contains("Q"), "No Q multiplier control is advertised.")
	world.remove_child(normal_amp)
	normal_amp.free()
	await physics_frame

	var high_amp := _box_device("medium", Vector3.ZERO, Vector3(1.0, 2.0, 3.0))
	high_amp.amplification = 3.0
	var high_segments := _trace(Vector3(-3, 1, 0), Vector3.RIGHT, "white", 1.0)
	_check(high_segments.size() >= 3 and is_equal_approx(float(high_segments[2].energy), 3.0), "The high-output unit automatically triples power and respects the 300% cap.")
	world.remove_child(high_amp)
	high_amp.free()
	await physics_frame

	var slab := _box_device("medium", Vector3.ZERO, Vector3(1.0, 2.0, 3.0), deg_to_rad(17.0))
	slab.amplification = 2.0
	var incident := Vector3(1.0, 0.0, 0.32).normalized()
	var source := Vector3(-3.0, 1.0, -0.1)
	var slab_segments := _trace(source, incident)
	var outgoing: Vector3 = (slab_segments.back().to - slab_segments.back().from).normalized() if not slab_segments.is_empty() else Vector3.ZERO
	var exit_point: Vector3 = slab_segments[1].to if slab_segments.size() > 2 else source
	var lateral_offset := incident.cross(exit_point - source).length()
	_check(outgoing.dot(incident) > 0.999, "A parallel-sided amplifier exits parallel to its incident ray, including after rotation.")
	_check(lateral_offset > 0.02, "Oblique refraction creates a measurable lateral displacement through the slab.")
	world.remove_child(slab)
	slab.free()
	await physics_frame

	var wedge := _wedge_amplifier(Vector3.ZERO)
	var wedge_segments := _trace(Vector3(-3, 1, 0), Vector3.RIGHT)
	var wedge_outgoing: Vector3 = (wedge_segments.back().to - wedge_segments.back().from).normalized() if not wedge_segments.is_empty() else Vector3.ZERO
	_check(wedge_segments.size() >= 3 and is_equal_approx(float(wedge_segments[1].energy), 2.0), "A nonparallel amplifier uses one automatic ×2 gain while tracing both physical boundary faces.")
	_check(wedge_outgoing.z < -0.03, "The wedge amplifier's nonparallel exit face changes the outgoing direction.")
	_check(wedge.get_function_text().contains("경사 출사"), "The selected wedge identifies its direction-changing optical role.")
	wedge.rotate_steps(1)
	var rotated_wedge_segments := _trace(Vector3(-3, 1, 0), Vector3.RIGHT)
	var rotated_wedge_outgoing: Vector3 = (rotated_wedge_segments.back().to - rotated_wedge_segments.back().from).normalized() if not rotated_wedge_segments.is_empty() else Vector3.ZERO
	_check(wedge_outgoing.dot(rotated_wedge_outgoing) < 0.999, "Rotating the selected wedge recalculates its real entry and exit angles.")
	world.remove_child(wedge)
	wedge.free()
	await physics_frame

	var prism := _prism(Vector3.ZERO, deg_to_rad(8.0))
	prism.refractive_indices = {"white": 1.5, "red": 1.42, "green": 1.5, "blue": 1.6}
	var white_segments := _trace(Vector3(-3, 1, 0), Vector3.RIGHT)
	var red := _tail_for_channel(white_segments, "red")
	var green := _tail_for_channel(white_segments, "green")
	var blue := _tail_for_channel(white_segments, "blue")
	_check(not red.is_empty() and not green.is_empty() and not blue.is_empty(), "White input automatically produces red, green, and blue branches.")	
	if not red.is_empty() and not green.is_empty() and not blue.is_empty():
		var red_dir: Vector3 = (red.to - red.from).normalized()
		var green_dir: Vector3 = (green.to - green.from).normalized()
		var blue_dir: Vector3 = (blue.to - blue.from).normalized()
		_check(red_dir.z * green_dir.z > 0.0 and green_dir.z * blue_dir.z > 0.0, "Prism colors leave toward the same side.")
		_check(absf(blue_dir.z) > absf(green_dir.z) and absf(green_dir.z) > absf(red_dir.z), "Blue bends more than green, which bends more than red.")
		var output_energy := float(red.energy) + float(green.energy) + float(blue.energy)
		_check(output_energy <= 1.0001 and absf(output_energy - 1.0) < 0.001, "The three spectral branches divide input energy without creating power.")
	var red_only := _trace(Vector3(-3, 1, 0), Vector3.RIGHT, "red")
	_check(not _tail_for_channel(red_only, "red").is_empty() and _tail_for_channel(red_only, "green").is_empty() and _tail_for_channel(red_only, "blue").is_empty(), "Monochromatic input remains one channel after the prism.")
	world.remove_child(prism)
	prism.free()
	await physics_frame

	var splitter := _box_device("splitter", Vector3.ZERO, Vector3(0.28, 2.2, 2.8), PI / 4.0)
	var split_segments := _trace(Vector3(-3, 1.1, 0), Vector3.RIGHT)
	var transmitted: Dictionary = {}
	var reflected: Dictionary = {}
	for segment in split_segments:
		if is_equal_approx(float(segment.energy), 0.5):
			var direction: Vector3 = (segment.to - segment.from).normalized()
			if direction.x > 0.99:
				transmitted = segment
			elif direction.z > 0.99:
				reflected = segment
	_check(not transmitted.is_empty(), "The splitter's transmitted branch continues straight at 50% power.")
	_check(not reflected.is_empty(), "The splitter's reflected branch follows the plate's mirror angle at 50% power.")
	world.remove_child(splitter)
	splitter.free()
	await physics_frame

	var pair_a := _box_device("receiver", Vector3(3, 0, 0), Vector3(0.65, 2.0, 0.8))
	var pair_b := _box_device("receiver", Vector3(3, 0, 3), Vector3(0.65, 2.0, 0.8))
	for receiver in [pair_a, pair_b]:
		receiver.simultaneous_group = "test-pair"
		receiver.required_seconds = 0.25
	await physics_frame
	laser.update_beam(Vector3(-3, 1.0, 0), Vector3(5, 1.0, 0), true, 1.0, "red")
	_check(pair_a._hit_this_frame and not pair_b._hit_this_frame, "The control ray reaches only one member of the simultaneous pair.")
	_check(not pair_a.receiver_active and not pair_b.receiver_active, "A single powered branch cannot latch a simultaneous receiver group.")
	world.remove_child(pair_a)
	world.remove_child(pair_b)
	pair_a.free()
	pair_b.free()

	print("v5.1 optical checks: %d failure(s)." % failures)
	quit(0 if failures == 0 else 1)
