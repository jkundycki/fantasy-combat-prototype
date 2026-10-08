extends Node3D
# Presentation only: combat state and collision remain owned by the actor.
@export_range(0.01, 0.4) var roll_tuck_fraction: float = 0.15
@export_range(0.01, 0.4) var roll_recovery_fraction: float = 0.15
@export var roll_crouch_depth: float = 0.35
@export_range(1.0, 2.5) var roll_visual_duration_multiplier: float = 1.25
var roll_elapsed: float = 0
var roll_duration: float = 0
var roll_playing: bool = false
var roll_direction := Vector3.FORWARD
var roll_root: Node3D
var actor
var torso: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var material := StandardMaterial3D.new()
var walk_phase: float = 0.0
var pose: String = "IDLE"
var last_health: float = 100
var flash_remaining: float = 0

func part(parent: Node3D, size: Vector3, offset: Vector3, surface: Material = null) -> void:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = surface if surface != null else material
	instance.position = offset
	parent.add_child(instance)

func limb(offset: Vector3, size: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = offset
	add_child(pivot)
	part(pivot, size, Vector3(0, -size.y / 2, 0))
	return pivot

func _ready() -> void:
	actor = get_parent().get_parent()
	last_health = actor.health
	actor.health_changed.connect(health_feedback)
	material.roughness = 0.85
	var armor := StandardMaterial3D.new()
	armor.albedo_color = Color("a0b5b8") if actor.has_method("movement_state") else Color("716452")
	armor.metallic = 0.55
	armor.roughness = 0.5
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color("352c26")
	leather.roughness = 0.9
	torso = Node3D.new()
	torso.position.y = 1.05
	add_child(torso)
	part(torso, Vector3(0.55, 0.65, 0.32), Vector3(0, 0.15, 0))
	part(torso, Vector3(0.32, 0.32, 0.32), Vector3(0, 0.65, 0))
	part(torso, Vector3(0.12, 0.1, 0.12), Vector3(0, 0.65, -0.2))
	left_arm = limb(Vector3(-0.38, 1.4, 0), Vector3(0.18, 0.65, 0.2))
	right_arm = limb(Vector3(0.38, 1.4, 0), Vector3(0.18, 0.65, 0.2))
	left_leg = limb(Vector3(-0.16, 0.75, 0), Vector3(0.22, 0.75, 0.25))
	right_leg = limb(Vector3(0.16, 0.75, 0), Vector3(0.22, 0.75, 0.25))
	part(torso, Vector3(0.48, 0.37, 0.07), Vector3(0, 0.22, -0.19), armor)
	part(torso, Vector3(0.57, 0.09, 0.35), Vector3(0, -0.13, 0), leather)
	part(torso, Vector3(0.37, 0.25, 0.37), Vector3(0, 0.75, 0), armor)
	part(torso, Vector3(0.22, 0.035, 0.02), Vector3(0, 0.7, -0.20), leather)
	part(left_arm, Vector3(0.29, 0.18, 0.3), Vector3(0, -0.05, 0), armor)
	part(right_arm, Vector3(0.26, 0.16, 0.28), Vector3(0, -0.05, 0), armor)
	part(left_leg, Vector3(0.24, 0.22, 0.34), Vector3(0, -0.64, -0.04), leather)
	part(right_leg, Vector3(0.24, 0.22, 0.34), Vector3(0, -0.64, -0.04), leather)

	# Rotate the model around its center, never the CharacterBody/camera/collider.
	roll_root = Node3D.new()
	roll_root.name = "RollVisual"
	roll_root.position.y = 0.9
	var pieces := get_children()
	add_child(roll_root)
	for piece in pieces:
		piece.reparent(roll_root, true)

func _process(delta: float) -> void:
	var is_player: bool = actor.has_method("movement_state")
	var frozen: bool = actor.weapon_set.freeze_remaining > 0 if is_player else actor.freeze_remaining > 0
	if frozen and not actor.guard_broken():
		if flash_remaining > 0:
			material.albedo_color = Color.WHITE
		return
	pose = "IDLE"
	var swing = null
	if is_player:
		var weapon = actor.weapon_set
		if actor.health <= 0:
			pose = "DEAD"
		elif actor.guard_broken():
			pose = "GUARD_BREAK"
		elif actor.stagger_remaining > 0:
			pose = "STAGGER"
		elif actor.dodge_remaining > 0:
			pose = "DODGE"
		elif weapon.active_swing().busy():
			swing = weapon.active_swing()
			pose = swing.state
		elif weapon.has_method("shield_state"):
			pose = weapon.shield_state()
		else:
			pose = weapon.parry_state
		material.albedo_color = Color("376b7b")
	else:
		pose = actor.state
		material.albedo_color = actor.material.albedo_color
	# Mechanical progress drives the visual; only a short upright tail may outlast it.
	if pose == "DODGE":
		var remaining: float = actor.dodge_remaining if is_player else actor.decision_remaining
		roll_elapsed = maxf(0, actor.dodge_duration - remaining)
		roll_duration = actor.dodge_duration * maxf(1, roll_visual_duration_multiplier)
		roll_direction = actor.dodge_direction
		roll_playing = true
	elif roll_playing:
		roll_elapsed += delta
		if roll_elapsed >= roll_duration or not (pose in ["IDLE", "DOWN"] or (not is_player and pose == "RECOVERY")):
			roll_playing = false
		else:
			pose = "DODGE"
	flash_remaining = maxf(0, flash_remaining - delta)
	if flash_remaining > 0:
		material.albedo_color = material.albedo_color.lerp(Color.WHITE, 0.8)
	roll_root.rotation = Vector3.ZERO
	roll_root.position.y = 0.9
	roll_root.scale = Vector3.ONE
	if is_player:
		actor.weapon_set.visible = pose != "DODGE"
	torso.rotation = Vector3.ZERO
	left_arm.rotation = Vector3.ZERO
	right_arm.rotation = Vector3.ZERO
	left_leg.rotation = Vector3.ZERO
	right_leg.rotation = Vector3.ZERO
	var speed: float = Vector2(actor.velocity.x, actor.velocity.z).length()
	if speed > 0.2:
		walk_phase += delta * minf(speed * 2, 16)
		left_leg.rotation.x = sin(walk_phase) * 0.45
		right_leg.rotation.x = -left_leg.rotation.x
		left_arm.rotation.x = -left_leg.rotation.x * 0.5
		right_arm.rotation.x = left_leg.rotation.x * 0.5
	if pose == "GUARD_BREAK":
		torso.rotation.x = 0.85
		left_arm.rotation.x = 0.6
		right_arm.rotation.x = 0.6
		left_leg.rotation.x = -0.25
		material.albedo_color = Color("e87bda")
	elif pose in ["STAGGER", "DEAD"]:
		torso.rotation.x = 0.65 if pose == "STAGGER" else 1.2
		left_arm.rotation.z = 0.8
		right_arm.rotation.z = -0.8
	elif pose == "DODGE":
		var progress := clampf(roll_elapsed / maxf(roll_duration, 0.001), 0, 1)
		var direction: Vector3 = roll_direction
		var yaw := atan2(-direction.x, -direction.z)
		roll_root.rotation.y = angle_difference(actor.visual.global_rotation.y if is_player else actor.global_rotation.y, yaw)
		# Gentle easing across the FULL window, not a short central burst.
		roll_root.rotation.x = -TAU * roll_turn_fraction(progress)
		var tuck := minf(smoothstep(0, maxf(roll_tuck_fraction, 0.01), progress), 1 - smoothstep(1 - roll_recovery_fraction, 1, progress))
		roll_root.position.y -= roll_crouch_depth * tuck
		roll_root.scale.y = 1 - 0.25 * tuck
		left_arm.rotation.x = -1.6
		right_arm.rotation.x = -1.6
		left_leg.rotation.x = -1.1 * tuck
		right_leg.rotation.x = -1.1 * tuck
	elif pose in ["BLOCK", "PERFECT BLOCK", "RAISING"]:
		left_arm.rotation.x = -1.6
		right_arm.rotation.x = -0.65
	elif pose in ["PARRY_STARTUP", "PARRY_ATTEMPT", "PARRY_WINDOW"]:
		left_arm.rotation.x = -1.7
		right_arm.rotation.x = -1.7
		right_arm.rotation.z = -0.5
		if pose == "PARRY_WINDOW":
			material.albedo_color = Color.CYAN
	elif (is_player and actor.weapon_set.has_method("fire")) or (not is_player and actor.get("opponent_weapon") != null and actor.opponent_weapon >= 2):
		var bow: bool = actor.weapon_set.kind == 1 if is_player else actor.opponent_weapon == 3
		var shooting: bool = swing != null if is_player else pose in ["FIREBALL_STARTUP", "FIREBALL_RECOVERY", "STAFF_CHARGE", "BOW_DRAW"]
		var fraction: float = actor.weapon_set.draw_fraction() if is_player and bow else (actor.ranged_draw_fraction() if not is_player and bow else 0)
		var charging: bool = actor.weapon_set.charging() if is_player else pose == "STAFF_CHARGE"
		left_arm.rotation.x = -1.5 if bow else -0.5
		right_arm.rotation.x = -1.4 if shooting else -0.6
		right_arm.rotation.z = lerpf(-0.2, -1.1, fraction) if bow and shooting else 0
		right_arm.rotation.y = fraction * 0.65 if bow else 0
		if charging:
			left_arm.rotation.x = -1.8
			right_arm.rotation.x = -2.1
			torso.rotation.x = -0.15
		elif not bow and shooting:
			var recovery: float = actor.weapon_set.elapsed / maxf(actor.weapon_set.recovery_duration, 0.001) if is_player else actor.elapsed / maxf(actor.fireball_recovery, 0.001)
			right_arm.rotation.x = lerpf(-1.65, -0.6, clampf(recovery, 0, 1))
		torso.rotation.y = 0.25 if bow and shooting else 0
	elif swing != null:
		var overhead: bool = swing.name == "Heavy"
		if swing.shield_bash:
			left_arm.rotation.x = -1.6 if swing.state == swing.ACTIVE else -0.9
			torso.rotation.x = -0.2
		elif overhead:
			var angle: float = -2.7
			if swing.state == swing.ACTIVE:
				angle = lerpf(-2.7, -0.5, clampf(swing.elapsed / swing.active_duration, 0, 1))
			elif swing.state == swing.RECOVERY:
				angle = lerpf(-0.5, 0, clampf(swing.elapsed / maxf(swing.recovery_duration, 0.001), 0, 1))
			left_arm.rotation.x = angle
			right_arm.rotation.x = angle
		else:
			var direction: float = -1 if swing.reverse_swing else 1
			var twist: float = -0.65
			if swing.state == swing.ACTIVE:
				twist = lerpf(-0.65, 0.65, clampf(swing.elapsed / swing.active_duration, 0, 1))
			elif swing.state == swing.RECOVERY:
				twist = lerpf(0.65, 0, clampf(swing.elapsed / maxf(swing.recovery_duration, 0.001), 0, 1))
			torso.rotation.y = twist * direction
			right_arm.rotation.x = -1.1
			right_arm.rotation.z = twist * direction
			if is_player and actor.weapon_set.name == "Greatsword":
				left_arm.rotation.x = -1.05
				left_arm.rotation.z = 0.35
	elif pose.begins_with("MELEE"):
		right_arm.rotation.x = -2.0 if pose == "MELEE_STARTUP" else -0.7
		torso.rotation.y = -0.5 if pose == "MELEE_STARTUP" else 0.5
	elif pose.begins_with("FIREBALL"):
		left_arm.rotation.x = -1.5
		right_arm.rotation.x = -1.5

func health_feedback() -> void:
	if actor.health < last_health:
		flash_remaining = 0.2
	last_health = actor.health

static func roll_turn_fraction(progress: float) -> float:
	var p := clampf(progress, 0, 1)
	return p - 0.04 * sin(TAU * p)
