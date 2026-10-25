extends Node3D
## Event-driven cosmetics: never owns receiver, progression or gate collision state.
const Art = preload("res://assets/presentation_v1/industrial_details.gd")
var game: Node3D
var locks: Dictionary = {}
var effects: Array[Dictionary] = []
var emitted_events := 0
var receiver_visuals: Array = []
var mechanical: AudioStreamPlayer
var mechanical_sound: AudioStreamWAV
func setup(world: Node3D) -> void:
	game = world
	mechanical = AudioStreamPlayer.new()
	add_child(mechanical)
	mechanical.volume_db = -15
	if DisplayServer.get_name() != "headless":
		mechanical_sound = make_mechanical_sound()
	for door in game.layout.doors:
		var at := Vector3(door.x,1.3,door.z)
		at += Vector3(door.width*0.5+0.2,0,0) if door.axis == "x" else Vector3(0,0,door.width*0.5+0.2)
		var mat: StandardMaterial3D = game._emissive_material(Color("c47e40"),0.7)
		var led := Art.box(self,at,Vector3(0.18,0.26,0.18),mat)
		if not game.demo_doors[door.id].visible:
			mat.albedo_color = Color("65ffad")
			mat.emission = mat.albedo_color
		locks[door.id] = {"led":led,"material":mat,"open":not game.demo_doors[door.id].visible,"timer":0.0}
	var receivers: Array = game.devices.values()+[game.a02_lab.control,game.a02_lab.receiver]
	for device in receivers:
		if device.kind == "receiver":
			device.receiver_activated.connect(receiver_confirmed)
			receiver_visuals.append(device)
func receiver_confirmed(device: OpticalDevice) -> void:
	if not device.receiver_active: return # A03 rejected order is reset synchronously by progression.
	emitted_events += 1
	var stage: String = device.get_meta("stage", "A-02")
	var end := device.position+Vector3(1,0,0)
	if device == game.a02_lab.control:
		end = game.a02_lab.handle_point
	elif game.completed.has(stage) or game.progression.completed_stage_ids.has(stage):
		for door in game.layout.doors:
			if door.unlock == stage:
				end = Vector3(door.x,0,door.z)
				break
	var start := Vector3(device.global_position.x,0.07,device.global_position.z)
	end.y = 0.07
	var elbow := Vector3(start.x,0.07,end.z)
	var points: Array[Vector3] = [start,elbow,end]
	var distance := start.distance_to(elbow)+elbow.distance_to(end)
	var mat: StandardMaterial3D = game._emissive_material(Color("80ffd0"),1.6)
	var pulse := Art.box(self,start,Vector3(0.25,0.07,0.25),mat)
	var cable_material: StandardMaterial3D = game._material(Color("3b6660"),0.2,0.85)
	var cable := Node3D.new()
	add_child(cable)
	for pair in [[start,elbow],[elbow,end]]:
		var delta: Vector3 = pair[1]-pair[0]
		Art.box(cable,(pair[0]+pair[1])*0.5,Vector3(maxf(0.06,absf(delta.x)),0.025,maxf(0.06,absf(delta.z))),cable_material)
	var flash := Art.ring(self,device.position+Vector3.UP*2.3,0.55,mat)
	effects.append({"time":0.0,"points":points,"length":distance,"pulse":pulse,"cable":cable,"flash":flash})
	game.chime()
func _process(delta: float) -> void:
	if game == null or game.is_paused_overlay or (game.platform_ui != null and game.platform_ui.is_open()): return
	for rail in [game.a02_lab.rail,game.devices["A03-RAIL"]]:
		if rail.has_meta("rail_clamp"):
			var mat: StandardMaterial3D = rail.get_meta("rail_clamp")
			mat.albedo_color = Color("65ffad") if (game.a02_lab.control.receiver_active if rail == game.a02_lab.rail else game.completed.has("A-02")) else Color("d69a43")
			mat.emission = mat.albedo_color
	for device in receiver_visuals:
		if device.has_meta("presentation_lens"):
			var mat: StandardMaterial3D = device.get_meta("presentation_lens")
			var color := Color("65ffad") if device.receiver_active else (Color("d6e9a0") if device._hit_this_frame else Color("245255"))
			mat.albedo_color = color
			mat.emission = color
	for i in range(effects.size()-1,-1,-1):
		var effect: Dictionary = effects[i]
		effect.time += delta
		var p: Array = effect.points
		var traveled := clampf((effect.time-0.12)/0.50,0,1)*float(effect.length)
		var first: float = p[0].distance_to(p[1])
		effect.pulse.position = p[0].lerp(p[1],traveled/maxf(first,0.001)) if traveled < first else p[1].lerp(p[2],(traveled-first)/maxf(p[1].distance_to(p[2]),0.001))
		effect.flash.scale = Vector3.ONE*(1+minf(effect.time,0.4))
		effect.flash.visible = effect.time < 0.6
		if effect.time > 1.1:
			for key in ["pulse","cable","flash"]: effect[key].queue_free()
			effects.remove_at(i)
	for id in locks:
		var record: Dictionary = locks[id]
		var open: bool = not game.demo_doors[id].visible
		if open and not record.open:
			record.timer = 0.65
			animate_gate(id)
			# A separate visual latch retracts; physical gate timing stays in sync_demo().
			var latch := Art.box(self,record.led.position,Vector3(0.45,0.10,0.18),game.materials.metal)
			latch.set_meta("feedback_transient",true)
			var tween := latch.create_tween()
			tween.tween_property(latch,"position:y",latch.position.y+0.65,0.4).set_delay(0.55)
			tween.tween_callback(latch.queue_free)
		if record.timer > 0:
			record.timer -= delta
			if record.timer <= 0:
				record.material.albedo_color = Color("65ffad")
				record.material.emission = Color("65ffad")
				if mechanical_sound != null:
					mechanical.stream = mechanical_sound
					mechanical.play()
		elif not open:
			record.material.albedo_color = Color("c47e40")
			record.material.emission = Color("c47e40")
		record.open = open
func animate_gate(id: String) -> void:
	var door: Dictionary = {}
	for item in game.layout.doors:
		if item.id == id: door = item
	if door.is_empty(): return
	# Thin outlined leaves preserve a visible open passage throughout the cosmetic animation.
	for side in [-1,1]:
		var leaf := Node3D.new()
		leaf.position = Vector3(door.x,1.325,door.z)
		add_child(leaf)
		var half: float = door.width*0.5
		for edge in [-1,1]:
			var p := Vector3(side*half*0.5+edge*half*0.5,0,0)
			var size := Vector3(0.045,2.3,0.045)
			if door.axis == "z": p = Vector3(0,0,p.x)
			Art.box(leaf,p,size,game.materials.yellow)
			var rail_p := Vector3(side*half*0.5,edge*1.15,0)
			var rail_size := Vector3(half,0.04,0.045)
			if door.axis == "z":
				rail_p = Vector3(0,rail_p.y,rail_p.x)
				rail_size = Vector3(0.045,0.04,half)
			Art.box(leaf,rail_p,rail_size,game.materials.metal)
		var offset := Vector3(side*half,0,0) if door.axis == "x" else Vector3(0,0,side*half)
		leaf.set_meta("feedback_transient",true)
		var tween := leaf.create_tween()
		tween.tween_property(leaf,"position",leaf.position+offset,0.3).set_delay(0.7)
		tween.tween_callback(leaf.queue_free)

func make_mechanical_sound() -> AudioStreamWAV:
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050)
	var random := RandomNumberGenerator.new()
	random.seed = 7007
	for i in range(11025):
		var t := i/22050.0
		var sound := (sin(TAU*(88-35*t)*t)*0.25+random.randf_range(-0.12,0.12))*(1-t*2)
		data.encode_s16(i*2,int(sound*8000))
	audio.data = data
	return audio
func _exit_tree() -> void:
	if mechanical != null:
		mechanical.stop()
		mechanical.stream = null
	mechanical_sound = null

func reset_visuals() -> void:
	for effect in effects:
		for key in ["pulse","cable","flash"]: effect[key].queue_free()
	effects.clear()
	for child in get_children():
		if child.has_meta("feedback_transient"): child.queue_free()
	for id in locks:
		locks[id].timer = 0.0
		locks[id].open = not game.demo_doors[id].visible
		locks[id].material.albedo_color = Color("65ffad") if locks[id].open else Color("c47e40")
		locks[id].material.emission = locks[id].material.albedo_color
