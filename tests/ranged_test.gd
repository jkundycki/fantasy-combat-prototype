extends SceneTree
var failures: int = 0
var arena
var player
var bot
var staff
var bow
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
func select(weapon) -> void:
	player.weapon_set.reset_combat()
	player.weapon_set.visible = false
	player.weapon_set = weapon
	weapon.reset_combat()
	weapon.visible = true
func shot_hit(weapon, x: float) -> float:
	select(weapon)
	bot.global_position = Vector3(x, 0.05, -3)
	bot.health = 100
	await ticks(3)
	var shot = weapon.fire()
	shot.set_physics_process(false)
	shot._physics_process(0.6)
	var hp: float = bot.health
	await ticks(2)
	clear_shots()
	return hp
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	arena = load("res://sandbox/arena.tscn").instantiate()
	preload("res://tests/baseline_tuning.gd").apply(arena)
	root.add_child(arena)
	player = arena.get_node("Player")
	bot = arena.get_node("TestEnemy")
	bot.ai_enabled = false
	bot.staff_charge_weights = Vector4(1, 0, 0, 0)
	bot.held_bow_chance = 0
	await ticks(100)
	player.set_physics_process(false)
	bot.set_physics_process(false)
	bot.guard.set_physics_process(false)
	player.get_node("SwordShield/Guard").set_physics_process(false)
	arena.get_node("TrainingDummy").global_position = Vector3(15, 0.9, 15)
	player.global_position = Vector3(0, 0.05, 3)
	player.velocity = Vector3.ZERO
	player.camera_rig.rotation.y = 0
	player.visual.rotation.y = 0
	Input.action_press("camera_facing")
	staff = player.get_node("Staff")
	bow = player.get_node("Bow")
	for expected in ["Greatsword", "Staff", "Bow", "SwordShield"]:
		check(player.switch_weapon() and player.weapon_set.name == expected, "Q/Y cycle must include " + expected)
	select(staff)
	check(staff.primary(), "Staff Primary starts")
	check(not staff.primary() and not player.switch_weapon(), "No shots or switch during startup")
	staff.tick(staff.startup_duration - 0.01)
	check(get_nodes_in_group("test_projectiles").is_empty(), "Startup must precede projectile")
	staff.tick(0.01)
	check(get_nodes_in_group("test_projectiles").size() == 1 and staff.state == staff.RECOVERY, "Startup releases exactly one shot")
	check(not staff.primary(), "Full recovery must prevent spam")
	staff.tick(staff.recovery_duration)
	check(staff.primary(), "Fresh press after recovery begins new shot")
	staff.reset_combat()
	clear_shots()
	for weapon in [staff, bow]:
		select(weapon)
		check(not weapon.heavy_attack() and not weapon.special() and not weapon.hard_feint(), "Undefined ranged actions must be no-ops")
		weapon.defense(true)
		check(not weapon.defense_held and not weapon.busy(), "Ranged Defense must remain no-op")
		check(await shot_hit(weapon, 0) == 100 - weapon.damage, "Facing shot hits once: " + str(weapon.name))
		check(await shot_hit(weapon, 2.5) == 100, "Off-axis shot misses: " + str(weapon.name))
	check(await shot_hit(staff, 0.55) == 76, "Staff sphere radius makes edge hit generous")
	check(await shot_hit(bow, 0.55) == 100, "Narrow arrow misses same offset")
	check(bow.projectile_speed > staff.projectile_speed * 2 and bow.projectile_radius < staff.projectile_radius / 3, "Bow identity is faster and narrower")
	# Thin wall blocks both the large orb and high-speed arrow before the target.
	var wall = arena.box("ShotWall", Vector3(0, 1, 0), Vector3(3, 3, 0.05), Color.GRAY)
	check(await shot_hit(bow, 0) == 100, "Swept arrow must not tunnel through thin wall")
	wall.free()
	await ticks(3)
	# Area-only dummy participates in the same projectile collision path.
	bot.global_position = Vector3(15, 0.05, 15)
	var dummy = arena.get_node("TrainingDummy")
	dummy.global_position = Vector3(0, 0.9, -3)
	dummy.health = 100
	select(staff)
	await ticks(3)
	var dummy_shot = staff.fire()
	dummy_shot.set_physics_process(false)
	dummy_shot._physics_process(0.5)
	check(dummy.health == 76 and dummy.hits_received > 0, "Ranged shot must damage Area dummy once")
	await ticks(2)
	dummy.global_position = Vector3(15, 0.9, 15)
	clear_shots()
	# Real incoming Staff bolt, perfect block, changed owner and return damage.
	select(player.get_node("SwordShield"))
	player.visual.rotation.y = 0
	player.weapon_set.defense(true)
	player.weapon_set.tick(0.01)
	bot.opponent_weapon = 2
	bot.global_position = Vector3(0, 0.05, -3)
	bot.rotation.y = PI
	bot.health = 100
	bot.aim_point = player.global_position + Vector3(0, 1.15, 0)
	await ticks(3)
	var reflected = bot.fire_projectile()
	reflected.set_physics_process(false)
	check(reflected.impact.reflectable, "This Staff bolt explicitly opts into reflect")
	var hp: float = player.health
	reflected._physics_process(0.4)
	check(reflected.reflected and reflected.attacker == player and player.health == hp, "Perfect block negates hit and transfers Staff ownership")
	check(reflected.direction.dot(-player.visual.global_basis.z) > 0.999 and reflected.speed == staff.projectile_speed * player.weapon_set.spell_reflect_speed_multiplier, "Reflection uses defender facing and existing speed multiplier")
	reflected._physics_process(0.3)
	check(bot.health == 76, "Reflected bolt can damage original caster")
	await ticks(2)
	clear_shots()
	player.weapon_set.reset_combat()
	player.weapon_set.defense(true)
	player.weapon_set.tick(0.01)
	bot.opponent_weapon = 3
	await ticks(3)
	var arrow = bot.fire_projectile()
	arrow.set_physics_process(false)
	check(not arrow.impact.reflectable and arrow.impact.blockable, "Arrow explicitly blockable, not reflectable")
	arrow._physics_process(0.2)
	check(not arrow.reflected and player.health == hp, "Perfect shield block blocks arrow without reflection")
	await ticks(2)
	clear_shots()
	player.weapon_set.reset_combat()
	select(staff)
	bot.opponent_weapon = 0
	bot.ai_enabled = true
	bot.state = "PARRY_WINDOW"
	bot.rotation.y = PI
	bot.freeze_remaining = 0
	bot.stagger_remaining = 0
	bot.guard.reset()
	bot.health = 100
	player.health = 100
	await ticks(3)
	var returned = staff.fire()
	returned.set_physics_process(false)
	returned._physics_process(0.4)
	check(returned.reflected and returned.attacker == bot and bot.guard.current == 100, "Bot perfect shield timing reflects player Staff without Guard cost")
	returned._physics_process(0.3)
	check(player.health == 76, "Bot-reflected Staff can damage its original player caster")
	await ticks(2)
	clear_shots()
	bot.ai_enabled = false
	bot.state = "IDLE"
	player.health = 100
	# Airborne momentum has its own reference; RMB facing turns only the shot.
	for weapon in [staff, bow]:
		select(weapon)
		player.global_position = Vector3(0, 4, 3)
		player.velocity = Vector3(0, 0, -9)
		player.move_and_slide()
		player.camera_rig.rotation.y = PI
		player.air_reference_yaw = 0
		weapon.primary()
		weapon.tick(weapon.startup_duration)
		var shot = get_nodes_in_group("test_projectiles").back()
		check(shot.direction.z > 0.99 and player.velocity.z == -9 and player.velocity.x == 0, "Backward airborne fire preserves original velocity: " + str(weapon.name))
		weapon.reset_combat()
		clear_shots()
	player.camera_rig.rotation.y = 0
	player.global_position = Vector3(0, 0.05, 3)
	player.velocity = Vector3.ZERO
	player.health = 100
	Input.action_release("camera_facing")
	bot.ai_enabled = true
	bot.mirror_weapon = true
	bot.state = "IDLE"
	bot.applied_weapon = -1
	select(player.get_node("Greatsword"))
	bot.sync_weapon()
	check(bot.opponent_weapon == 1 and bot.melee_damage == 40 and bot.melee_range == 2.9, "Mirror Greatsword uses actual Light tuning")
	bot.apply_personality(6)
	bot.global_position = Vector3(0, 0.05, -8)
	bot.rotation.y = PI
	var before: float = bot.global_position.z
	bot._physics_process(0.01)
	check(bot.global_position.z > before and bot.pressure_move_speed > bot.move_speed, "ALL_OUT aggressively pursues")
	bot.begin_weapon_attack()
	select(staff)
	bot.sync_weapon()
	check(bot.opponent_weapon == 1, "Mirror changes must wait through committed melee")
	bot.state = "IDLE"
	bot.sync_weapon()
	check(bot.opponent_weapon == 2, "Mirror changes apply safely after recovery")
	for weapon in [staff, bow]:
		select(weapon)
		bot.state = "IDLE"
		bot.freeze_remaining = 0
		bot.stagger_remaining = 0
		bot.sync_weapon()
		bot.cooldown = 10
		bot.global_position = Vector3(0, 0.05, 0)
		bot.rotation.y = PI
		bot._physics_process(0.01)
		check(bot.velocity.z < 0, "Ranged bot creates close-range space")
		bot.global_position = Vector3(0, 0.05, -13)
		bot.cooldown = 10
		bot.state = "IDLE"
		bot._physics_process(0.01)
		check(bot.velocity.z > 0, "Ranged bot pursues outside preferred range")
		bot.global_position = Vector3(0, 0.05, -5 if weapon == staff else -8)
		bot.rotation.y = PI
		bot.cooldown = 0
		bot.state = "IDLE"
		bot._physics_process(0.01)
		check(bot.state == ("BOW_DRAW" if weapon == bow else "STAFF_CHARGE"), "Mirrored ranged bot starts its actual shot")
		bot._physics_process(weapon.startup_duration + 0.01)
		var shot = get_nodes_in_group("test_projectiles").back()
		check(shot.attacker == bot and shot.speed == weapon.projectile_speed, "Bot fires mirrored projectile tuning")
		var flat := Vector3(shot.direction.x, 0, shot.direction.z).normalized()
		check(flat.dot(-bot.global_basis.z) > 0.999, "Bot fires along committed facing")
		check(Vector2(bot.velocity.x, bot.velocity.z).length() > 0, "Ranged bot repositions during cast/recovery")
		var launched: Vector3 = shot.direction
		player.global_position.x = 2
		bot._physics_process(0.01)
		check(shot.direction == launched and not shot.impact.parryable, "AI shot has fixed trajectory and no melee parry")
		check(bot.state == "FIREBALL_RECOVERY", "ALL_OUT respects shot recovery")
		var hp_before: float = player.health
		shot.set_physics_process(false)
		await ticks(3) # Flush the moved CharacterBody collider before the sweep.
		shot._physics_process(0.8)
		check(player.health == hp_before, "Moving off the launched AI trajectory causes a physical miss")
		clear_shots()
		bot._physics_process(weapon.recovery_duration + 0.01)
		check(bot.state == "IDLE" and bot.cooldown == bot.pressure_attack_interval, "ALL_OUT removes idle only after recovery")
		player.global_position.x = 0
	bot.global_position = Vector3(18, 0.05, 0)
	bot.state = "IDLE"
	bot.cooldown = 10
	bot._physics_process(0.01)
	check(bot.velocity.x < 0, "Ranged bot returns inward at arena edge")
	bot.state = "STAGGER"
	bot.stagger_remaining = 0.5
	bot._physics_process(0.1)
	check(bot.state == "STAGGER", "ALL_OUT respects legitimate stagger")
	# HUD uses four weapon names and hides irrelevant Guard.
	var hud = arena.get_node("MovementDebug/CombatHUD")
	hud._process(0)
	check(hud.player_action.text == "BOW" and not hud.player_guard_panel.visible and not hud.opponent_guard_panel.visible, "Ranged HUD name and Guard relevance")
	if failures == 0:
		print("PASS: Staff/Bow cadence, hit/miss/radius/thin wall/dummy, directional ownership/speed reflection, arrow block, airborne freedom, four-set selection, safe mirror, actual GS tuning, ALL_OUT pursuit/recovery/stagger, ranged spacing/fixed aiming/HUD")
	quit(1 if failures else 0)
