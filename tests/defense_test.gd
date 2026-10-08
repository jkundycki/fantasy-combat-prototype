extends SceneTree

const Impact = preload("res://sandbox/incoming_attack.gd")
const Projectile = preload("res://sandbox/fireball.gd")
var failures: int = 0
var arena
var player
var weapon
var enemy
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func ticks(count: int) -> void:
	for index in range(count):
		await physics_frame
func action(name: String, pressed: bool = true) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
func incoming(melee: bool, blockable: bool, parryable: bool, reflectable: bool):
	var impact = Impact.new()
	impact.damage = 12
	impact.melee = melee
	impact.blockable = blockable
	impact.parryable = parryable
	impact.reflectable = reflectable
	return impact
func guard(normal: bool = false) -> void:
	weapon.guard.reset() # Each legacy defense case starts with a fresh shield.
	action("defense", false)
	weapon.freeze_remaining = 0
	await ticks(2)
	action("defense")
	await ticks(30 if normal else 2)
func launch(impact: Resource, x: float = 0.0, shot_speed: float = 5.0):
	var projectile = Projectile.new()
	projectile.impact = impact
	projectile.attacker = enemy
	projectile.speed = shot_speed
	arena.add_child(projectile)
	projectile.global_position = Vector3(x, 1, 2.2)
	projectile.direction = Vector3.BACK
	return projectile
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	for binding in [[JOY_BUTTON_X, "primary"], [JOY_BUTTON_RIGHT_SHOULDER, "special"], [JOY_BUTTON_LEFT_SHOULDER, "defense"], [JOY_BUTTON_B, "mobility"], [JOY_BUTTON_A, "jump"]]:
		var event := InputEventJoypadButton.new()
		event.button_index = binding[0]
		event.pressed = true
		check(InputMap.event_is_action(event, binding[1]), "Controller binding must map to universal action")
	check(not InputMap.has_action("dodge_sprint") and not InputMap.has_action("attack"), "Old sprint and class-style attack action names must be removed")
	arena = load("res://sandbox/arena.tscn").instantiate()
	preload("res://tests/baseline_tuning.gd").apply(arena)
	root.add_child(arena)
	player = arena.get_node("Player")
	weapon = player.weapon_set
	enemy = arena.get_node("TestEnemy")
	enemy.ai_enabled = false
	await ticks(100)
	enemy.set_physics_process(false)
	player.global_position = Vector3(0, 0.05, 3)
	player.velocity = Vector3.ZERO
	player.camera_rig.rotation.y = 0
	var melee = incoming(true, true, true, false)
	var front := Vector3(0, 1, 1)
	await guard(true)
	check(weapon.shield_state() == "BLOCK", "Held shield must expire into normal BLOCK")
	var health_before: float = player.health
	var result: String = player.receive_attack(melee, front, enemy)
	check(result == "BLOCK" and player.health == health_before and enemy.stagger_remaining == 0, "Normal block must negate damage without attacker stagger")
	await guard()
	check(weapon.shield_state() == "PERFECT BLOCK", "Initial raise must enable perfect window")
	result = player.receive_attack(melee, front, enemy)
	check(result == "PARRY" and player.health == health_before and enemy.state == "STAGGER", "Perfect parry must negate melee and stagger attacker")
	check(enemy.stagger_remaining == weapon.parry_stagger_duration and weapon.last_event == "PARRY", "Parry must use tunable stagger and show event")
	check(not weapon.primary(), "Defender recovery must briefly prevent instant counterattack")
	await ticks(25)
	check(weapon.primary(), "Short defender recovery must allow a counterattack")
	await ticks(70)
	enemy.stagger_remaining = 0
	enemy.state = "IDLE"
	await guard()
	result = player.receive_attack(incoming(true, true, false, false), front, enemy)
	check(result == "BLOCK" and enemy.stagger_remaining == 0, "Unparryable melee must normal-block even in perfect window")
	await guard()
	result = player.receive_attack(melee, Vector3(0, 1, 5), enemy)
	check(result == "HIT" and player.health == health_before - 12, "Behind shield must still take damage")
	await guard()
	result = player.receive_attack(melee, Vector3(3, 1, 3), enemy)
	check(result == "HIT", "Side attacks outside defensive arc must hit")
	await guard()
	result = player.receive_attack(incoming(false, false, false, false), front, enemy)
	check(result == "HIT", "Unblockable/unreflectable spell must ignore perfect shield")
	await guard()
	result = player.receive_attack(incoming(false, true, true, false), front, enemy)
	check(result == "BLOCK" and enemy.stagger_remaining == 0, "Projectile parry flag alone must not cause melee parry or reflection")
	weapon.perfect_block_duration = 0
	await guard()
	check(weapon.shield_state() == "BLOCK", "Zero perfect duration must disable perfect blocks")
	weapon.perfect_block_duration = 0.16
	weapon.block_startup = 0.08
	await guard()
	check(weapon.shield_state() == "RAISING" and player.receive_attack(melee, front, enemy) == "HIT", "Block startup must remain vulnerable")
	await ticks(11)
	check(weapon.shield_state() == "PERFECT BLOCK", "Perfect window must begin after startup")
	weapon.block_startup = 0

	# Actual traveling fireballs, not just resolver calls.
	player.health = 100
	enemy.health = 100
	enemy.global_position = Vector3(0, 0.05, -2)
	await guard()
	var shot = launch(incoming(false, true, false, true))
	await ticks(12)
	check(is_instance_valid(shot) and shot.reflected and shot.direction.z < 0, "Perfect shield must redirect real fireball along player forward")
	check(weapon.last_event == "SPELL REFLECT" and player.health == 100, "Reflection must negate damage and provide event")
	await ticks(140)
	check(enemy.health == 88, "Returned fireball must damage original attacker")
	await guard(true)
	launch(incoming(false, true, false, true))
	await ticks(20)
	check(player.health == 100 and weapon.last_event.begins_with("GUARD DAMAGE") and weapon.guard.current == 85, "Normal shield must dissipate reflectable fireball without reflecting")
	await guard()
	launch(incoming(false, true, false, false))
	await ticks(20)
	check(player.health == 100 and weapon.last_event.begins_with("GUARD DAMAGE") and weapon.guard.current == 85, "Unreflectable blockable projectile must never reflect")
	await guard()
	launch(incoming(false, false, false, false), 0, 100)
	await ticks(5)
	check(player.health == 88, "Fast unblockable projectile must hit via swept segment without tunneling")
	action("defense", false)
	launch(incoming(false, false, false, false), 2)
	await ticks(25)
	check(player.health == 88, "Projectile passing beside player must physically miss")

	# Enemy actual melee overlap respects committed facing, distance and guard.
	for projectile in get_nodes_in_group("test_projectiles"):
		projectile.queue_free()
	await ticks(2)
	enemy.global_position = Vector3(0, 0.05, 1.4)
	enemy.rotation.y = PI
	enemy.state = "IDLE"
	enemy.stagger_remaining = 0
	await guard(true)
	enemy.begin_melee()
	enemy.state = "MELEE_ACTIVE"
	enemy.query_melee()
	check(enemy.hit_player and player.health == 88 and enemy.stagger_remaining == 0, "Real enemy melee must normal block without stagger")
	await guard()
	enemy.begin_melee()
	enemy.state = "MELEE_ACTIVE"
	enemy.query_melee()
	check(enemy.state == "STAGGER", "Real enemy melee must parry during perfect window")
	action("defense", false)
	enemy.begin_melee()
	enemy.state = "MELEE_ACTIVE"
	enemy.rotation.y = 0
	enemy.query_melee()
	check(not enemy.hit_player, "Enemy swing in wrong direction must miss")
	enemy.rotation.y = PI
	player.global_position.x = 4
	await ticks(3)
	enemy.query_melee()
	check(not enemy.hit_player, "Moving outside enemy volume must avoid committed swing")
	# Player is not immune while airborne and resets for continued laboratory use.
	player.global_position.y = 1.5
	await ticks(2)
	var lethal = incoming(false, false, false, false)
	lethal.damage = 1000
	check(player.receive_attack(lethal, front, enemy) == "HIT" and player.health == 0, "Airborne player must have no special damage immunity")
	await ticks(150)
	check(player.health == player.max_health and not weapon.busy() and weapon.shield_state() == "DOWN", "Player death must reset health and weapon commitment for testing")
	if failures == 0:
		print("PASS: normal block, frontal arc/back/side vulnerability, perfect timing/startup/disable, parry versus ordinary block, counter recovery, independent attack flags, traveling reflect and return damage, normal projectile block, unreflectable/unblockable shots, sweep/dodge misses, enemy melee overlap")
	quit(1 if failures else 0)