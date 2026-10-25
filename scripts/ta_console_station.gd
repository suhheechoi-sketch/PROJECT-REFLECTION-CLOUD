extends Node3D
## Visual upgrade of existing stations; decoration adds no optical colliders.
var game: Node3D
var stage: String
var led: StandardMaterial3D
func setup(world: Node3D, room: String, at: Vector3) -> void:
	game = world
	stage = room
	position = at
	name = room+" Optical Control Console"
	box(Vector3(0,0.48,0),Vector3(0.85,0.95,0.65),game.materials.metal)
	box(Vector3(0,0.98,-0.03),Vector3(1.1,0.12,0.75),game.materials.dark)
	box(Vector3(0,1.28,0.10),Vector3(0.75,0.5,0.15),game.materials.metal)
	box(Vector3(0,1.29,0.01),Vector3(0.6,0.33,0.035),game.materials.cyan)
	led = game._emissive_material(Color("55b7b0"),1.5)
	box(Vector3(0.43,1.07,0.12),Vector3(0.12,0.12,0.12),led)
	for x in [-0.27,0.0,0.27]: box(Vector3(x,1.06,-0.22),Vector3(0.14,0.07,0.12),game.materials.yellow)
	var label := Label3D.new()
	label.text = stage+" / OPTICAL CONTROL\n광학 제어 콘솔 · E / 조작"
	label.position = Vector3(0,2.0,0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.pixel_size = 0.009
	add_child(label)
func box(at: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
func _process(_delta: float) -> void:
	if game == null: return
	var near: bool = game.near_point(global_position,1.6 if stage == "A-02" else 2.7)
	var active: bool = game.control_mode and game.console_stage == stage or stage == "A-02" and game.a02_lab.control_mode
	led.albedo_color = Color("65ffad") if active else (Color("ffd075") if near else Color("55b7b0"))
	led.emission = led.albedo_color
