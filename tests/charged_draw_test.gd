extends SceneTree
var failures: int = 0
var player
var bot
var arena
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
func equip(name: String):
	player.weapon_set.reset_combat()
	player.weapon_set.visible = false
	player.weapon_set = player.get_node(name)
	player.weapon_set.visible = true
	return player.weapon_set
func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	player._unhandled_input(event)
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	arena = load("res://sandbox/arena.tscn").instantiate()
	preload("res://tests/baseline_tuning.gd").apply(arena)
	root.add_child(arena)
	player = arena.get_node("Player")
	bot = arena.get_node("TestEnemy")
	bot.ai_enabled = false
	arena.get_node("TrainingDummy").global_position = Vector3(15, 0.9, 15)
	await ticks(100)
	player.set_physics_process(false)
	bot.set_physics_process(false)
	player.get_node("SwordShield/Guard").set_physics_process(false)
	bot.guard.set_physics_process(false)
	player.global_position = Vector3(0, 0.02, 3)
	player.camera_rig.rotation.y = 0
	Input.action_press("camera_facing")
	var model = player.get_node("Visual/Humanoid")
	var capsule_rotation: Vector3 = player.get_node("CollisionShape3D").rotation
	var camera_rotation: Vector3 = player.camera_rig.rotation
	check(player.dodge_speed == 18 and player.dodge_duration == 0.16 and player.dodge_cooldown == 0.35 and player.dodge_recovery_time == 0, "Mechanical dodge balance unchanged")
	var previous: float = 0
	var maximum_step: float = 0
	for i in range(101):
		var fraction: float = model.roll_turn_fraction(i / 100.0)
		check(fraction >= previous and fraction <= 1, "Roll monotone one-turn progression")
		maximum_step = maxf(maximum_step, fraction - previous)
		previous = fraction
	check(previous == 1 and maximum_step < 0.013, "Roll uses full timeline, no central rapid spin")
	for duration in [0.16, 0.3]:
		player.dodge_duration = duration
		player.start_dodge(Vector3.LEFT)
		player.dodge_remaining = duration * 0.5
		model._process(0.001)
		check(is_equal_approx(model.roll_duration, duration * player.roll_visual_duration_multiplier), "Visual duration adapts to mechanical tuning")
		check(absf(model.roll_root.rotation.x) > 2 and absf(model.roll_root.rotation.x) < TAU, "Middle of dodge visibly rolls once")
		check(player.get_node("CollisionShape3D").rotation == capsule_rotation and player.camera_rig.rotation == camera_rotation, "Roll never rotates camera/capsule")
		player.dodge_remaining = 0
		for i in range(60):
			model._process(0.01)
		check(model.roll_root.rotation == Vector3.ZERO and is_equal_approx(model.roll_root.position.y, 0.9), "Visual tail settles upright")
	player.dodge_duration = 0.16
	player.cooldown_remaining = 0
	player.recovery_remaining = 0
	var staff = equip("Staff")
	for amount in [0.0, 0.5, 1.0]:
		staff.reset_combat()
		action("primary", true)
		staff.tick(staff.max_charge_time * amount)
		check(staff.charging() and get_nodes_in_group("test_projectiles").is_empty(), "Holding never auto-fires at any amount")
		check(is_equal_approx(staff.charge_fraction(), amount) and staff.movement_scale() == 0.5, "Continuous charge fraction and slow movement")
		if amount == 1:
			staff.tick(2)
			check(staff.charge_fraction() == 1 and get_nodes_in_group("test_projectiles").is_empty(), "Full charge caps and waits indefinitely")
		player.camera_rig.rotation.y = PI
		player.visual.global_rotation.y = player.facing_yaw()
		staff.update_visuals()
		var release_origin: Vector3 = staff.spawn_origin()
		action("primary", false)
		var shot = get_nodes_in_group("test_projectiles").back()
		check(is_equal_approx(shot.impact.damage, lerpf(24, 60, amount)) and is_equal_approx(shot.radius, lerpf(0.22, 0.44, amount)), "Linear damage and hitbox scaling")
		check(shot.charge_fraction == amount and shot.speed == 18 and shot.impact.reflectable, "Constant speed and reflectable charged identity")
		check(shot.direction.z > 0.99 and absf(shot.direction.y) < 0.001 and shot.global_position.distance_to(release_origin) < 0.001, "Immediate release uses new facing and casting-hand origin")
		check(not staff.primary_pressed(), "Recovery still prevents spam")
		staff.tick(staff.recovery_duration)
		check(not staff.busy(), "Full recovery completes normally")
		clear_shots()
		player.camera_rig.rotation.y = 0
	# Brief taps remain near original power and fire on release, not automatically.
	action("primary", true)
	staff.tick(0.04)
	action("primary", false)
	var quick = get_nodes_in_group("test_projectiles").back()
	check(quick.impact.damage < 26 and quick.speed == 18, "Quick tap close to old 24-damage bolt")
	clear_shots()
	for name in ["mobility", "jump"]:
		staff.reset_combat()
		player.dodge_remaining = 0
		player.dodge_pressed = false
		player.jump_pressed = false
		action("primary", true)
		staff.tick(0.4)
		action(name, true)
		check(staff.state == staff.IDLE and staff.movement_scale() == 1 and not staff.charge_orb.visible and get_nodes_in_group("test_projectiles").is_empty(), "Movement action loses held Staff charge without firing/penalty")
		check(player.dodge_pressed if name == "mobility" else player.jump_pressed, "Normal mobility/jump input preserved")
	player.dodge_pressed = false
	player.jump_pressed = false
	player.jump_buffer_remaining = 0
	# Slow ground repositioning while upper-body charge and leg locomotion coexist.
	player.velocity = Vector3.ZERO
	player.camera_rig.rotation.y = 0
	staff.primary_pressed()
	Input.action_press("move_forward")
	player.update_horizontal(Vector3.FORWARD, true, 0.1)
	check(is_equal_approx(player.velocity.z, -4.5), "Staff charging ground speed is normal speed times multiplier")
	model._process(0.05)
	check(model.right_arm.rotation.x < -1.8 and absf(model.left_leg.rotation.x) > 0, "Charge upper body and walking legs coexist")
	Input.action_release("move_forward")
	# Already-airborne charging is allowed, retaining launch momentum and gravity.
	staff.reset_combat()
	player.global_position.y = 4
	player.velocity = Vector3(0, 0, -9)
	player.move_and_slide()
	staff.primary_pressed()
	player.camera_rig.rotation.y = PI
	player._physics_process(0.02)
	check(player.velocity.z == -9 and player.velocity.y < 0 and staff.charging(), "Airborne charge preserves momentum/gravity")
	staff.primary_released()
	check(get_nodes_in_group("test_projectiles").back().direction.z > 0.99, "Backward airborne release follows facing")
	clear_shots()
	staff.reset_combat()
	player.global_position = Vector3(0, 0.02, 3)
	player.velocity = Vector3(0, -1, 0)
	player.move_and_slide()
	player.camera_rig.rotation.y = 0
	player.visual.rotation.y = 0
	player.health = 100
	bot.global_position = Vector3(0, 0.02, -3)
	bot.rotation.y = PI
	bot.opponent_weapon = 0
	bot.ai_enabled = true
	for amount in [0.5, 1.0]:
		bot.state = "PARRY_WINDOW"
		bot.freeze_remaining = 0
		bot.stagger_remaining = 0
		bot.guard.reset()
		player.health = 100
		await ticks(3)
		var shot = staff.fire(amount)
		shot.set_physics_process(false)
		var radius: float = shot.radius
		var damage: float = shot.impact.damage
		shot._physics_process(0.5)
		check(shot.reflected and shot.attacker == bot and shot.direction.z > 0.99 and shot.speed == 36, "Reflect applies facing/ownership/speed")
		check(shot.radius == radius and shot.impact.damage == damage and shot.charge_fraction == amount and is_equal_approx(shot.sweep.shape.radius, radius), "Reflect preserves current charge, physical radius and damage")
		shot._physics_process(0.4)
		check(player.health == 100 - damage, "Reflected scaled shot damages original caster")
		var number = get_nodes_in_group("damage_numbers").back()
		check(number.amount == damage, "Floating damage uses actual scaled HP loss")
		await ticks(2)
		clear_shots()
	player.health = 100
	bot.state = "IDLE"
	bot.mirror_weapon = true
	bot.sync_weapon()
	for duration in [0.04, 0.3, 0.65, 1.4]:
		bot.state = "IDLE"
		bot.begin_weapon_attack()
		bot.staff_hold_duration = duration
		bot.tick_ranged_attack(duration * 0.5)
		check(bot.state == "STAFF_CHARGE" and Vector2(bot.velocity.x, bot.velocity.z).length() <= 4.501, "AI visibly holds and respects same slowed movement")
		bot.tick_ranged_attack(duration * 0.5)
		var shot = get_nodes_in_group("test_projectiles").back()
		var amount: float = staff.staff_fraction(duration, staff.max_charge_time)
		check(is_equal_approx(shot.impact.damage, lerpf(24, 60, amount)) and is_equal_approx(shot.radius, lerpf(0.22, 0.44, amount)) and shot.speed == 18, "AI exact same fraction and projectile rules")
		var heading: Vector3 = shot.direction
		player.global_position.x += 1
		bot.tick_ranged_attack(0.01)
		check(shot.direction == heading and bot.state == "FIREBALL_RECOVERY", "AI no post-release aim correction or skipped recovery")
		clear_shots()
	var choices := [false, false, false, false]
	bot.rng.seed = 123
	for i in range(100):
		var duration: float = bot.choose_staff_hold(staff)
		var amount: float = duration / staff.max_charge_time
		choices[0 if amount < 0.1 else (1 if amount < 0.45 else (2 if amount < 0.9 else 3))] = true
	check(choices.all(func(value): return value), "AI samples quick, short, medium and full holds")
	# Bow remains quick-on-release, held-at-full, with unchanged strength/mobility.
	bot.ai_enabled = false
	var bow = equip("Bow")
	bow.primary_pressed()
	bow.tick(0.05)
	bow.primary_released()
	bow.tick(0.2)
	var arrow = get_nodes_in_group("test_projectiles").back()
	check(arrow.speed == 48 and arrow.impact.damage == 28, "Bow quick shot unchanged")
	clear_shots()
	bow.reset_combat()
	bow.primary_pressed()
	bow.tick(bow.draw_duration + 2)
	check(bow.draw_fraction() == 1 and bow.movement_scale() == 0.5 and get_nodes_in_group("test_projectiles").is_empty(), "Bow remains held at full and mobile")
	bow.primary_released()
	arrow = get_nodes_in_group("test_projectiles").back()
	check(is_equal_approx(arrow.impact.damage, 37.8) and is_equal_approx(arrow.speed, 57.6), "Bow full draw scaling unchanged")
	clear_shots()
	bow.reset_combat()
	bow.primary_pressed()
	action("mobility", true)
	check(bow.state == bow.IDLE and player.dodge_pressed, "Bow dodge cancellation unchanged")
	Input.action_release("camera_facing")
	if failures == 0:
		print("PASS: progressive one-turn visual roll/adaptive duration/unchanged mechanics; Staff immediate tap/continuous partial/full/manual release/facing/slow movement/cancels/air/reflect/actual damage; shared AI charge distribution/movement/recovery; Bow unchanged")
	quit(1 if failures else 0)
