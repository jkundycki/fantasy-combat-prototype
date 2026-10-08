extends SceneTree
const Impact = preload("res://sandbox/incoming_attack.gd")
var failures: int = 0
var player
var enemy
var arena
var shield
var guard
var hud
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func incoming(hp: float = 12, cost: float = 15):
	var value = Impact.new()
	value.damage = hp
	value.guard_damage = cost
	value.melee = true
	value.blockable = true
	value.parryable = true
	return value
func raise_shield(perfect: bool = false) -> void:
	shield.reset_combat()
	guard.reset()
	player.stagger_remaining = 0
	player.visual.rotation.y = 0
	player.camera_rig.rotation.y = 0
	shield.defense(true)
	shield.tick(0.001)
	if not perfect:
		shield.tick(0.2)
func numbers() -> Array:
	return get_nodes_in_group("damage_numbers")
func simulate(weapon, seconds: float) -> void:
	for i in range(ceili(seconds / 0.005)):
		weapon.tick(0.005)
		enemy.guard.tick(0.005)
		enemy._physics_process(0.005)
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	arena = load("res://sandbox/arena.tscn").instantiate()
	preload("res://tests/baseline_tuning.gd").apply(arena)
	root.add_child(arena)
	player = arena.get_node("Player")
	enemy = arena.get_node("TestEnemy")
	enemy.mirror_weapon = false
	enemy.applied_weapon = 0
	enemy.ai_enabled = false
	for i in range(100):
		await physics_frame
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	shield = player.get_node("SwordShield")
	guard = shield.guard
	guard.set_physics_process(false)
	enemy.guard.set_physics_process(false)
	hud = arena.get_node("MovementDebug/CombatHUD")
	player.global_position = Vector3(0, 0.05, 3)
	enemy.global_position = Vector3(0, 0.05, 1.5)
	enemy.rotation.y = PI
	arena.get_node("TrainingDummy").global_position = Vector3(15, 0.9, 15)
	var front := Vector3(0, 1, 1)
	player.health = 75
	enemy.health = 68
	check(hud.player_bar.value == 75 and hud.opponent_bar.value == 68, "Health signals update both bars immediately")
	player.health = 100
	enemy.health = 100
	hud._process(0)
	check(hud.player_bar.get_global_rect().intersects(Rect2(Vector2.ZERO, root.size)), "Player HUD is inside viewport")
	check(hud.opponent_panel.visible and hud.opponent_panel.position.y < root.get_camera_3d().unproject_position(enemy.global_position + Vector3.UP * 2.1).y, "Enemy bars are projected above head")
	var old_position: Vector2 = hud.opponent_panel.position
	enemy.global_position.x += 1
	hud._process(0)
	check(hud.opponent_panel.position != old_position, "Enemy panel follows world movement")
	enemy.global_position.x -= 1
	arena.get_node("MovementDebug/State").hide()
	check(hud.is_visible_in_tree(), "Bars independent of debug toggle")
	var impact = incoming()
	raise_shield()
	var count := numbers().size()
	check(player.receive_attack(impact, front, enemy) == "BLOCK", "Normal shield blocks")
	check(player.health == 100 and guard.current == 85 and numbers().size() == count, "Full block costs Guard without HP number")
	guard.tick(2)
	check(guard.current == 85, "Holding shield pauses regeneration and has no idle drain")
	shield.defense(false)
	guard.tick(0.4)
	check(guard.current == 95, "Released shield regenerates at 25/sec")
	guard.tick(2)
	check(guard.current == 100, "Guard regeneration caps at max")
	raise_shield()
	player.receive_attack(impact, front, enemy)
	shield.defense(false)
	guard.tick(1)
	check(guard.current == 85, "Guard waits full delay")
	guard.tick(0.5)
	check(is_equal_approx(guard.current, 91.25), "Only time beyond 1.25 sec delay regenerates")
	raise_shield(true)
	var enemy_stagger: float = enemy.stagger_remaining
	count = numbers().size()
	check(player.receive_attack(impact, front, enemy) == "PARRY" and player.health == 100 and guard.current == 100 and numbers().size() == count, "Perfect parry costs zero HP/Guard")
	check(enemy.stagger_remaining > enemy_stagger, "Parry retains attacker stagger")
	enemy.stagger_remaining = 0
	enemy.state = "IDLE"
	raise_shield(true)
	var spell = incoming()
	spell.melee = false
	spell.parryable = false
	spell.reflectable = true
	check(player.receive_attack(spell, front, enemy) == "REFLECT" and guard.current == 100 and player.health == 100, "Spell reflect costs zero Guard")
	raise_shield()
	check(player.receive_attack(spell, front, enemy) == "BLOCK" and guard.current == 85, "Ordinary projectile block spends Guard")
	# Actual chip and overkill numbers, multiple simultaneous labels, lifecycle.
	raise_shield()
	shield.blocked_damage_multiplier = 0.25
	count = numbers().size()
	player.receive_attack(impact, front, enemy)
	check(player.health == 97 and numbers().size() == count + 1 and numbers().back().amount == 3, "Chip number is actual HP loss")
	shield.blocked_damage_multiplier = 0
	shield.reset_combat()
	player.health = 7
	player.receive_attack(impact, front, enemy)
	check(player.health == 0 and numbers().back().amount == 7, "Overkill number is capped at actual HP lost")
	player.reset_remaining = 0
	player._physics_process(0.01)
	check(player.health == player.max_health and guard.current == guard.starting_guard, "Player death/reset updates health and Guard")
	player.global_position = Vector3(0, 0.05, 3)
	count = numbers().size()
	player.receive_attack(incoming(2, 0), front, enemy)
	player.receive_attack(incoming(4, 0), front, enemy)
	check(numbers().size() == count + 2, "Close hits have independent numbers")
	var number = numbers().back()
	var start: Vector3 = number.global_position
	number._process(0.4)
	check(number.global_position.y > start.y and number.modulate.a < 1, "Number rises and fades")
	number._process(0.5)
	check(number.is_queued_for_deletion(), "Number expires")
	# Player break locks every action; normal hit stagger cannot extend it.
	player.health = 100
	raise_shield()
	for i in range(7):
		player.receive_attack(impact, front, enemy)
	check(guard.current == 0 and guard.is_broken() and not shield.shield_raised and not shield.defense_held, "Repeated blocks break and lower shield")
	check(not shield.primary() and not shield.heavy_attack() and not shield.special() and not shield.hard_feint() and not player.switch_weapon(), "Guard Break prevents offensive actions and switching")
	shield.defense(true)
	check(not shield.defense_held, "Cannot defend while broken")
	var event := InputEventAction.new()
	event.action = "jump"
	event.pressed = true
	player._unhandled_input(event)
	event.action = "mobility"
	player._unhandled_input(event)
	player.start_dodge(Vector3.FORWARD)
	check(not player.jump_pressed and player.dodge_remaining == 0, "Cannot jump or dodge while broken")
	player.velocity = Vector3(9, 0, 9)
	player._physics_process(0.01)
	check(Vector2(player.velocity.x, player.velocity.z).length() == 0, "Broken player cannot move")
	var remaining: float = guard.stun_remaining
	var stagger_hit = incoming(1, 0)
	stagger_hit.stagger_duration = 10
	player.receive_attack(stagger_hit, front, enemy)
	check(guard.stun_remaining == remaining and player.stagger_remaining == 0, "Ordinary hits cannot refresh or stack break stun")
	player.visual.get_node("Humanoid")._process(0)
	hud._process(0)
	check(player.visual.get_node("Humanoid").pose == "GUARD_BREAK" and hud.feedback.text == "GUARD BREAK", "Distinct pose/text without debug")
	guard.tick(guard.break_stun_duration)
	check(not guard.is_broken() and guard.current == 30 and guard.immunity_remaining > 0, "Break recovers partially with short protection")
	raise_shield()
	guard.current = 1
	guard.immunity_remaining = 0.5
	player.receive_attack(impact, front, enemy)
	check(not guard.is_broken() and guard.current == 1, "Protection avoids immediate repeat break")
	# Greatsword keeps finite parry, no sustained block or Guard display.
	shield.reset_combat()
	guard.reset()
	var great = player.get_node("Greatsword")
	player.weapon_set = great
	great.reset_combat()
	player.stagger_remaining = 0
	great.defense(true)
	great.tick(0.05)
	check(great.defend(impact, front, enemy) == "PARRY" and guard.current == 100, "Greatsword parry costs no Guard")
	great.reset_combat()
	check(great.defend(impact, front, enemy) == "HIT" and great.defend(spell, front, enemy) == "HIT", "Greatsword gains no block or reflect")
	hud._process(0)
	check(not hud.player_guard_panel.visible, "Greatsword hides Guard bar")
	# Physical player Greatsword pressure against ALWAYS_BLOCK, then real Heavy.
	player.health = 100
	player.visual.rotation.y = 0
	player.velocity = Vector3.ZERO
	enemy.ai_enabled = true
	enemy.training_mode = 1
	enemy.opponent_weapon = 0
	enemy.health = 100
	enemy.stagger_remaining = 0
	enemy.freeze_remaining = 0
	enemy.guard.reset()
	enemy.global_position = Vector3(0, 0.05, 1.5)
	enemy.rotation.y = PI
	enemy.state = "IDLE"
	enemy._physics_process(0.01)
	for i in range(3):
		await physics_frame
	count = numbers().size()
	for i in range(7):
		great.reset_combat()
		great.primary()
		simulate(great, 0.9)
	check(enemy.guard.is_broken() and enemy.state == "GUARD_BREAK" and enemy.health == 100, "Real Greatsword swings deplete ALWAYS_BLOCK Guard without HP damage")
	check(enemy.guard.break_stun_duration >= great.heavy.recovery_duration + great.heavy.startup_duration + great.heavy.active_duration + 0.2, "Break covers longest attack recovery, Heavy and human allowance")
	simulate(great, 0.2)
	check(great.heavy_attack(), "Manual Heavy begins after last Light recovery")
	simulate(great, 0.55)
	check(enemy.health == 35 and enemy.guard.is_broken() and enemy.stagger_remaining == 0, "Actual Greatsword Heavy lands before break ends without stun stacking")
	# SwordShield Heavy also fits, with ordinary directional geometry.
	great.reset_combat()
	player.weapon_set = shield
	shield.reset_combat()
	enemy.health = 100
	enemy.guard.reset()
	enemy.state = "BLOCK"
	enemy.guard.current = 15
	enemy.receive_attack(impact, player.global_position, player)
	simulate(shield, 0.2)
	check(shield.heavy_attack(), "SwordShield Heavy can punish")
	simulate(shield, 0.55)
	check(enemy.health == 55 and enemy.guard.is_broken(), "SwordShield Heavy also lands inside stun")
	enemy.guard.tick(enemy.guard.stun_remaining)
	check(enemy.guard.current == 30 and enemy.stagger_remaining == 0 and enemy.state == "IDLE", "AI regains normal control with partial Guard")
	enemy.opponent_weapon = 1
	enemy.commit_response("BLOCK")
	check(enemy.state == "PARRY_ATTEMPT", "Greatsword opponent never gains sustained Block")
	# Actual opponent death/reset also updates the projected bar and Guard.
	enemy.ai_enabled = false
	enemy.opponent_weapon = 0
	enemy.state = "IDLE"
	enemy.test_guard_mode = 0
	enemy.health = 5
	enemy.receive_attack(incoming(), player.global_position, player)
	check(enemy.health == 0 and hud.opponent_bar.value == 0 and numbers().back().amount == 5, "Enemy overkill/death updates actual number and health bar")
	enemy.reset_remaining = 0
	enemy._physics_process(0.01)
	check(enemy.health == enemy.max_health and hud.opponent_bar.value == enemy.max_health and enemy.guard.current == enemy.guard.starting_guard, "Enemy respawn resets health UI and Guard")
	if failures == 0:
		print("PASS: visible/projected immediate health, actual chip/overkill/multiple floating numbers, Guard costs/delay/hold pause, free parry/reflect, player full stun lock/no refresh/recovery protection, physical ALWAYS_BLOCK depletion and both Heavy punishes, Greatsword identity")
	quit(1 if failures else 0)
