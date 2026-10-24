extends CharacterBody3D
class_name ReflectionPlayer
const CameraPointer = preload("res://scripts/camera_pointer.gd")

signal aim_changed(world_position: Vector3)

@export var move_speed: float = 4.2
@export var acceleration: float = 18.0
@export var laser_height: float = 1.15

var camera: Camera3D
var pointer_position := Vector2.ZERO
var aim_position: Vector3 = Vector3.ZERO
var firing: bool = false
var has_emitter: bool = false
var emitter_channel: String = "red"
var emitter: MeshInstance3D
var optical_control: Node
var station_control: Node


func _ready() -> void:
	pointer_position = get_viewport().get_mouse_position()
	collision_layer = 4
	collision_mask = 5
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.65
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.83
	add_child(collision)
	_build_character()


func _build_character() -> void:
	var suit := StandardMaterial3D.new()
	suit.albedo_color = Color(0.18, 0.23, 0.22)
	suit.roughness = 0.95
	var visor := StandardMaterial3D.new()
	visor.albedo_color = Color(0.35, 0.62, 0.61)
	visor.emission_enabled = true
	visor.emission = Color(0.09, 0.28, 0.26)
	visor.emission_energy_multiplier = 1.4
	var torso := MeshInstance3D.new()
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.62, 0.82, 0.42)
	torso.mesh = torso_mesh
	torso.material_override = suit
	torso.position.y = 0.94
	add_child(torso)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.42, 0.42, 0.42)
	head.mesh = head_mesh
	head.material_override = suit
	head.position = Vector3(0, 1.57, 0)
	add_child(head)
	var face := MeshInstance3D.new()
	var face_mesh := BoxMesh.new()
	face_mesh.size = Vector3(0.32, 0.12, 0.08)
	face.mesh = face_mesh
	face.material_override = visor
	face.position = Vector3(0, 1.58, -0.22)
	add_child(face)
	emitter = MeshInstance3D.new()
	var emitter_mesh := BoxMesh.new()
	emitter_mesh.size = Vector3(0.16, 0.16, 0.55)
	emitter.mesh = emitter_mesh
	var emitter_material := StandardMaterial3D.new()
	emitter_material.albedo_color = Color(0.48, 0.52, 0.49)
	emitter_material.metallic = 0.55
	emitter_material.roughness = 0.35
	emitter.material_override = emitter_material
	emitter.position = Vector3(0.34, 1.12, -0.38)
	add_child(emitter)
	emitter.visible = has_emitter
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.72, 0.82, 0.71)
	lamp.light_energy = 0.35
	lamp.omni_range = 3.0
	lamp.position = Vector3(0, 1.7, 0)
	add_child(lamp)


func _physics_process(delta: float) -> void:
	if (optical_control != null and optical_control.control_mode) or (station_control != null and station_control.control_mode):
		velocity = Vector3.ZERO
		firing = false
		_update_aim()
		return
	var input_vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.y += 1.0
	input_vector = input_vector.normalized()
	var desired := Vector3(input_vector.x, 0.0, input_vector.y) * move_speed
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	velocity.y = 0.0
	move_and_slide()
	_update_aim()
	if optical_control != null and optical_control.suppress_fire_until_release:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			optical_control.suppress_fire_until_release = false
		firing = false
	else:
		firing = has_emitter and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if emitter != null and aim_position.distance_squared_to(global_position) > 0.1:
		emitter.look_at(Vector3(aim_position.x, emitter.global_position.y, aim_position.z), Vector3.UP)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		pointer_position = event.position

func _update_aim() -> void:
	if camera == null:
		return
	var mouse := pointer_position
	var ray := CameraPointer.ray(camera, mouse)
	var ray_origin: Vector3 = ray.origin
	var ray_direction: Vector3 = ray.direction
	var hit = Plane(Vector3.UP, laser_height).intersects_ray(ray_origin, ray_direction)
	if hit != null:
		aim_position = hit
		aim_changed.emit(aim_position)


func get_emitter_origin() -> Vector3:
	if emitter != null:
		return emitter.global_position
	return global_position + Vector3(0.0, laser_height, 0.0)


func set_emitter_acquired(acquired: bool) -> void:
	has_emitter = acquired
	firing = false
	if emitter != null:
		emitter.visible = acquired

