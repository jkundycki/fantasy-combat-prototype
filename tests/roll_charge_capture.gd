extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func snap(name: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + name + ".png")
func capture() -> void:
	var arena = load("res://sandbox/arena.tscn").instantiate()
	root.add_child(arena)
	var player = arena.get_node("Player")
	var bot = arena.get_node("TestEnemy")
	bot.ai_enabled = false
	await physics_frame
	for i in range(100):
		await physics_frame
	player.set_physics_process(false)
	bot.set_physics_process(false)
	player.start_dodge(Vector3.FORWARD)
	player.dodge_remaining = player.dodge_duration * 0.55
	await snap("roll-preview")
	player.dodge_remaining = 0
	player.cooldown_remaining = 0
	player.weapon_set.visible = false
	player.weapon_set = player.get_node("Staff")
	player.weapon_set.visible = true
	player.weapon_set.primary_pressed()
	player.weapon_set.tick(player.weapon_set.max_charge_time * 0.75)
	await snap("channel-preview")
	player.weapon_set.reset_combat()
	player.weapon_set.visible = false
	player.weapon_set = player.get_node("Bow")
	player.weapon_set.visible = true
	player.weapon_set.primary_pressed()
	player.weapon_set.tick(player.weapon_set.draw_duration)
	await snap("draw-preview")
	quit()
