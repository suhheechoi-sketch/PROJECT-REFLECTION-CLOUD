extends SceneTree

var failures := 0
var world: Node3D
var laser: ReflectionLaser

func _initialize() -> void:
	call_deferred("_run")

func _device(kind: String, at: Vector3, size: Vector3) -> OpticalDevice:
	var device := OpticalDevice.new()
	device.configure(kind, kind, Color.CYAN)
	device.position = at
	device.optical_size = size
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y / 2
	device.add_child(shape)
	world.add_child(device)
	return device

func _check(condition: bool, message: String) -> void:
	if not condition:
		printerr("FAIL: " + message)
		failures += 1

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	laser = ReflectionLaser.new()
	world.add_child(laser)
	var first := _device("medium", Vector3.ZERO, Vector3(1, 2, 2))
	first.amplification = 2
	first.refractive_indices = {"white": 1.0}
	var second := _device("medium", Vector3(4, 0, 0), Vector3(1, 2, 2))
	second.amplification = 2
	second.refractive_indices = {"white": 1.0}
	var receiver := _device("receiver", Vector3(8, 0, 0), Vector3(0.5, 2, 1))
	receiver.minimum_energy = 2.9
	receiver.required_seconds = 0.1
	await physics_frame
	await physics_frame
	var segments: Array[Dictionary] = []
	laser._trace(Vector3(-3, 1.15, 0), Vector3.RIGHT, "white", 1, segments)
	var seen_double := false
	var seen_cap := false
	for segment in segments:
		seen_double = seen_double or is_equal_approx(segment.energy, 2.0)
		seen_cap = seen_cap or is_equal_approx(segment.energy, 3.0)
		_check(segment.energy <= 3.0, "No branch exceeds the 300% cap.")
	_check(seen_double and seen_cap, "Physical entry surfaces produce 100% -> 200% -> 300%.")
	receiver.update_receiver(0.2)
	_check(receiver.receiver_active, "High-power receiver receives capped energy after exiting both media.")
	first.amplification = 1
	second.amplification = 1
	segments.clear()
	laser._trace(Vector3(-3, 1.15, 0), Vector3.RIGHT, "white", 1, segments)
	_check(is_equal_approx(segments.back().energy, 1.0), "Default medium preserves original energy.")
	print("Energy flow checks: %d failure(s)." % failures)
	quit(0 if failures == 0 else 1)
