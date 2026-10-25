extends SceneTree
var game: Node3D
var failures := 0
var cells := {}
var parents := {}
var shape_query := PhysicsShapeQueryParameters3D.new()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL TA NAV: "+message)
	else: print("PASS TA NAV: "+message)
func settle() -> void:
	await physics_frame
	await physics_frame
func allowed(c: Vector2i) -> bool:
	var point := Vector2(c.x*0.5,c.y*0.5)
	for room in game.layout.rooms:
		var b: Array = room.bounds
		if Rect2(b[0],b[1],b[2]-b[0],b[3]-b[1]).has_point(point): return true
	return false
func build_cells() -> void:
	cells.clear()
	for x in range(1,136):
		for z in range(1,156):
			var c := Vector2i(x,z)
			if not allowed(c): continue
			shape_query.transform.origin = Vector3(x*0.5,0.86,z*0.5)
			if game.get_world_3d().direct_space_state.intersect_shape(shape_query).is_empty(): cells[c] = true
func flood(seed: Vector2i) -> void:
	parents = {seed:seed}
	var queue := [seed]
	var index := 0
	while index < queue.size():
		var c: Vector2i = queue[index]
		index += 1
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var n: Vector2i = c+d
			if cells.has(n) and not parents.has(n):
				parents[n] = c
				queue.append(n)
func reachable_near(point: Vector3,radius: float) -> Vector2i:
	var best := Vector2i(-1,-1)
	var distance := radius
	for c in parents:
		var d: float = Vector2(c.x*0.5,c.y*0.5).distance_to(Vector2(point.x,point.z))
		if d < distance:
			best = c
			distance = d
	return best
func sweep(seed: Vector2i,target: Vector2i) -> bool:
	var path := [target]
	while path.back() != seed: path.append(parents[path.back()])
	path.reverse()
	game.player.position = Vector3(seed.x*0.5,0.03,seed.y*0.5)
	for c in path:
		var to := Vector3(c.x*0.5,0.03,c.y*0.5)
		game.player.move_and_collide(to-game.player.position)
		if game.player.position.distance_to(to) > 0.04: return false
	return true
func run() -> void:
	game = preload("res://scenes/ta_demo.tscn").instantiate()
	game.checkpoint_enabled = false
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.a02_lab.set_physics_process(false)
	shape_query.shape = game.player.get_child(0).shape
	shape_query.collision_mask = 2|4|8
	shape_query.exclude = [game.player.get_rid()]
	await settle()
	build_cells()
	flood(Vector2i(10,16))
	check(reachable_near(Vector3(18,0,6),1.6).x == -1,"T02 blocked before identity")
	for stage in ["T-01","T-02","T-03","T-04","T-04_TERMINAL_E","A-01","A-02","A-03"]: game.completed.append(stage)
	game.sync_demo()
	await settle()
	build_cells()
	var seed := Vector2i(10,16)
	flood(seed)
	for id in game.terminals:
		var target := reachable_near(game.terminals[id],1.6)
		check(target.x != -1,"body-clear route to terminal "+id)
		if target.x != -1: check(sweep(seed,target),"CharacterBody sweep to "+id)
	for point in [game.a02_lab.console_point,game.a02_lab.dock_point,game.a02_lab.handle_point]:
		var target := reachable_near(point,1.5)
		check(target.x != -1,"A02 station reachable "+str(point))
		if target.x != -1: check(sweep(seed,target),"CharacterBody sweep A02 station")
	for d in game.devices.values():
		if d.kind != "mirror" or not d.rotatable or d.get_meta("stage") == "A-01": continue
		check(reachable_near(d.position,2.65).x != -1,"local mirror service access "+d.name)
	var escapes := 0
	for c in parents:
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if allowed(c+d): continue
			game.player.position = Vector3(c.x*0.5,0.03,c.y*0.5)
			game.player.move_and_collide(Vector3(d.x,0,d.y)*2)
			var inside := false
			for room in game.layout.rooms:
				var b: Array = room.bounds
				if Rect2(b[0],b[1],b[2]-b[0],b[3]-b[1]).has_point(Vector2(game.player.position.x,game.player.position.z)): inside = true
			if not inside: escapes += 1
	check(escapes == 0,"actual capsule sweeps cannot escape the floorplan (count="+str(escapes)+")")
	# Sample body-reachable cells only: vault interiors cannot be considered firing positions.
	game.devices["A02-RCTRL"] = game.a02_lab.control
	game.devices["A02-RN"] = game.a02_lab.receiver
	var bypass := 0
	for id in ["T03-RN","T04-RN","A01-RN","A03-RO1","A03-RO2","A03-RN","A02-RCTRL","A02-RN"]:
		var receiver: OpticalDevice = game.devices[id]
		var hits := 0
		for c in parents:
			var from := Vector3(c.x*0.5,1.15,c.y*0.5)
			if from.distance_to(receiver.position) > 30: continue
			var query := PhysicsRayQueryParameters3D.create(from,receiver.position+Vector3.UP*1.15,7)
			query.exclude = [game.player.get_rid()]
			query.hit_from_inside = true
			var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.get("collider") == receiver: hits += 1
		check(hits == 0,"no direct receiver bypass at reachable 0.5m samples "+id+" count="+str(hits))
		bypass += hits
	print("TA NAV: reachable cells=%d, failures=%d, bypasses=%d" % [parents.size(),failures,bypass])
	game.hum.stop()
	game.tone.stop()
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
