extends RefCounted
## Geometry only. World metres come from the uploaded blueprint.
var game: Node3D
var emitted_edges := {}
var apertures: Array[Vector2] = []

func build(world: Node3D) -> void:
	game = world
	var rooms: Array = game.layout.rooms
	var rects: Array[Rect2] = []
	for room in rooms:
		var b: Array = room.bounds
		var rect := Rect2(b[0], b[1], b[2] - b[0], b[3] - b[1])
		rects.append(rect)
		game._add_box(room.id + " FLOOR", Vector3(rect.get_center().x, -0.12, rect.get_center().y), Vector3(rect.size.x, 0.24, rect.size.y), game.materials["tutorial_floor" if room.zone == "T" else "a_floor"], true, 1)
		if not room.get("corridor", false):
			game.sign_at(room.id + " / " + room.name, Vector3(b[0] + 2, 0.04, b[3] - 2), true)
			decorate(rect, room.zone == "T")
	boundary(rects, false, [])
	# Shared room edges remain partitions, even where floors touch.
	for rect in rects:
		boundary([rect], false, [])
	for door in game.layout.doors:
		var size := Vector3(door.width, 2.65, 0.45) if door.axis == "x" else Vector3(0.45, 2.65, door.width)
		game.demo_doors[door.id] = game._make_gate(door.id, Vector3(door.x, 1.325, door.z), size)
		game.sign_at(door.id, Vector3(door.x, 2.9, door.z))
	# Folded light ducts. Only the source aperture admits a beam from walkable space.
	channel([Rect2(29.5,3.5,3,8), Rect2(29.5,3.5,11,3)], [Vector2(31,11.5)])
	channel([Rect2(43.5,3.5,3,8), Rect2(43.5,3.5,11,3), Rect2(51.5,3.5,3,11)], [Vector2(45,11.5)])
	channel([Rect2(34.5,31.5,3,10), Rect2(34.5,31.5,12,3), Rect2(43.5,31.5,3,13), Rect2(43.5,41.5,10,3)], [Vector2(36,41.5)])
	channel([Rect2(10.5,33.5,3,12), Rect2(10.5,33.5,14,3), Rect2(21.5,33.5,3,14), Rect2(17.5,39.5,12,3)], [Vector2(12,45.5)])
	channel([Rect2(9,59,2,12), Rect2(9,59,10,2), Rect2(14,61,2,10), Rect2(14,61,12,2), Rect2(24,61,2,11), Rect2(17,65,2,6), Rect2(17,65,11,2), Rect2(26,57,2,10)], [Vector2(10,71),Vector2(15,71),Vector2(18,71)])
	for stage in game.layout.optical_vaults:
		# Screenshot request: remove only the extra T03 receiver rectangle, not its L duct.
		if stage == "T-03": continue
		var vault: Dictionary = game.layout.optical_vaults[stage]
		for s in vault.walls:
			segment(Vector2(s[0],s[1]), Vector2(s[2],s[3]), false, false)
		for s in vault.slits:
			segment(Vector2(s[0],s[1]), Vector2(s[2],s[3]), true, false)

func contains(rects: Array[Rect2], p: Vector2) -> bool:
	for rect in rects:
		if rect.has_point(p): return true
	return false

func channel(rects: Array[Rect2], slits: Array[Vector2]) -> void:
	if rects[0].size.x == 3:
		for i in range(rects.size()): rects[i] = rects[i].grow(-0.25)
		for i in range(slits.size()): slits[i].y -= 0.25
	apertures.append_array(slits)
	boundary(rects, true, slits)

func boundary(rects: Array[Rect2], optical: bool, slits: Array[Vector2]) -> void:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF,-INF)
	for rect in rects:
		low = low.min(rect.position)
		high = high.max(rect.end)
	var groups := {}
	var step := 0.25 if optical else 0.5
	for x in range(int(low.x/step), int(high.x/step)):
		for z in range(int(low.y/step), int(high.y/step)):
			var cell := Vector2(x*step+step*0.5,z*step+step*0.5)
			if not contains(rects,cell): continue
			for d in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				if contains(rects,cell+d*step): continue
				var p: Vector2 = cell+d*step*0.5
				var edge_key := "%s:%s:%s" % [optical,p,d.x != 0]
				if emitted_edges.has(edge_key): continue
				emitted_edges[edge_key] = true
				var slit := false
				for entry in slits:
					if p.distance_to(entry) < 0.3: slit = true
				if not optical and door_gap(p): continue
				var vertical: bool = d.x != 0
				var fixed: float = p.x if vertical else p.y
				var along: float = p.y if vertical else p.x
				var key := "%s:%s:%s" % [vertical,fixed,slit]
				if not groups.has(key): groups[key] = {"v":vertical,"f":fixed,"slit":slit,"points":[]}
				groups[key].points.append(along)
	for group in groups.values():
		group.points.sort()
		var start: float = group.points[0]-step*0.5
		var end := start
		for value in group.points:
			if float(value)-step*0.5 > end+0.01:
				emit_segment(group,start,end,optical)
				start = float(value)-step*0.5
			end = float(value)+step*0.5
		emit_segment(group,start,end,optical)

func door_gap(p: Vector2) -> bool:
	for mouth in [Rect2(56,21.7,4,0.6),Rect2(16,49.7,3,0.6),Rect2(33.7,61,0.6,3)]:
		if mouth.has_point(p): return true
	for door in game.layout.doors:
		# One gate can sit between two corridor mouths (A01→A02).
		var cross: float = absf(p.y-door.z) if door.axis == "x" else absf(p.x-door.x)
		var along: float = absf(p.x-door.x) if door.axis == "x" else absf(p.y-door.z)
		if cross <= 1.01 and along < door.width*0.5: return true
	return false

func emit_segment(g: Dictionary, a: float, b: float, optical: bool) -> void:
	var first := Vector2(g.f,a) if g.v else Vector2(a,g.f)
	var last := Vector2(g.f,b) if g.v else Vector2(b,g.f)
	segment(first,last,g.slit,optical)

func segment(a: Vector2,b: Vector2,slit: bool,service: bool) -> void:
	var center := (a+b)*0.5
	var size := Vector3(0.45,2.65,a.distance_to(b)) if a.x == b.x else Vector3(a.distance_to(b),2.65,0.45)
	if slit:
		var body: StaticBody3D = game._add_box("BEAM ONLY 0.5m",Vector3(center.x,1.325,center.y),size,game.materials.cyan,true,8)
		body.get_child(0).visible = false
	elif service:
		if a.x == b.x: size.x = 0.2
		else: size.z = 0.2
		# Mechanical service slots below the laser plane. Body-only sill prevents entry.
		var upper := size
		upper.y = 1.95
		game._add_wall("OPTICAL DUCT",Vector3(center.x,1.675,center.y),upper)
		var sill := size
		sill.y = 0.7
		game._add_box("SERVICE SILL",Vector3(center.x,0.35,center.y),sill,game.materials.metal,true,8)
	else:
		game._add_wall("TA STRUCTURE",Vector3(center.x,1.325,center.y),size)

func decorate(rect: Rect2, clean: bool) -> void:
	var color := Color("a8e9e2") if clean else Color("d69a43")
	var x := rect.position.x+1
	var z := rect.position.y+1
	game._add_area_light(Vector3(rect.get_center().x,2.5,rect.get_center().y),color,0.8,18)
	game._add_box("CEILING STRIP",Vector3(x+2,2.5,z),Vector3(3,0.1,0.15),game._emissive_material(color,1.1),false)
	game._add_box("SURVEILLANCE",Vector3(x,2.3,z),Vector3(0.45,0.3,0.5),game.materials.dark,false)
	game._add_box("REC LED",Vector3(x,2.3,z+0.27),Vector3(0.12,0.08,0.08),game.materials.light,false)
	game.sign_at("FACILITY 17 / SUBJECT 07\nCAUTION · OPTICAL TEST",Vector3(x+4,2.1,z))
	if not clean:
		for i in range(3):
			game._add_box("EXPOSED PIPE",Vector3(x+0.16*i,1.8,z+rect.size.y*0.4),Vector3(0.12,0.12,rect.size.y*0.65),game.materials.rust,false)
