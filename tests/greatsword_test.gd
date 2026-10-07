extends SceneTree
const Impact = preload("res://sandbox/incoming_attack.gd")
const Projectile = preload("res://sandbox/fireball.gd")
var failures: int = 0
var player
var weapon
var dummy
var enemy
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
func action(name: String, pressed: bool = true) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
func pose(distance: float, angle: float = 0) -> void:
	weapon.reset_combo()
	player.global_position = Vector3(0, 0.05, 3)
	player.velocity = Vector3.ZERO
	dummy.global_position = Vector3(sin(deg_to_rad(angle)) * distance, 0.9, 3 - cos(deg_to_rad(angle)) * distance)
	dummy.health = 100
	await ticks(10)
	player.visual.rotation.y = 0
func attack(special: bool = false) -> void:
	action("heavy" if special else "primary")
	await ticks(2)
	action("heavy" if special else "primary", false)
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	var ctrl := InputEventKey.new()
	ctrl.physical_keycode = KEY_CTRL
	ctrl.location = KEY_LOCATION_LEFT
	ctrl.pressed = true
	check(InputMap.event_is_action(ctrl, "defense"), "Left Ctrl must bind Defense through InputMap")
	var switch_button := InputEventJoypadButton.new()
	switch_button.button_index = JOY_BUTTON_Y
	switch_button.pressed = true
	check(InputMap.event_is_action(switch_button, "weapon_switch"), "Controller Y/Triangle must bind test switching")
	var arena = load("res://sandbox/arena.tscn").instantiate()
	root.add_child(arena)
	player = arena.get_node("Player")
	dummy = arena.get_node("TrainingDummy")
	enemy = arena.get_node("TestEnemy")
	enemy.ai_enabled = false
	await ticks(100)
	action("weapon_switch")
	await ticks(2)
	action("weapon_switch", false)
	weapon = player.weapon_set
	# Independent legacy shape test; new combo test checks bounded early tracking.
	weapon.heavy.turn_speed_degrees = 0.0
	check(weapon == player.get_node("Greatsword") and weapon.visible and not player.get_node("SwordShield").visible, "Universal switch action must select only Greatsword")
	await pose(2.7)
	await attack()
	check(weapon.slash.state == weapon.slash.STARTUP and dummy.health == 100, "Greatsword must have deliberate windup")
	check(not player.switch_weapon() and not weapon.special(), "Switching/chaining must not cancel commitment")
	await ticks(100)
	check(dummy.health == 60 and weapon.slash.hit_targets.size() == 1, "Longer slash must damage once")
	await pose(2.0, 60)
	await attack()
	await ticks(100)
	check(dummy.health == 60, "Broad slash must hit off-angle target within its arc")
	await pose(2.0, 60)
	await attack(true)
	await ticks(160)
	check(dummy.health == 100, "Narrow overhead must whiff same off-angle target")
	await pose(2.4)
	await attack(true)
	player.camera_rig.rotation.y = PI
	await ticks(20)
	check(dummy.health == 100 and absf(weapon.heavy.locked_yaw) < 0.01, "Heavy windup must be visible and not freely track camera")
	await ticks(60)
	check(dummy.health == 35 and weapon.heavy.state == weapon.heavy.RECOVERY, "Heavy must pay off with damage and committed recovery")
	check(not player.switch_weapon(), "Heavy recovery must prevent switching")
	await ticks(100)
	await pose(1.5)
	dummy.global_position = Vector3(-10, 0.9, 10)
	enemy.global_position = Vector3(0, 0.05, 1.5)
	enemy.health = 100
	await attack(true)
	await ticks(70)
	check(enemy.health == 35 and enemy.stagger_remaining > 0.7, "Heavy hit must strongly stagger enemy")
	await ticks(150)
	enemy.global_position = Vector3(8, 0.05, -4)
	var impact = Impact.new()
	impact.melee = true
	impact.parryable = true
	impact.blockable = true
	impact.damage = 12
	player.camera_rig.rotation.y = 0
	action("defense")
	await ticks(2)
	check(weapon.parry_state == "PARRY_STARTUP", "Defense press must begin finite timed attempt")
	var before: float = player.health
	check(player.receive_attack(impact, Vector3(0, 1, 1), enemy) == "HIT", "Parry startup must remain vulnerable")
	await ticks(6)
	check(weapon.parry_state == "PARRY_WINDOW", "Timed parry window must open")
	check(player.receive_attack(impact, Vector3(0, 1, 1), enemy) == "PARRY" and enemy.state == "STAGGER", "Melee parry must negate damage and stagger")
	check(player.health == before - 12 and not weapon.primary(), "Successful parry must have brief defender recovery")
	await ticks(25)
	check(weapon.primary(), "Successful parry must allow counterattack after short recovery")
	await ticks(110)
	action("defense", false)
	action("defense")
	await ticks(80)
	check(weapon.parry_state == "DOWN", "Holding defense must not sustain or repeat parry")
	check(player.receive_attack(impact, Vector3(0, 1, 1), enemy) == "HIT", "Expired Greatsword defense must not normal-block")
	action("defense", false)
	action("defense")
	await ticks(8)
	var shot = Projectile.new()
	shot.attacker = enemy
	shot.impact = Impact.new()
	shot.impact.reflectable = true
	shot.impact.blockable = true
	shot.impact.damage = 12
	arena.add_child(shot)
	shot.global_position = player.global_position + Vector3(0, 1, -0.7)
	shot.direction = Vector3.BACK
	before = player.health
	await ticks(12)
	check(player.health == before - 12 and not is_instance_valid(shot), "Greatsword parry window must take projectile damage without block/reflect")
	await ticks(70)
	action("defense", false)
	check(player.switch_weapon(), "Idle Greatsword must switch back")
	check(player.weapon_set == player.get_node("SwordShield"), "Sword & Shield must remain equipped through same interface")
	action("defense")
	await ticks(2)
	check(player.weapon_set.shield_state() == "PERFECT BLOCK", "Switching back must preserve shield perfect block")
	await ticks(30)
	check(player.weapon_set.shield_state() == "BLOCK", "Sword & Shield must still sustain held block")
	action("defense", false)
	if failures == 0:
		print("PASS: universal switching, longer/broader slash, narrow heavy whiffs, heavy commitment/stagger, finite melee parry/startup/recovery/counter, no sustained block or spell reflect, Sword & Shield preserved")
	quit(1 if failures else 0)