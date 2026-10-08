extends "res://sandbox/test_enemy.gd"

@export_group("Perception")
@export var sparring_enabled: bool = true
@export var perception_range: float = 4.0
@export_range(30.0, 360.0) var perception_arc: float = 240.0
@export var reaction_delay: float = 0.56
@export var reaction_jitter: float = 0.14
@export var turning_speed_degrees: float = 90.0
@export_group("Decision weights")
@export_enum("BALANCED", "TURTLE", "PARRY_HAPPY", "SLIPPERY", "AGGRESSIVE", "CUSTOM", "ALL_OUT") var personality: int = 0
@export var block_weight: float = 3.0
@export var parry_weight: float = 2.0
@export var dodge_weight: float = 2.0
@export var greed_weight: float = 3.0
@export_group("Committed defense")
@export var block_duration: float = 1.0
@export var defensive_arc_degrees: float = 120.0
@export var parry_prediction_delay: float = 0.2
@export var parry_prediction_jitter: float = 0.2
@export var parry_window: float = 0.36
@export var parry_attacker_stagger: float = 1.2
@export var parry_hit_stop: float = 0.07
@export var defensive_recovery: float = 0.56
@export var missed_parry_recovery: float = 0.8
@export_group("Physical dodge")
@export var dodge_speed: float = 4.5
@export var dodge_duration: float = 0.54
@export_range(0.0, 1.0) var backward_dodge_chance: float = 0.35
@export var dodge_recovery: float = 0.6
@export var dodge_cooldown: float = 5.0
var dodge_cooldown_remaining: float = 0
@export_group("Training defense")
@export_enum("SWORD & SHIELD", "GREATSWORD", "STAFF", "BOW") var opponent_weapon: int = 0
@export_enum("SPARRING", "ALWAYS_BLOCK") var training_mode: int = 0
@export_group("Development")
@export var random_seed: int = 0
@export var mirror_weapon: bool = true
@export var pressure_move_speed: float = 7.6
@export var pressure_attack_interval: float = 0.12
@export var staff_min_range: float = 6.0
@export var staff_max_range: float = 9.0
@export var bow_min_range: float = 9.0
@export var bow_max_range: float = 13.0
@export var ranged_move_speed: float = 4.0
@export var ranged_strafe_speed: float = 1.6
@export var arena_limit: float = 17.0
@export var spell_reflect_speed_multiplier: float = 2.0
var applied_weapon: int = -1
var melee_step: int = 0
var ranged_model: Node3D
var strafe_elapsed: float = 0
var queued_weapon: int = -1
@export var staff_charge_weights := Vector4(3, 2, 2, 2)
@export var staff_full_charge_extra_hold: float = 0.5
@export_range(0, 1) var held_bow_chance: float = 0.45
@export var bow_extra_hold: float = 0.5
var staff_hold_duration: float = 0
var bow_hold_duration: float = 0
var bot_charge_orb: MeshInstance3D

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
	if selected < 5 or selected == 6:
		var values: Array = [1, 1, 1, 12] if selected == 6 else presets[selected]
		block_weight = values[0]
		parry_weight = values[1]
		dodge_weight = values[2]
		greed_weight = values[3]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("bot_training") and not event.is_echo() and not guard_broken():
		training_mode = 1 - training_mode
		if state in ["IDLE", "APPROACH", "BLOCK"]:
			state = "IDLE"
	if event.is_echo():
		return
	if event.is_action_pressed("bot_pressure"):
		apply_personality(0 if personality == 6 else 6)
	if event.is_action_pressed("bot_mirror"):
		mirror_weapon = not mirror_weapon
	if event.is_action_pressed("bot_personality"):
		apply_personality([1, 2, 3, 4, 6, 0, 0][personality])
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
	if swing.state not in ["ATTACK_STARTUP", "ATTACK_ACTIVE", "STAFF_CHARGE", "BOW_DRAW"]:
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
	var weights := [maxf(0, block_weight) if has_shield_guard() else 0.0, maxf(0, parry_weight) if opponent_weapon < 2 else 0.0, maxf(0, dodge_weight) if dodge_cooldown_remaining <= 0 else 0.0, maxf(0, greed_weight)]
	var total: float = weights[0] + weights[1] + weights[2] + weights[3]
	var roll := rng.randf() * total
	for i in range(4):
		roll -= weights[i]
		if roll < 0:
			return ["BLOCK", "PARRY", "DODGE", "GREED"][i]
	return "GREED"

func commit_response(choice: String) -> void:
	if guard_broken():
		return
	if opponent_weapon >= 2 and choice in ["BLOCK", "PARRY"]:
		choice = "DODGE"
	if choice == "BLOCK" and not has_shield_guard():
		choice = "PARRY"
	if choice == "DODGE" and dodge_cooldown_remaining > 0:
		choice = "GREED"
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
		dodge_cooldown_remaining = dodge_cooldown
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
		begin_weapon_attack()

func recover(duration: float) -> void:
	state = "RECOVERY"
	decision_remaining = maxf(0, duration)

func _physics_process(delta: float) -> void:
	dodge_cooldown_remaining = maxf(0, dodge_cooldown_remaining - delta)
	if ai_enabled and sparring_enabled:
		sync_weapon()
	if guard_broken():
		super._physics_process(delta)
		return
	if not sparring_enabled or not ai_enabled:
		super._physics_process(delta)
		return
	if personality != applied_personality:
		apply_personality(personality)
	# Inherited attack, hit-stop, death and stagger rules have priority.
	if health <= 0 or freeze_remaining > 0 or stagger_remaining > 0 or state.begins_with("MELEE_") or state.begins_with("FIREBALL_") or state in ["STAGGER", "STAFF_CHARGE", "BOW_DRAW"]:
		if opponent_weapon >= 2 and (state.begins_with("FIREBALL_") or state in ["STAFF_CHARGE", "BOW_DRAW"]) and health > 0 and freeze_remaining <= 0 and stagger_remaining <= 0:
			tick_ranged_attack(delta)
			return
		var was_attacking: bool = state.begins_with("MELEE_") or state.begins_with("FIREBALL_") or state == "STAGGER"
		super._physics_process(delta)
		if was_attacking and state == "IDLE" and personality == 6:
			cooldown = pressure_attack_interval
		return
	flash_remaining = maxf(0, flash_remaining - delta)
	visual.position = visual.position.move_toward(Vector3(0, 0.9, 0), recoil_return_speed * delta)
	velocity.x = 0
	velocity.z = 0
	if training_mode == 1 and has_shield_guard() and player.health > 0:
		state = "BLOCK"
		decision = "ALWAYS_BLOCK"
		var offset: Vector3 = player.global_position - global_position
		rotation.y = rotate_toward(rotation.y, atan2(-offset.x, -offset.z), deg_to_rad(turning_speed_degrees) * delta)
	elif state in ["IDLE", "APPROACH"] and player.health > 0:
		var offset: Vector3 = player.global_position - global_position
		offset.y = 0
		var yaw := atan2(-offset.x, -offset.z)
		rotation.y = rotate_toward(rotation.y, yaw, deg_to_rad(turning_speed_degrees) * delta)
		var swing = visible_pressure()
		if swing != null:
			perceive(swing)
		else:
			cooldown = maxf(0, cooldown - delta)
			if opponent_weapon >= 2:
				ranged_pressure(offset, delta)
			else:
				var preferred: float = minf(melee_range * 0.8, 2.35)
				if offset.length() > preferred:
					state = "APPROACH"
					var speed: float = pressure_move_speed if personality == 6 else move_speed
					velocity.x = offset.normalized().x * speed
					velocity.z = offset.normalized().z * speed
				elif cooldown <= 0:
					decision = "PRESSURE"
					begin_weapon_attack()
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
				cooldown = pressure_attack_interval if personality == 6 else attack_interval
			else:
				recover(missed_parry_recovery if state == "PARRY_WINDOW" else (dodge_recovery if state == "DODGE" else defensive_recovery))
	velocity.y -= 22.4 * delta
	move_and_slide()
	update_visuals()

func receive_attack(impact: Resource, origin: Vector3, attacker_node: Node) -> String:
	if not sparring_enabled or not ai_enabled:
		return super.receive_attack(impact, origin, attacker_node)
	var incoming := origin - global_position
	incoming.y = 0
	var frontal := not incoming.is_zero_approx() and (-global_basis.z).dot(incoming.normalized()) >= cos(deg_to_rad(defensive_arc_degrees / 2))
	if health > 0 and stagger_remaining <= 0 and not guard_broken() and frontal and not impact.guard_break:
		if state == "PARRY_WINDOW" and has_shield_guard() and not impact.melee and impact.reflectable:
			recover(defensive_recovery)
			Feedback.impact(self, "reflect")
			return "REFLECT"
		if state == "PARRY_WINDOW" and opponent_weapon < 2 and impact.melee and impact.parryable:
			if is_instance_valid(attacker_node) and attacker_node.has_method("stagger"):
				attacker_node.stagger(parry_attacker_stagger, parry_hit_stop)
			freeze_remaining = parry_hit_stop
			recover(defensive_recovery)
			Feedback.impact(self, "parry")
			return "PARRY"
		if state == "BLOCK" and impact.blockable and has_shield_guard():
			flash_remaining = flash_duration
			guard.absorb(impact.guard_damage)
			if not guard_broken():
				Feedback.impact(self, "block")
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
	if weapon != null:
		weapon.visible = opponent_weapon < 2
	if ranged_model != null:
		ranged_model.visible = opponent_weapon >= 2
		ranged_model.rotation.x = -0.6 if state == "STAFF_CHARGE" else (-0.3 if state in ["FIREBALL_STARTUP", "BOW_DRAW"] else 0)
		if opponent_weapon == 3:
			ranged_model.get_node("String").position.z = ranged_draw_fraction() * 0.2
	if bot_charge_orb != null:
		bot_charge_orb.visible = state == "STAFF_CHARGE"
		if ranged_model != null:
			bot_charge_orb.global_position = ranged_model.to_global(Vector3(0, 0.45, -0.2))
		var staff = player.get_node("Staff")
		bot_charge_orb.scale = Vector3.ONE * lerpf(staff.staff_min_radius, staff.staff_max_radius, ranged_staff_fraction()) / 0.4
		bot_charge_orb.material_override.albedo_color = Color("70bfff").lerp(Color("b9efff"), ranged_staff_fraction())
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
	return "AI %s | %s | %s\nRead %.2f s | Decision timer %.2f s | Parry window %s\nDodge %s | Weights B/P/D/G %.1f/%.1f/%.1f/%.1f\nF4 personality | F5 ALL_OUT | F6 sparring/projectiles | F7 ALWAYS_BLOCK | F8 Mirror %s" % [["BALANCED", "TURTLE", "PARRY_HAPPY", "SLIPPERY", "AGGRESSIVE", "CUSTOM", "ALL_OUT"][personality], state, decision, reaction_remaining, decision_remaining, state == "PARRY_WINDOW", dodge_direction, block_weight, parry_weight, dodge_weight, greed_weight, mirror_weapon]
func has_shield_guard() -> bool:
	return opponent_weapon == 0

func is_guard_held() -> bool:
	return has_shield_guard() and not guard_broken() and (state == "BLOCK" or test_guard_mode == 1)

func on_guard_break() -> void:
	reaction_remaining = 0
	decision_remaining = 0
	decision = "GUARD BREAK"
	super.on_guard_break()

func on_guard_recovered() -> void:
	decision = "RECOVERED"
	super.on_guard_recovered()
	if personality == 6:
		cooldown = pressure_attack_interval

func weapon_label() -> String:
	return ["SWORD & SHIELD", "GREATSWORD", "STAFF", "BOW"][opponent_weapon]

func sync_weapon() -> void:
	var desired: int = player.weapon_sets.find(player.weapon_set) if mirror_weapon else opponent_weapon
	queued_weapon = desired
	# Finish commitment/recovery and incapacitation before changing equipment.
	if (state not in ["IDLE", "APPROACH"] and not (state == "BLOCK" and training_mode == 1)) or freeze_remaining > 0 or stagger_remaining > 0 or guard_broken() or health <= 0:
		return
	if desired == applied_weapon:
		return
	opponent_weapon = clampi(desired, 0, 3)
	applied_weapon = opponent_weapon
	melee_step = 0
	if ranged_model != null:
		ranged_model.queue_free()
		ranged_model = null
	if opponent_weapon >= 2:
		ranged_model = preload("res://sandbox/ranged_weapon.gd").build_model(self, opponent_weapon == 3)
		ranged_model.position = Vector3(-0.32 if opponent_weapon == 3 else 0.4, 1, -0.45)
		if bot_charge_orb == null:
			bot_charge_orb = preload("res://sandbox/ranged_weapon.gd").make_charge_orb(self)
	else:
		configure_melee()
	cooldown = pressure_attack_interval if personality == 6 else minf(cooldown, attack_interval)
	update_visuals()

func configure_melee() -> void:
	# Copy the existing Light's real reach, timing and damage, not just its mesh.
	var source = player.weapon_sets[opponent_weapon].chain.attacks[melee_step]
	melee_startup = source.startup_duration
	melee_active = source.active_duration
	melee_recovery = source.recovery_duration
	melee_range = source.reach
	melee_arc = source.arc_degrees
	melee_damage = source.damage
	melee_guard_damage = source.guard_damage
	melee_stagger = source.stagger_duration
	melee_hit_stop = source.hit_stop_duration
	var points := PackedVector3Array()
	for height in [-melee_height / 2.0, melee_height / 2.0]:
		points.append(Vector3(0, height, 0))
		for index in range(13):
			var angle := deg_to_rad(-melee_arc / 2 + melee_arc * index / 12.0)
			points.append(Vector3(sin(angle) * melee_range, height, -cos(angle) * melee_range))
	melee_shape.points = points
	if melee_debug != null:
		melee_debug.mesh = melee_shape.get_debug_mesh()

func begin_weapon_attack() -> void:
	if opponent_weapon >= 2:
		var source = player.weapon_sets[opponent_weapon]
		fireball_startup = source.startup_duration
		fireball_recovery = source.recovery_duration
		begin_fireball()
		if opponent_weapon == 2:
			state = "STAFF_CHARGE"
			staff_hold_duration = choose_staff_hold(source)
			if source.auto_release_time > 0:
				staff_hold_duration = minf(staff_hold_duration, source.auto_release_time)
		elif opponent_weapon == 3:
			state = "BOW_DRAW"
			bow_hold_duration = source.draw_duration + rng.randf_range(0, bow_extra_hold) if rng.randf() < held_bow_chance else source.startup_duration
	else:
		begin_melee()

func begin_melee() -> void:
	if guard_broken():
		return
	if applied_weapon >= 0 and opponent_weapon < 2:
		configure_melee()
		melee_step = (melee_step + 1) % 3
	super.begin_melee()

func fire_projectile():
	if opponent_weapon < 2:
		return super.fire_projectile()
	var source = player.weapon_sets[opponent_weapon]
	var shot = preload("res://sandbox/ranged_projectile.gd").new()
	shot.attacker = self
	shot.arrow = opponent_weapon == 3
	shot.speed = source.projectile_speed * (lerpf(1, source.full_draw_speed_multiplier, ranged_draw_fraction()) if opponent_weapon == 3 else 1)
	shot.radius = source.projectile_radius
	shot.lifetime = source.projectile_lifetime
	shot.impact.damage = source.damage * (lerpf(1, source.full_draw_damage_multiplier, ranged_draw_fraction()) if opponent_weapon == 3 else 1)
	shot.impact.guard_damage = source.guard_damage
	shot.impact.blockable = true
	shot.impact.reflectable = opponent_weapon == 2
	shot.impact.feedback_kind = "arrow" if shot.arrow else "magic"
	if opponent_weapon == 2:
		source.apply_staff_charge(shot, ranged_staff_fraction())
	get_parent().add_child(shot)
	shot.global_position = ranged_model.to_global(Vector3(0, 0.45, -0.2)) if opponent_weapon == 2 and ranged_model != null else global_transform * Transform3D(Basis.IDENTITY, Vector3(-0.32, 1.25, -0.85)).origin
	# Spawn height never supplies aim: release follows the current character heading.
	shot.direction = -global_basis.z

	Feedback.sound(self, "light_swing" if shot.arrow else "cast")
	return shot

func ranged_motion(offset: Vector3, delta: float) -> Vector3:
	var minimum: float = staff_min_range if opponent_weapon == 2 else bow_min_range
	var maximum: float = staff_max_range if opponent_weapon == 2 else bow_max_range
	var distance := offset.length()
	var toward := offset.normalized()
	strafe_elapsed += delta
	var side := toward.cross(Vector3.UP) * (1 if fmod(strafe_elapsed, 4) < 2 else -1)
	var motion := side * ranged_strafe_speed
	if distance < minimum:
		motion -= toward * ranged_move_speed
	elif distance > maximum:
		motion += toward * (pressure_move_speed if personality == 6 else ranged_move_speed)
	# Bias back into the arena instead of fleeing indefinitely.
	if absf(global_position.x) > arena_limit:
		motion.x = -signf(global_position.x) * ranged_move_speed
	if absf(global_position.z) > arena_limit:
		motion.z = -signf(global_position.z) * ranged_move_speed
	return motion

func ranged_pressure(offset: Vector3, delta: float) -> void:
	var maximum: float = staff_max_range if opponent_weapon == 2 else bow_max_range
	var toward := offset.normalized()
	var motion := ranged_motion(offset, delta)
	state = "APPROACH"
	velocity.x = motion.x
	velocity.z = motion.z
	if offset.length() <= maximum + 2 and cooldown <= 0 and (-global_basis.z).dot(toward) >= 0.995:
		var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, player.global_position + Vector3.UP, 1)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			decision = "RANGED PRESSURE"
			begin_weapon_attack()

func ranged_draw_fraction() -> float:
	var source = player.get_node("Bow")
	return clampf((minf(elapsed, bow_hold_duration) - source.startup_duration) / maxf(source.draw_duration - source.startup_duration, 0.001), 0, 1) if state == "BOW_DRAW" else 0

func tick_ranged_attack(delta: float) -> void:
	var source = player.weapon_sets[opponent_weapon]
	flash_remaining = maxf(0, flash_remaining - delta)
	visual.position = visual.position.move_toward(Vector3(0, 0.9, 0), recoil_return_speed * delta)
	var aiming: bool = state in ["STAFF_CHARGE", "BOW_DRAW"]
	if aiming:
		var offset: Vector3 = player.global_position - global_position
		rotation.y = rotate_toward(rotation.y, atan2(-offset.x, -offset.z), deg_to_rad(turning_speed_degrees) * delta)
	else:
		rotation.y = attack_yaw
	elapsed += delta
	if (state == "STAFF_CHARGE" and elapsed >= staff_hold_duration) or (state == "BOW_DRAW" and elapsed >= bow_hold_duration) or (state == "FIREBALL_STARTUP" and elapsed >= fireball_startup):
		fire_projectile()
		attack_yaw = rotation.y
		elapsed = 0
		state = "FIREBALL_RECOVERY"
	elif state == "FIREBALL_RECOVERY" and elapsed >= fireball_recovery:
		state = "IDLE"
		elapsed = 0
		cooldown = pressure_attack_interval if personality == 6 else attack_interval
	var offset: Vector3 = player.global_position - global_position
	offset.y = 0
	var motion := ranged_motion(offset, delta)
	var multiplier: float = source.staff_charge_move_multiplier if state == "STAFF_CHARGE" else (source.draw_movement_multiplier if state == "BOW_DRAW" else source.movement_multiplier)
	motion = motion.limit_length(player.move_speed * multiplier)
	velocity.x = motion.x
	velocity.z = motion.z
	velocity.y -= 22.4 * delta
	move_and_slide()
	update_visuals()

func ranged_staff_fraction() -> float:
	var staff = player.get_node("Staff")
	return staff.staff_fraction(minf(elapsed, staff_hold_duration), staff.max_charge_time) if state == "STAFF_CHARGE" else 0

func choose_staff_hold(staff) -> float:
	var weights := [maxf(0, staff_charge_weights.x), maxf(0, staff_charge_weights.y), maxf(0, staff_charge_weights.z), maxf(0, staff_charge_weights.w)]
	var total: float = weights[0] + weights[1] + weights[2] + weights[3]
	if total <= 0:
		return rng.randf_range(0.04, 0.16)
	var roll := rng.randf() * total
	var choice: int = 0
	for i in range(4):
		roll -= weights[i]
		choice = i
		if roll < 0:
			break
	# Duration is selected before charging, never optimized from player input.
	if choice == 0:
		return rng.randf_range(0.04, 0.16)
	if choice == 1:
		return staff.max_charge_time * rng.randf_range(0.2, 0.4)
	if choice == 2:
		return staff.max_charge_time * rng.randf_range(0.45, 0.7)
	return staff.max_charge_time + rng.randf_range(0, staff_full_charge_extra_hold)
