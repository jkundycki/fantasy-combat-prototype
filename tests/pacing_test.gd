extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
func clear_shots() -> void:
	for shot in get_nodes_in_group("test_projectiles"):
		shot.free()
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	# Intentionally use actual shipped tuning, never the old preset.
	var arena = load("res://sandbox/arena.tscn").instantiate()
	root.add_child(arena)
	var player = arena.get_node("Player")
	var bot = arena.get_node("TestEnemy")
	bot.ai_enabled = false
	arena.get_node("TrainingDummy").global_position = Vector3(15, 0.9, 15)
	await ticks(100)
	player.set_physics_process(false)
	bot.set_physics_process(false)
	check(Engine.time_scale == 1 and player.move_speed == 7.2 and player.jump_speed == 8 and player.gravity == 22.4, "Movement/jump at 80%, without global slowdown")
	var height_ratio: float = (pow(player.jump_speed, 2) / player.gravity) / (100.0 / 28)
	check(is_equal_approx(height_ratio, 0.8), "Jump height at 80%, flight-time ratio preserved")
	var sword = player.get_node("SwordShield")
	var great = player.get_node("Greatsword")
	check(sword.sword.startup_duration == 0.18 and sword.sword.active_duration == 0.24 and sword.sword.recovery_duration == 0.4, "Sword times doubled")
	check(great.heavy.startup_duration == 0.96 and great.heavy.recovery_duration == 1.3 and great.heavy.feint_startup_fraction == 0.65, "Heavy timing slowed while feint fraction preserved")
	check(sword.perfect_block_duration == 0.32 and great.parry_window == 0.36, "Defense windows slowed consistently")
	check(sword.guard.regeneration_rate == 12.5 and sword.guard.break_stun_duration == 3.2, "Guard temporal rules slowed")
	var staff = player.get_node("Staff")
	var bow = player.get_node("Bow")
	check(staff.projectile_speed == 9 and bow.projectile_speed == 24 and bow.draw_duration == 1.5 and bow.recovery_duration == 0.56, "Projectiles, draw and recovery half speed")
	check(staff.max_charge_time == 2.4 and staff.auto_release_time == 2.4 and staff.recovery_duration == 0.48, "Staff charge and cutoff slowed")
	player.weapon_set.visible = false
	player.weapon_set = staff
	staff.visible = true
	player.camera_rig.rotation.y = 0
	Input.action_press("camera_facing")
	for fraction in [0.0, 0.5]:
		staff.reset_combat()
		staff.primary_pressed()
		staff.tick(staff.max_charge_time * fraction)
		check(staff.charging() and get_nodes_in_group("test_projectiles").is_empty(), "Early holds wait for release")
		staff.primary_released()
		var shot = get_nodes_in_group("test_projectiles").back()
		check(shot.impact.damage == lerpf(12, 30, fraction) and is_equal_approx(shot.radius, lerpf(0.22, 0.44, fraction)), "Halved damage and continuous radius scaling")
		clear_shots()
	staff.reset_combat()
	staff.primary_pressed()
	staff.tick(staff.auto_release_time - 0.01)
	check(staff.charging() and get_nodes_in_group("test_projectiles").is_empty(), "No premature cutoff launch")
	player.camera_rig.rotation.y = PI
	staff.tick(0.02)
	var full = get_nodes_in_group("test_projectiles").back()
	check(full.impact.damage == 30 and full.radius == 0.44 and full.direction.z > 0.99 and staff.state == staff.RECOVERY, "Cutoff launches maximum ball in completion-facing direction")
	full.set_physics_process(false)
	staff.tick(5)
	staff.primary_released()
	check(get_nodes_in_group("test_projectiles").size() == 1, "Continued holding/later release cannot duplicate automatic shot")
	clear_shots()
	staff.reset_combat()
	player.weapon_set = sword
	player.camera_rig.rotation.y = 0
	player.global_position = Vector3(0, 0.02, 10)
	player.velocity = Vector3(0, -1, 0)
	player.move_and_slide()
	player.set_physics_process(true)
	await ticks(3)
	check(player.dodge_speed == 9 and player.dodge_duration == 0.432 and player.dodge_cooldown == 5, "Longer slower roll with five-second cooldown")
	var start: Vector3 = player.global_position
	player.start_dodge(Vector3.FORWARD)
	for i in range(100):
		await physics_frame
		if player.dodge_remaining <= 0:
			break
	var distance: float = Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	check(absf(distance - 3.888) < 0.1, "Actual roll displacement approximately 35% longer")
	check(player.cooldown_remaining > 4.4 and player.cooldown_remaining < 4.7, "Cooldown lasts five seconds from activation")
	player.set_physics_process(false)
	var model = player.get_node("Visual/Humanoid")
	player.dodge_remaining = player.dodge_duration * 0.5
	model._process(0.01)
	check(is_equal_approx(model.roll_duration, 0.54) and player.get_node("CollisionShape3D").rotation == Vector3.ZERO and player.camera_rig.rotation.z == 0, "Slower visual roll with upright capsule/camera")
	player.dodge_remaining = 0
	player.dodge_pressed = true
	player._physics_process(0.01)
	check(player.dodge_remaining == 0, "Cooldown prevents another player roll")
	player.health = 100
	player.stagger_remaining = 0
	player.global_position = Vector3(0, 0.02, 3)
	bot.ai_enabled = true
	bot.state = "IDLE"
	bot.commit_response("DODGE")
	check(bot.dodge_cooldown_remaining == 5, "Bot observes roll cooldown too")
	bot.state = "IDLE"
	bot.commit_response("DODGE")
	check(bot.state != "DODGE", "Bot cannot roll again during cooldown")
	bot.state = "IDLE"
	bot.stagger_remaining = 0
	bot.freeze_remaining = 0
	player.weapon_set = staff
	bot.sync_weapon()
	bot.staff_charge_weights = Vector4(0, 0, 0, 1)
	bot.begin_weapon_attack()
	check(bot.staff_hold_duration == staff.auto_release_time, "AI full holds obey same cutoff")
	bot.tick_ranged_attack(1.2)
	check(bot.state == "STAFF_CHARGE" and Vector2(bot.velocity.x, bot.velocity.z).length() <= 3.601, "AI charge respects new player movement speed")
	bot.tick_ranged_attack(1.2)
	check(get_nodes_in_group("test_projectiles").back().impact.damage == 30 and bot.state == "FIREBALL_RECOVERY", "AI launches halved-damage full charge at cutoff")
	clear_shots()
	bot.opponent_weapon = 0
	bot.global_position = Vector3(0, 0.02, -3)
	bot.rotation.y = PI
	player.visual.rotation.y = 0
	player.health = 100
	for fraction in [0.5, 1.0]:
		bot.state = "PARRY_WINDOW"
		bot.freeze_remaining = 0
		bot.stagger_remaining = 0
		player.health = 100
		await ticks(3)
		var shot = staff.fire(fraction)
		shot.set_physics_process(false)
		shot._physics_process(0.7)
		check(shot.reflected and shot.speed == 18 and shot.charge_fraction == fraction, "Current paced Staff still reflects at existing multiplier")
		shot._physics_process(0.5)
		check(player.health == 100 - lerpf(12, 30, fraction), "Current reduced partial/full damage reaches original caster")
		await ticks(2)
		clear_shots()
	Input.action_release("camera_facing")
	if failures == 0:
		print("PASS: shipped half-speed combat/projectiles/Guard, 80% movement/jump height, halved Staff damage/continuous scaling/cutoff/one shot, actual 35% longer slower roll/player+bot cooldown, shared AI cutoff/movement")
	quit(1 if failures else 0)
