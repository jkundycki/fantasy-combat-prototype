extends SceneTree
const Impact = preload("res://sandbox/incoming_attack.gd")
var failures: int = 0
var bot
var player
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame
func advance(seconds: float) -> void:
	for i in range(ceili(seconds / 0.01)):
		bot._physics_process(0.01)
func reset_bot() -> void:
	bot.health = 100
	bot.state = "IDLE"
	bot.cooldown = 100
	bot.freeze_remaining = 0
	bot.stagger_remaining = 0
	bot.decision_remaining = 0
	bot.reaction_remaining = 0
	bot.last_observed_id = 0
	bot.last_observed_serial = -1
	bot.global_position = Vector3(0, 0.05, 1.2)
	bot.rotation.y = PI
	player.weapon_set.reset_combat()
	player.stagger_remaining = 0
	player.visual.rotation.y = 0
func impact(guard_break: bool = false):
	var value = Impact.new()
	value.damage = 10
	value.melee = true
	value.blockable = true
	value.parryable = true
	value.guard_break = guard_break
	return value
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	var arena = load("res://sandbox/arena.tscn").instantiate()
	root.add_child(arena)
	player = arena.get_node("Player")
	bot = arena.get_node("TestEnemy")
	bot.ai_enabled = false
	await ticks(100)
	player.set_physics_process(false)
	bot.set_physics_process(false)
	bot.ai_enabled = true
	bot.apply_personality(5)
	bot.block_weight = 1
	bot.parry_weight = 0
	bot.dodge_weight = 0
	bot.greed_weight = 0
	bot.reaction_delay = 0.3
	bot.reaction_jitter = 0
	player.global_position = Vector3(0, 0.05, 3)
	player.velocity = Vector3.ZERO
	arena.get_node("TrainingDummy").global_position = Vector3(15, 0.9, 15)
	reset_bot()
	await ticks(3)
	check(bot.visible_pressure() == null, "Bot must not read a future attack from player input")
	player.weapon_set.primary()
	bot.global_position.x = 10
	check(bot.visible_pressure() == null, "Out-of-range visible actions must not be perceived")
	bot.global_position.x = 0
	bot.perception_arc = 90
	bot.rotation.y = 0
	check(bot.visible_pressure() == null, "Actions outside perception arc must not be perceived")
	bot.rotation.y = PI
	bot.perception_arc = 240
	var wall = arena.box("PerceptionWall", Vector3(0, 1, 2.1), Vector3(3, 2, 0.2), Color.GRAY)
	await ticks(3)
	check(bot.visible_pressure() == null, "Opaque arena geometry must block perception")
	wall.queue_free()
	await ticks(3)
	bot._physics_process(0.01)
	check(bot.state == "REACT" and bot.reaction_remaining == 0.3, "Visible startup must begin delayed perception")
	advance(0.25)
	check(bot.state == "REACT" and bot.decisions_made == 0, "No instant defense before reaction time")
	advance(0.06)
	check(bot.state == "BLOCK" and bot.decision == "BLOCK", "Only weighted response must begin after delay")
	var before: float = bot.health
	check(bot.receive_attack(impact(), player.global_position, player) == "BLOCK" and bot.health == before and player.stagger_remaining == 0, "Normal block must stop attack without parry advantage")
	var choice_count: int = bot.decisions_made
	player.weapon_set.reset_combat()
	player.weapon_set.special()
	advance(0.1)
	check(bot.state == "BLOCK" and bot.decisions_made == choice_count, "New player action must not revise a committed defense")
	var bash = impact(true)
	bash.stagger_duration = 0.2
	check(bot.receive_attack(bash, player.global_position, player) == "HIT" and bot.state == "STAGGER", "Guard break must beat block and stagger")
	advance(0.1)
	check(bot.state == "STAGGER" and bot.decisions_made == choice_count, "Stagger must prevent immediate defensive escape")
	advance(0.3)
	check(bot.stagger_remaining == 0, "Stagger must eventually end")

	reset_bot()
	bot.parry_prediction_delay = 0.1
	bot.parry_prediction_jitter = 0
	bot.commit_response("PARRY")
	check(bot.receive_attack(impact(), player.global_position, player) == "HIT", "Parry preparation must be vulnerable to an early attack")
	advance(0.11)
	check(bot.state == "PARRY_WINDOW", "Attempt must open a real finite window")
	check(bot.receive_attack(impact(), player.global_position, player) == "PARRY" and player.stagger_remaining > 0, "Only actual contact during window must parry")
	reset_bot()
	bot.commit_response("PARRY")
	advance(0.11 + bot.parry_window + 0.03)
	check(bot.state == "RECOVERY" and bot.receive_attack(impact(), player.global_position, player) == "HIT", "Late contact after window must punish parry recovery")

	# A finisher read remains committed when changed to actual hilt bash geometry.
	reset_bot()
	player.weapon_set = player.get_node("Greatsword")
	player.weapon_set.reset_combat()
	bot.global_position.z = 2.1
	await ticks(3)
	player.weapon_set.heavy_attack()
	player.weapon_set.tick(0.2)
	bot.commit_response("PARRY")
	advance(0.11)
	var committed_decisions: int = bot.decisions_made
	check(player.weapon_set.special(), "Player finisher must remain feintable")
	for i in range(25):
		player.weapon_set.tick(0.01)
		bot._physics_process(0.01)
	check(bot.health == 96 and bot.stagger_remaining > 0 and bot.decisions_made == committed_decisions, "Physical feint must punish parry read without bot changing its choice")

	reset_bot()
	bot.global_position.z = 2.1
	bot.backward_dodge_chance = 1
	await ticks(3)
	var start: Vector3 = bot.global_position
	bot.commit_response("DODGE")
	var direction: Vector3 = bot.dodge_direction
	advance(0.18)
	check(bot.global_position.distance_to(start) > 1 and bot.global_position.distance_to(start) < 3, "Dodge must physically displace rather than teleport")
	check(bot.dodge_direction == direction, "Dodge direction must remain committed")
	await ticks(3) # Flush moved body transforms before querying physical overlap.
	player.weapon_set.feint.begin()
	for i in range(25):
		player.weapon_set.tick(0.01)
		bot._physics_process(0.01)
	check(bot.health == 100, "Physical dodge spacing must cause short hilt bash to miss")
	reset_bot()
	bot.commit_response("DODGE")
	check(bot.receive_attack(impact(), player.global_position, player) == "HIT", "Dodge must not grant artificial damage immunity")

	reset_bot()
	bot.commit_response("GREED")
	var yaw: float = bot.attack_yaw
	player.global_position.x += 3
	advance(0.2)
	check(bot.state == "MELEE_STARTUP" and absf(angle_difference(bot.rotation.y, yaw)) < 0.001, "Greed attack must preserve direction commitment")
	bot.stagger(0.6, 0)
	advance(0.2)
	check(bot.state == "STAGGER" and bot.reaction_remaining == 0, "Parried bot must remain staggered, not resume decision")
	bot.apply_personality(1)
	check(bot.block_weight > bot.parry_weight and bot.block_weight > bot.greed_weight, "Turtle preset must alter weights")
	bot.apply_personality(2)
	check(bot.parry_weight > bot.block_weight, "Parry-happy preset must favor attempts")
	bot.apply_personality(3)
	check(bot.dodge_weight > bot.block_weight, "Slippery preset must favor dodge")
	bot.apply_personality(4)
	check(bot.greed_weight > bot.block_weight, "Aggressive preset must favor greed")
	if failures == 0:
		print("PASS: delayed observable perception, weighted decisions, commitment, normal block, finite early/late parry, physical feint punish, physical dodge/no immunity, greed facing lock, stagger priority, personality weights")
	quit(1 if failures else 0)