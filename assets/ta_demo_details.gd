extends RefCounted
## New procedural generation; locked assets/v4_0 remains untouched.
static func build(game: Node3D) -> void:
	# Identity bay: dimensions give the subject's body a human scale.
	game._add_box("T01 BED FRAME",Vector3(2.1,0.27,4),Vector3(1.05,0.5,2),game.materials.metal,true,4)
	game._add_box("T01 MATTRESS",Vector3(2.1,0.6,4),Vector3(1,0.16,1.9),game.materials.tutorial_floor,false)
	game._add_box("T01 PILLOW",Vector3(2.1,0.73,3.3),Vector3(0.8,0.13,0.45),game.materials.wall,false)
	game.sign_at("SUBJECT 07 / OBSERVATION\nMEMORY CHECK: PENDING",Vector3(2.2,1.5,1))
	for room in game.layout.rooms:
		if room.get("corridor",false): continue
		var b: Array = room.bounds
		var clean: bool = room.zone == "T"
		# Sparse seams and repeated wall panels, no new gameplay colliders.
		for x in range(int(b[0])+2,int(b[2]),2):
			game._add_box("PANEL JOINT",Vector3(x,0.006,(b[1]+b[3])*0.5),Vector3(0.025,0.008,b[3]-b[1]-0.5),game.materials.metal,false)
		for z in range(int(b[1])+2,int(b[3]),2):
			game._add_box("PANEL JOINT",Vector3((b[0]+b[2])*0.5,0.006,z),Vector3(b[2]-b[0]-0.5,0.008,0.025),game.materials.metal,false)
		for i in range(3):
			var at := Vector3(b[2]-0.35,0.8,b[1]+1+i*1.5)
			game._add_box("WALL CONTROL PANEL",at,Vector3(0.15,1.2,0.9),game.materials.metal,false)
			game._add_box("PANEL LED",at+Vector3(-0.09,0.2,0),Vector3(0.03,0.12,0.25),game.materials.cyan if clean else game.materials.yellow,false)
		if not clean:
			game._add_box("CABLE TRAY",Vector3(b[0]+0.4,0.08,(b[1]+b[3])*0.5),Vector3(0.18,0.12,b[3]-b[1]-1),game.materials.dark,false)
	for id in game.terminals:
		if id == "A03-HANDLE": continue
		var p: Vector3 = game.terminals[id]
		game._add_box("TERMINAL FRAME",p+Vector3(0,0.8,0.08),Vector3(0.78,0.16,0.65),game.materials.metal,false)
		game._add_box("CRT SCREEN",p+Vector3(0,1.12,0.09),Vector3(0.5,0.42,0.12),game.materials.dark,false)
		game._add_box("CRT TEXT",p+Vector3(0,1.12,-0.01),Vector3(0.38,0.23,0.02),game.materials.cyan,false)
