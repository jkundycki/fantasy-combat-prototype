extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var arena = load("res://sandbox/arena.tscn").instantiate()
	root.add_child(arena)
	var player = arena.get_node("Player")
	var bot = arena.get_node("TestEnemy")
	bot.ai_enabled = false
	for i in range(100):
		await physics_frame
	player.set_physics_process(false)
	bot.set_physics_process(false)
	bot.global_position = Vector3(1.5, 0.05, -1)
	bot.rotation.y = PI
	bot.applied_weapon = -1
	bot.mirror_weapon = false
	bot.opponent_weapon = 3
	bot.state = "IDLE"
	bot.sync_weapon()
	bot.state = "FIREBALL_STARTUP"
	for name in ["Staff", "Bow"]:
		player.weapon_set.visible = false
		player.weapon_set = player.get_node(name)
		player.weapon_set.visible = true
		player.weapon_set.primary()
		player.weapon_set.tick(player.weapon_set.startup_duration * 0.65)
		for i in range(10):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + name.to_lower() + "-preview.png")
		player.weapon_set.reset_combat()
	quit()
