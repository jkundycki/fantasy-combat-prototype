extends CharacterBody3D

signal health_changed
const Feedback = preload("res://sandbox/combat_feedback.gd")
const DamageNumber = preload("res://sandbox/damage_number.gd")

@export_group("Ground movement")
@export_range(0.0, 50.0) var move_speed: float = 7.2
@export_range(0.0, 1000.0) var ground_acceleration: float = 144.0
@export_range(0.0, 1000.0) var ground_deceleration: float = 176.0
@export_range(0.0, 1000.0) var ground_turn_acceleration: float = 288.0
@export_group("Air movement")
@export_range(0.0, 200.0) var air_acceleration: float = 4.8
@export_range(0.0, 200.0) var air_deceleration: float = 0.0
@export_group("Jump")
@export var jump_speed: float = 8.0
@export var gravity: float = 22.4
@export var falling_gravity_multiplier: float = 1.35
@export_range(0.1, 1.0) var jump_release_multiplier: float = 0.5
@export_range(0.0, 0.3) var coyote_time: float = 0.08
@export_range(0.0, 0.3) var jump_buffer_time: float = 0.1
@export_group("Ground dodge")
@export var dodge_speed: float = 9.0
@export var dodge_duration: float = 0.432
@export var dodge_cooldown: float = 5.0
@export var dodge_recovery_time: float = 0.0
@export_group("Roll presentation")
@export_range(0.01, 0.4) var roll_tuck_fraction: float = 0.15
@export_range(0.01, 0.4) var roll_recovery_fraction: float = 0.15
@export var roll_crouch_depth: float = 0.35
@export_range(1.0, 2.5) var roll_visual_duration_multiplier: float = 1.25
@export_group("Test health")
@export var max_health: float = 100.0
@export var reset_delay: float = 1.0

@onready var camera_rig: Node3D = $CameraRig
@onready var visual: Node3D = $Visual
@onready var weapon_set = $SwordShield
@onready var weapon_sets: Array[Node3D] = [$SwordShield, $Greatsword, $Staff, $Bow]
var coyote_remaining: float = 0.0
var jump_buffer_remaining: float = 0.0
var jump_pressed: bool = false
var jump_cut_pending: bool = false
var dodge_pressed: bool = false
var dodge_remaining: float = 0.0
var cooldown_remaining: float = 0.0
var recovery_remaining: float = 0.0
var dodge_direction := Vector3.FORWARD
var air_reference_yaw: float = 0.0
var stagger_remaining: float = 0.0
var health: float = 100.0:
	set(value):
		health = clampf(value, 0, max_health)
		health_changed.emit()
var reset_remaining: float = 0.0

func _ready() -> void:
	health = max_health
	$Greatsword.visible = false
	$Visual/Body.hide()
	$Visual/Facing.hide()
	var humanoid = preload("res://sandbox/humanoid.gd").new()
	humanoid.name = "Humanoid"
	humanoid.roll_tuck_fraction = roll_tuck_fraction
	humanoid.roll_recovery_fraction = roll_recovery_fraction
	humanoid.roll_crouch_depth = roll_crouch_depth
	humanoid.roll_visual_duration_multiplier = roll_visual_duration_multiplier
	visual.add_child(humanoid)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if stagger_remaining > 0 or guard_broken():
		if event.is_action_released("defense"):
			weapon_set.defense(false)
		return
	if weapon_set.has_method("cancel_draw") and (event.is_action_pressed("jump") or event.is_action_pressed("mobility")):
		weapon_set.cancel_draw()
	if event.is_action_pressed("jump"):
		jump_pressed = true
		jump_buffer_remaining = jump_buffer_time
		jump_cut_pending = false
	elif event.is_action_released("jump"):
		jump_cut_pending = true
	if event.is_action_pressed("weapon_switch"):
		switch_weapon()
	if event.is_action_pressed("mobility"):
		dodge_pressed = true
	if event.is_action_released("defense"):
		weapon_set.defense(false)
	if event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if stagger_remaining > 0 or guard_broken():
		return
	if event.is_action_pressed("primary"):
		weapon_set.primary_pressed() if weapon_set.has_method("primary_pressed") else weapon_set.primary()
	elif event.is_action_released("primary") and weapon_set.has_method("primary_released"):
		weapon_set.primary_released()
	elif event.is_action_pressed("heavy"):
		weapon_set.heavy_attack()
	elif event.is_action_pressed("cancel_feint"):
		weapon_set.hard_feint()
	elif event.is_action_pressed("special"):
		weapon_set.special()
	if event.is_action_pressed("defense"):
		weapon_set.defense(true)
	elif event.is_action_released("defense"):
		weapon_set.defense(false)

func movement_direction() -> Vector3:
	var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw: float = camera_rig.global_rotation.y if is_on_floor() else air_reference_yaw
	return Basis(Vector3.UP, yaw) * Vector3(axis.x, 0, axis.y)

func facing_yaw() -> float:
	# RMB facing, airborne facing and guarded facing share the existing camera yaw.
	if not is_on_floor() or Input.is_action_pressed("camera_facing") or weapon_set.defense_held:
		return camera_rig.global_rotation.y
	var direction := movement_direction()
	return atan2(-direction.x, -direction.z) if not direction.is_zero_approx() else visual.global_rotation.y

func start_dodge(direction: Vector3) -> void:
	if guard_broken():
		return
	dodge_direction = direction.normalized() if not direction.is_zero_approx() else -visual.global_basis.z
	dodge_direction.y = 0.0
	dodge_direction = dodge_direction.normalized()
	dodge_remaining = dodge_duration
	cooldown_remaining = dodge_cooldown
	coyote_remaining = 0.0
	weapon_set.reset_combo()
	weapon_set.lower_shield()
	visual.rotation.y = atan2(-dodge_direction.x, -dodge_direction.z)

func finish_dodge() -> void:
	dodge_remaining = 0.0
	recovery_remaining = dodge_recovery_time

func update_horizontal(direction: Vector3, grounded: bool, delta: float) -> void:
	# Attack restrictions affect ground speed, not retained launch momentum.
	var speed: float = move_speed * (weapon_set.movement_scale() if grounded else 1.0)
	var horizontal := Vector2(velocity.x, velocity.z)
	var target: Vector2 = Vector2(direction.x, direction.z) * speed
	var acceleration := ground_acceleration if grounded else air_acceleration
	if direction.is_zero_approx():
		acceleration = ground_deceleration if grounded else air_deceleration
	elif grounded and not horizontal.is_zero_approx() and horizontal.normalized().dot(target.normalized()) < 0.5:
		acceleration = ground_turn_acceleration
	horizontal = horizontal.move_toward(target, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	if not weapon_set.busy() or weapon_set.feint_recovery_remaining > 0:
		visual.global_rotation.y = facing_yaw()

func _physics_process(delta: float) -> void:
	if health <= 0.0:
		reset_remaining -= delta
		if reset_remaining <= 0.0:
			health = max_health
			$SwordShield/Guard.reset()
			global_position = Vector3(0, 2, 3)
			velocity = Vector3.ZERO
		return
	if guard_broken():
		cooldown_remaining = maxf(0, cooldown_remaining - delta)
		recovery_remaining = maxf(0, recovery_remaining - delta)
		velocity.x = 0
		velocity.z = 0
		weapon_set.tick(delta)
		velocity.y -= gravity * delta
		move_and_slide()
		return
	if stagger_remaining > 0:
		stagger_remaining = maxf(0, stagger_remaining - delta)
		weapon_set.tick(delta)
		velocity.y -= gravity * delta
		move_and_slide()
		return
	var grounded := is_on_floor()
	if grounded:
		air_reference_yaw = camera_rig.global_rotation.y
	if not weapon_set.busy() and dodge_remaining <= 0.0:
		visual.global_rotation.y = facing_yaw()
	weapon_set.tick(delta)
	if weapon_set.hold_movement_this_tick:
		return
	var direction := movement_direction()
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	recovery_remaining = maxf(0.0, recovery_remaining - delta)
	coyote_remaining = coyote_time if grounded and dodge_remaining <= 0.0 else maxf(0.0, coyote_remaining - delta)
	var can_jump := grounded or coyote_remaining > 0.0
	var wants_jump := jump_pressed or jump_buffer_remaining > 0.0
	if dodge_pressed and not weapon_set.busy() and not (wants_jump and can_jump) and grounded and dodge_remaining <= 0.0 and recovery_remaining <= 0.0 and cooldown_remaining <= 0.0 and dodge_duration > 0.0:
		start_dodge(direction)
	dodge_pressed = false
	if dodge_remaining > 0.0 and not grounded:
		finish_dodge()
	if dodge_remaining > 0.0:
		velocity.x = dodge_direction.x * dodge_speed
		velocity.z = dodge_direction.z * dodge_speed
		dodge_remaining = maxf(0.0, dodge_remaining - delta)
		if dodge_remaining <= 0.0:
			finish_dodge()
	else:
		update_horizontal(direction, grounded, delta)
	if not grounded:
		velocity.y -= gravity * (falling_gravity_multiplier if velocity.y < 0.0 else 1.0) * delta
	if wants_jump and can_jump and dodge_remaining <= 0.0:
		air_reference_yaw = camera_rig.global_rotation.y
		velocity.y = jump_speed
		jump_buffer_remaining = 0.0
		coyote_remaining = 0.0
	if jump_cut_pending and velocity.y > 0.0:
		velocity.y *= jump_release_multiplier
		jump_cut_pending = false
	jump_pressed = false
	jump_buffer_remaining = maxf(0.0, jump_buffer_remaining - delta)
	move_and_slide()
	if global_position.y < -15.0:
		global_position = Vector3(0, 2, 3)
		velocity = Vector3.ZERO
		coyote_remaining = 0.0
		jump_buffer_remaining = 0.0
		dodge_remaining = 0.0
		cooldown_remaining = 0.0
		recovery_remaining = 0.0

func receive_attack(impact: Resource, origin: Vector3, attacker: Node) -> String:
	if health <= 0.0:
		return "DEAD"
	var health_before := health
	var result: String = weapon_set.defend(impact, origin, attacker)
	if result == "HIT" or result == "BLOCK":
		health = maxf(0.0, health - maxf(0, impact.damage) * (weapon_set.blocked_damage_multiplier if result == "BLOCK" else 1.0))
		if result == "HIT":
			weapon_set.feedback("HIT TAKEN")
			if impact.stagger_duration > 0:
				stagger(impact.stagger_duration, impact.hit_stop)
	DamageNumber.show_damage(self, health_before - health)
	if health_before > health:
		Feedback.impact(self, impact.feedback_kind)
	if health <= 0.0:
		reset_remaining = reset_delay
		weapon_set.reset_combat()
		dodge_remaining = 0.0
		jump_pressed = false
		jump_buffer_remaining = 0.0
	return result

func movement_state() -> String:
	if not is_on_floor():
		return "AIRBORNE"
	return "DODGE" if dodge_remaining > 0.0 else "NORMAL"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(weapon_set):
		weapon_set.defense(false)
		if weapon_set.has_method("cancel_primary"):
			weapon_set.cancel_primary()
func switch_weapon() -> bool:
	if guard_broken() or stagger_remaining > 0 or health <= 0 or weapon_set.busy() or weapon_set.defense_held or weapon_set.recovery_remaining > 0 or weapon_set.freeze_remaining > 0 or dodge_remaining > 0 or recovery_remaining > 0:
		return false
	var enabled: bool = weapon_set.debug_enabled
	weapon_set.reset_combat()
	weapon_set.visible = false
	weapon_set = weapon_sets[(weapon_sets.find(weapon_set) + 1) % weapon_sets.size()]
	weapon_set.reset_combat()
	weapon_set.debug_enabled = enabled
	weapon_set.visible = true
	weapon_set.update_visuals()
	return true
func stagger(duration: float, hit_stop: float = 0.0) -> void:
	if guard_broken():
		return # HP hits cannot refresh the Guard Break timer.
	stagger_remaining = maxf(stagger_remaining, duration)
	weapon_set.reset_combat()
	weapon_set.freeze(hit_stop)
	weapon_set.feedback("STAGGERED / INTERRUPTED")
	dodge_remaining = 0
	dodge_pressed = false
	jump_pressed = false
	jump_buffer_remaining = 0
func guard_broken() -> bool:
	return $SwordShield/Guard.is_broken()

func is_guard_held() -> bool:
	return weapon_set == $SwordShield and weapon_set.defense_held

func on_guard_break() -> void:
	Feedback.impact(self, "guard_break")
	for weapon in weapon_sets:
		weapon.reset_combat()
	stagger_remaining = 0
	velocity.x = 0
	velocity.z = 0
	dodge_remaining = 0
	dodge_pressed = false
	jump_pressed = false
	jump_buffer_remaining = 0
	coyote_remaining = 0
	jump_cut_pending = false
	weapon_set.feedback("GUARD BREAK")
	weapon_set.update_visuals()

func on_guard_recovered() -> void:
	weapon_set.feedback("GUARD RECOVERED")
