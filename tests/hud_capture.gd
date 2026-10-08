extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var arena = load("res://sandbox/arena.tscn").instantiate()
	root.add_child(arena)
	var player = arena.get_node("Player")
	var enemy = arena.get_node("TestEnemy")
	enemy.ai_enabled = false
	for i in range(120):
		await physics_frame
	enemy.set_physics_process(false)
	enemy.global_position = Vector3(0, 0.05, -1)
	enemy.rotation.y = PI
	enemy.state = "BLOCK"
	player.health = 73
	enemy.health = 68
	player.get_node("SwordShield/Guard").current = 62
	enemy.guard.current = 48
	arena.get_node("MovementDebug/State").hide()
	for i in range(20):
		await physics_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png("res://.godot/hud-preview.png")
	print("CAPTURE: .godot/hud-preview.png")
	player.get_node("SwordShield/Guard").absorb(100)
	enemy.guard.absorb(100)
	var impact = load("res://sandbox/incoming_attack.gd").new()
	impact.damage = 12
	player.receive_attack(impact, enemy.global_position, enemy)
	enemy.receive_attack(impact, player.global_position, player)
	impact.damage = 8
	enemy.receive_attack(impact, player.global_position, player)
	for i in range(12):
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/guard-break-preview.png")
	print("CAPTURE: .godot/guard-break-preview.png")
	player.get_node("SwordShield/Guard").tick(2)
	enemy.guard.tick(2)
	player.switch_weapon()
	player.weapon_set.primary()
	for i in range(28):
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/greatsword-preview.png")
	var event := InputEventAction.new()
	event.action = "combat_debug"
	event.pressed = true
	arena.get_node("MovementDebug/State")._unhandled_input(event)
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/debug-preview.png")
	quit()
