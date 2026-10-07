extends Node3D
# Presentation only: combat state and collision remain owned by the actor.
var actor
var torso: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var material := StandardMaterial3D.new()
var walk_phase: float = 0.0
var pose: String = "IDLE"

func part(parent: Node3D, size: Vector3, offset: Vector3) -> void:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = material
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

func _process(delta: float) -> void:
	var is_player: bool = actor.has_method("movement_state")
	var frozen: bool = actor.weapon_set.freeze_remaining > 0 if is_player else actor.freeze_remaining > 0
	if frozen:
		return
	pose = "IDLE"
	var swing = null
	if is_player:
		var weapon = actor.weapon_set
		if actor.health <= 0:
			pose = "DEAD"
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
		material.albedo_color = Color("408fc4")
	else:
		pose = actor.state
		material.albedo_color = actor.material.albedo_color
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
	if pose in ["STAGGER", "DEAD"]:
		torso.rotation.x = 0.55 if pose == "STAGGER" else 1.2
		left_arm.rotation.z = 0.8
		right_arm.rotation.z = -0.8
	elif pose == "DODGE":
		torso.rotation.x = -0.5
		left_arm.rotation.x = 0.9
		right_arm.rotation.x = 0.9
		left_leg.rotation.x = -0.7
	elif pose in ["BLOCK", "PERFECT BLOCK", "RAISING"]:
		left_arm.rotation.x = -1.4
		right_arm.rotation.x = -0.65
	elif pose in ["PARRY_STARTUP", "PARRY_ATTEMPT", "PARRY_WINDOW"]:
		left_arm.rotation.x = -1.7
		right_arm.rotation.x = -1.7
		right_arm.rotation.z = -0.5
		if pose == "PARRY_WINDOW":
			material.albedo_color = Color.CYAN
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
	elif pose.begins_with("MELEE"):
		right_arm.rotation.x = -2.0 if pose == "MELEE_STARTUP" else -0.7
		torso.rotation.y = -0.5 if pose == "MELEE_STARTUP" else 0.5
	elif pose.begins_with("FIREBALL"):
		left_arm.rotation.x = -1.5
		right_arm.rotation.x = -1.5
