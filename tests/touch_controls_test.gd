extends SceneTree
var game: Node3D
var touch: Control
var failed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		printerr("FAIL: "+description)
func press(id: int, label: String, down := true) -> void:
	var e := InputEventScreenTouch.new()
	e.index = id
	e.position = touch.buttons[label].get_center()
	e.pressed = down
	touch._input(e)
func run() -> void:
	game = preload("res://scenes/ta_demo.tscn").instantiate()
	game.checkpoint_enabled = false
	root.add_child(game)
	await physics_frame
	for layer in game.get_children():
		for child in layer.get_children():
			if child.get_script() == preload("res://scripts/touch_controls.gd"): touch = child
	touch.visible = true
	game.player.set_emitter_acquired(true)
	press(0,"W")
	press(1,"D")
	press(2,"FIRE")
	await physics_frame
	await physics_frame
	check(game.player.touch_movement == Vector2(1,-1),"multi-touch diagonal movement")
	check(game.player.firing,"independent held fire")
	press(0,"W",false)
	check(game.player.touch_movement == Vector2.RIGHT and game.player.touch_firing,"release one finger preserves other inputs")
	touch.release_all()
	check(game.player.touch_movement == Vector2.ZERO and not game.player.touch_firing,"focus loss cancels held input")
	game.player.position = game.terminals["T-ID"]
	press(3,"E")
	check(game.completed.has("T-01"),"touch interaction completes identity terminal")
	press(3,"E",false)
	game.player.position = game.terminals["L-07-PICKUP"]
	press(3,"E")
	check(game.player.has_emitter,"touch interaction acquires emitter")
	press(3,"E",false)
	game.player.touch_firing = true
	game.restore_fire_state()
	check(game.suppress_fire_until_release,"console exit suppresses held touch fire")
	touch.release_all()
	press(3,"HELP")
	check(game.help_panel.visible,"touch help opens overlay")
	press(3,"HELP",false)
	press(3,"HELP")
	check(not game.help_panel.visible,"touch help closes overlay")
	press(3,"HELP",false)
	game.queue_free()
	await process_frame
	if not failed: print("PASS: touch input lifecycle")
	quit(1 if failed else 0)
