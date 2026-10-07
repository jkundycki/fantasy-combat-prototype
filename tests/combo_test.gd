extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func advance(weapon, seconds: float) -> void:
	for i in range(ceili(seconds / 0.005)):
		weapon.tick(0.005)
func recover(weapon) -> void:
	for i in range(1000):
		if weapon.chain.active().state == "ATTACK_RECOVERY":
			return
		weapon.tick(0.005)
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	check(InputMap.event_is_action(key, "heavy"), "E maps to Heavy")
	key.physical_keycode = KEY_F
	check(InputMap.event_is_action(key, "special"), "F maps to Bash")
	key.physical_keycode = KEY_R
	check(InputMap.event_is_action(key, "cancel_feint"), "R maps to Cancel")
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1
	check(InputMap.event_is_action(trigger, "heavy"), "Controller right trigger maps to Heavy")
	var stick := InputEventJoypadButton.new()
	stick.button_index = JOY_BUTTON_RIGHT_STICK
	check(InputMap.event_is_action(stick, "cancel_feint"), "R3 maps to Cancel")
	var arena = load("res://sandbox/arena.tscn").instantiate()
	root.add_child(arena)
	var player = arena.get_node("Player")
	var enemy = arena.get_node("TestEnemy")
	enemy.ai_enabled = false
	for i in range(100):
		await physics_frame
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	enemy.global_position = Vector3(15, 0, 15)
	arena.get_node("TrainingDummy").global_position = Vector3(15, 1, 15)
	for weapon in player.weapon_sets:
		player.weapon_set = weapon
		weapon.reset_combat()
		check(weapon.primary(), "Light 1 starts")
		check(not weapon.primary() and not weapon.heavy_attack(), "No startup overlap")
		recover(weapon)
		advance(weapon, weapon.chain.active().recovery_duration * 0.4)
		check(weapon.primary(), "Light 2 can buffer")
		check(weapon.chain.step == 0, "No skipping preceding recovery")
		advance(weapon, weapon.chain.active().recovery_duration * 0.7)
		check(weapon.chain.step == 1, "Buffered Light 2 begins")
		recover(weapon)
		advance(weapon, weapon.chain.active().recovery_duration * 0.4)
		check(weapon.primary(), "Light 3 can buffer")
		advance(weapon, weapon.chain.active().recovery_duration * 0.7)
		check(weapon.chain.step == 2 and not weapon.chain.active().can_feint(), "Light 3 is not a feintable Heavy")
		var third = weapon.chain.attacks[2]
		check(third.damage > weapon.chain.attacks[1].damage and third.damage < weapon.heavy.damage, "Light 3 reward lies between Light 2 and Heavy")
		check(third.startup_duration < weapon.heavy.startup_duration and third.recovery_duration < weapon.heavy.recovery_duration and not third.guard_break, "Light 3 is faster and ordinarily defended")
		advance(weapon, 2)
		check(not weapon.busy() and weapon.chain.next_step == 0, "Three-hit chain resets")
		weapon.primary()
		recover(weapon)
		advance(weapon, 1.5)
		check(weapon.chain.next_step == 0, "Combo timeout resets")
		weapon.reset_combat()
		weapon.chain.next_step = 1
		weapon.primary()
		recover(weapon)
		advance(weapon, weapon.chain.active().recovery_duration * 0.4)
		check(weapon.heavy_attack() and weapon.chain.buffered_heavy, "Light 2 offers buffered Heavy")
		check(not weapon.heavy.busy(), "Heavy waits for full Light 2 recovery")
		advance(weapon, weapon.chain.active().recovery_duration * 0.7)
		check(weapon.active_swing() == weapon.heavy and weapon.heavy.busy() and not weapon.chain.running, "Branch uses same neutral Heavy instance")
		weapon.reset_combat()
		check(weapon.heavy_attack(), "Neutral Heavy starts")
		check(not weapon.primary() and weapon.heavy.busy(), "Primary never soft-feints Heavy")
		check(weapon.hard_feint(), "Hard feint accepted early")
		check(not weapon.busy() if weapon.hard_feint_recovery == 0 else weapon.busy(), "Recovery carries commitment")
		check(not weapon.primary() and not weapon.special() and not weapon.heavy_attack() and not player.switch_weapon(), "No overlap or switching during recovery")
		weapon.defense(true)
		check(not weapon.shield_raised if weapon.has_method("shield_state") else weapon.parry_state == "DOWN", "Defense cannot open during reset")
		weapon.defense(false)
		check(weapon.movement_scale() == 1, "Movement remains available during reset")
		advance(weapon, weapon.hard_feint_recovery + 0.02)
		check(not weapon.busy() and not weapon.chain.running, "Cancel chooses no automatic follow-up")
		check(weapon.primary() and weapon.chain.step == 0, "Fresh Light after reset")
		weapon.reset_combat()
		weapon.heavy_attack()
		weapon.heavy.elapsed = weapon.heavy.startup_duration * weapon.heavy.feint_startup_fraction - 0.001
		check(weapon.heavy.can_feint() and weapon.special(), "Bash replaces Heavy before cutoff")
		check(weapon.feint.busy() and weapon.feint.guard_break and not weapon.heavy.busy(), "Bash is sole guard-breaking soft-feint")
		weapon.reset_combat()
		weapon.heavy_attack()
		weapon.heavy.elapsed = weapon.heavy.startup_duration * weapon.heavy.feint_startup_fraction
		check(not weapon.hard_feint() and not weapon.special() and not weapon.primary(), "Exact cutoff locks all branches")
		check(weapon.heavy.facing_committed(), "Facing locks at configurable cutoff")
		weapon.heavy.elapsed = weapon.heavy.startup_duration
		weapon.tick(0.005)
		check(not weapon.hard_feint() and not weapon.special(), "Active Heavy cannot cancel")
		weapon.reset_combat()
	# Actual Light 3 geometry retains ordinary block/parry and directional misses.
	player.global_position = Vector3(0, 0.05, 3)
	enemy.global_position = Vector3(0, 0.05, 1.5)
	enemy.rotation.y = PI
	for i in range(3):
		await physics_frame
	for weapon in player.weapon_sets:
		player.weapon_set = weapon
		for guard in [1, 2, 0]:
			player.stagger_remaining = 0
			enemy.health = enemy.max_health
			enemy.test_guard_mode = guard
			weapon.reset_combat()
			player.visual.rotation.y = PI if guard == 0 else 0
			weapon.chain.next_step = 2
			weapon.primary()
			advance(weapon, 1.2)
			check(enemy.health == enemy.max_health, "Light 3 must be blockable/parryable and miss behind facing")
			if guard == 2:
				check(player.stagger_remaining > 0, "Light 3 contact must allow ordinary parry")
		enemy.test_guard_mode = 0
		weapon.reset_combat()
	player.stagger_remaining = 0
	# AI commitment survives hard feint; it never reads the next input.
	player.weapon_set = player.get_node("Greatsword")
	player.weapon_set.heavy_attack()
	enemy.commit_response("PARRY")
	var decisions: int = enemy.decisions_made
	check(player.weapon_set.hard_feint(), "AI bait uses real hard cancel")
	enemy._physics_process(0.02)
	check(enemy.state in ["PARRY_ATTEMPT", "PARRY_WINDOW"] and enemy.decisions_made == decisions, "Bot retains committed parry")
	if failures == 0:
		print("PASS: full Light chains/recovery buffers/timeouts, Light2-Heavy same move, no chase, hard-feint reset/overlap, cutoff/facing, bash-only soft-feint, AI commitment")
	quit(1 if failures else 0)
