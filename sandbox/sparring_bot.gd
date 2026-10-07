extends "res://sandbox/test_enemy.gd"

@export_group("Perception")
@export var sparring_enabled: bool = true
@export var perception_range: float = 4.0
@export_range(30.0, 360.0) var perception_arc: float = 240.0
@export var reaction_delay: float = 0.28
@export var reaction_jitter: float = 0.07
@export var turning_speed_degrees: float = 180.0
@export_group("Decision weights")
@export_enum("BALANCED", "TURTLE", "PARRY_HAPPY", "SLIPPERY", "AGGRESSIVE", "CUSTOM") var personality: int = 0
@export var block_weight: float = 3.0
@export var parry_weight: float = 2.0
@export var dodge_weight: float = 2.0
@export var greed_weight: float = 3.0
@export_group("Committed defense")
@export var block_duration: float = 0.5
@export var defensive_arc_degrees: float = 120.0
@export var parry_prediction_delay: float = 0.1
@export var parry_prediction_jitter: float = 0.1
@export var parry_window: float = 0.18
@export var parry_attacker_stagger: float = 0.6
@export var parry_hit_stop: float = 0.035
@export var defensive_recovery: float = 0.28
@export var missed_parry_recovery: float = 0.4
@export_group("Physical dodge")
@export var dodge_speed: float = 9.0
@export var dodge_duration: float = 0.2
@export_range(0.0, 1.0) var backward_dodge_chance: float = 0.35
@export var dodge_recovery: float = 0.3
@export_group("Development")
@export var random_seed: int = 0

var decision: String = "NONE"
var reaction_remaining: float = 0.0
var decision_remaining: float = 0.0
var dodge_direction := Vector3.ZERO
var last_observed_id: int = 0
var last_observed_serial: int = -1
var decisions_made: int = 0
var rng := RandomNumberGenerator.new()
var applied_personality: int = -1

func _ready() -> void:
	super._ready()
	if random_seed == 0:
		rng.randomize()
	else:
		rng.seed = random_seed
	apply_personality(personality)

func apply_personality(selected: int) -> void:
	personality = selected
	applied_personality = selected
	var presets := [[3, 2, 2, 3], [7, 1, 1, 1], [1, 7, 1, 1], [1, 1, 7, 1], [1, 1, 1, 7]]
	if selected < 5:
		var values: Array = presets[selected]
		block_weight = values[0]
		parry_weight = values[1]
		dodge_weight = values[2]
		greed_weight = values[3]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("bot_personality"):
		apply_personality((personality + 1) % 5)
	if event.is_action_pressed("bot_mode"):
		sparring_enabled = not sparring_enabled
		# Development mode changes only while not committed or staggered.
		if state not in ["IDLE", "APPROACH"] or stagger_remaining > 0:
			sparring_enabled = not sparring_enabled
			return
		state = "IDLE"
		decision = "NONE"
		reaction_remaining = 0
		cooldown = attack_interval

func visible_pressure():
	# Read only a visible, already-started action. Never inspect player inputs,
	# queued combos, future steps, feint eligibility or predicted hit timings.
	if not player.weapon_set.busy():
		return null
	var swing = player.weapon_set.active_swing()
	if swing.state not in ["ATTACK_STARTUP", "ATTACK_ACTIVE"]:
		return null
	if swing.get_instance_id() == last_observed_id and swing.attack_serial == last_observed_serial:
		return null
	var offset: Vector3 = player.global_position - global_position
	if offset.length() > perception_range:
		return null
	offset.y = 0
	if not offset.is_zero_approx() and (-global_basis.z).dot(offset.normalized()) < cos(deg_to_rad(perception_arc / 2)):
		return null
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1, 0), player.global_position + Vector3(0, 1, 0), 1)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return null
	return swing

func perceive(swing) -> void:
	last_observed_id = swing.get_instance_id()
	last_observed_serial = swing.attack_serial
	reaction_remaining = maxf(0.01, reaction_delay + rng.randf_range(-reaction_jitter, reaction_jitter))
	decision = "WAITING / READ"
	state = "REACT"

func choose_response() -> String:
	var weights := [maxf(0, block_weight), maxf(0, parry_weight), maxf(0, dodge_weight), maxf(0, greed_weight)]
	var total: float = weights[0] + weights[1] + weights[2] + weights[3]
	var roll := rng.randf() * total
	for i in range(4):
		roll -= weights[i]
		if roll < 0:
			return ["BLOCK", "PARRY", "DODGE", "GREED"][i]
	return "GREED"

func commit_response(choice: String) -> void:
	decision = choice
	decisions_made += 1
	if choice == "BLOCK":
		state = "BLOCK"
		decision_remaining = maxf(0.01, block_duration)
	elif choice == "PARRY":
		state = "PARRY_ATTEMPT"
		decision_remaining = maxf(0, parry_prediction_delay + rng.randf_range(-parry_prediction_jitter, parry_prediction_jitter))
	elif choice == "DODGE":
		state = "DODGE"
		decision_remaining = maxf(0.01, dodge_duration)
		var away: Vector3 = global_position - player.global_position
		away.y = 0
		away = away.normalized() if not away.is_zero_approx() else global_basis.z
		if rng.randf() < backward_dodge_chance:
			dodge_direction = away
		else:
			dodge_direction = away.cross(Vector3.UP) * (-1 if rng.randf() < 0.5 else 1)
	else:
		# Greed commits to the inherited, visibly telegraphed melee even if
		# it will whiff. The bot cannot change its mind after seeing a feint.
		begin_melee()

func recover(duration: float) -> void:
	state = "RECOVERY"
	decision_remaining = maxf(0, duration)

func _physics_process(delta: float) -> void:
	if not sparring_enabled or not ai_enabled:
		super._physics_process(delta)
		return
	if personality != applied_personality:
		apply_personality(personality)
	# Inherited attack, hit-stop, death and stagger rules have priority.
	if health <= 0 or freeze_remaining > 0 or stagger_remaining > 0 or state.begins_with("MELEE_") or state.begins_with("FIREBALL_") or state == "STAGGER":
		super._physics_process(delta)
		return
	flash_remaining = maxf(0, flash_remaining - delta)
	visual.position = visual.position.move_toward(Vector3(0, 0.9, 0), recoil_return_speed * delta)
	velocity.x = 0
	velocity.z = 0
	if state in ["IDLE", "APPROACH"] and player.health > 0:
		var offset: Vector3 = player.global_position - global_position
		offset.y = 0
		var yaw := atan2(-offset.x, -offset.z)
		rotation.y = rotate_toward(rotation.y, yaw, deg_to_rad(turning_speed_degrees) * delta)
		var swing = visible_pressure()
		if swing != null:
			perceive(swing)
		else:
			cooldown = maxf(0, cooldown - delta)
			if offset.length() > 1.8:
				state = "APPROACH"
				velocity.x = offset.normalized().x * move_speed
				velocity.z = offset.normalized().z * move_speed
			elif cooldown <= 0:
				decision = "PRESSURE"
				begin_melee()
			else:
				state = "IDLE"
	elif state == "REACT":
		reaction_remaining = maxf(0, reaction_remaining - delta)
		if reaction_remaining <= 0:
			commit_response(choose_response())
	elif state in ["BLOCK", "PARRY_ATTEMPT", "PARRY_WINDOW", "DODGE", "RECOVERY"]:
		decision_remaining = maxf(0, decision_remaining - delta)
		if state == "DODGE":
			velocity.x = dodge_direction.x * dodge_speed
			velocity.z = dodge_direction.z * dodge_speed
		if decision_remaining <= 0:
			if state == "PARRY_ATTEMPT":
				state = "PARRY_WINDOW"
				decision_remaining = maxf(0, parry_window)
			elif state == "RECOVERY":
				state = "IDLE"
				cooldown = attack_interval
			else:
				recover(missed_parry_recovery if state == "PARRY_WINDOW" else (dodge_recovery if state == "DODGE" else defensive_recovery))
	velocity.y -= 28 * delta
	move_and_slide()
	update_visuals()

func receive_attack(impact: Resource, origin: Vector3, attacker_node: Node) -> String:
	if not sparring_enabled or not ai_enabled:
		return super.receive_attack(impact, origin, attacker_node)
	var incoming := origin - global_position
	incoming.y = 0
	var frontal := not incoming.is_zero_approx() and (-global_basis.z).dot(incoming.normalized()) >= cos(deg_to_rad(defensive_arc_degrees / 2))
	if health > 0 and stagger_remaining <= 0 and frontal and not impact.guard_break:
		if state == "PARRY_WINDOW" and impact.melee and impact.parryable:
			if is_instance_valid(attacker_node) and attacker_node.has_method("stagger"):
				attacker_node.stagger(parry_attacker_stagger, parry_hit_stop)
			freeze_remaining = parry_hit_stop
			recover(defensive_recovery)
			return "PARRY"
		if state == "BLOCK" and impact.blockable:
			flash_remaining = flash_duration
			return "BLOCK"
	# Static guard fixture must not override the actual sparring decisions.
	var saved_fixture := test_guard_mode
	test_guard_mode = 0
	var result: String = super.receive_attack(impact, origin, attacker_node)
	test_guard_mode = saved_fixture
	return result

func stagger(duration: float, freeze_time: float = 0) -> void:
	reaction_remaining = 0
	decision_remaining = 0
	decision = "STAGGERED"
	super.stagger(duration, freeze_time)

func update_visuals() -> void:
	super.update_visuals()
	if material == null or flash_remaining > 0:
		return
	if state == "BLOCK":
		material.albedo_color = Color("4f83c7")
	elif state == "PARRY_WINDOW":
		material.albedo_color = Color.CYAN
	elif state == "PARRY_ATTEMPT":
		material.albedo_color = Color("b6a5df")
	elif state == "DODGE":
		material.albedo_color = Color("73b583")

func ai_debug_text() -> String:
	return "AI %s | %s | %s\nRead %.2f s | Decision timer %.2f s | Parry window %s\nDodge %s | Weights B/P/D/G %.1f/%.1f/%.1f/%.1f\nF4 personality | F6 sparring/original projectile test" % [["BALANCED", "TURTLE", "PARRY_HAPPY", "SLIPPERY", "AGGRESSIVE", "CUSTOM"][personality], state, decision, reaction_remaining, decision_remaining, state == "PARRY_WINDOW", dodge_direction, block_weight, parry_weight, dodge_weight, greed_weight]