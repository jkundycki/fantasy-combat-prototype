extends CharacterBody3D

const Impact = preload("res://sandbox/incoming_attack.gd")
const Projectile = preload("res://sandbox/fireball.gd")
@export var ai_enabled: bool = true
@export_enum("OFF", "BLOCK", "PARRY") var test_guard_mode: int = 0
@export var max_health: float = 100.0
@export var move_speed: float = 1.5
@export var attack_interval: float = 1.4
@export_group("Melee")
@export var melee_startup: float = 0.8
@export var melee_active: float = 0.16
@export var melee_recovery: float = 1.0
@export var melee_range: float = 2.1
@export var melee_arc: float = 90.0
@export var melee_damage: float = 14.0
@export var melee_height: float = 2.8
@export_group("Fireball")
@export var fireball_startup: float = 0.9
@export var fireball_recovery: float = 1.1
@export var projectile_speed: float = 5.0
@export var projectile_damage: float = 12.0
@export var projectile_blockable: bool = true
@export var projectile_reflectable: bool = true
@export_group("Feedback and reset")
@export var flash_duration: float = 0.09
@export var hit_recoil_distance: float = 0.1
@export var stagger_recoil_distance: float = 0.3
@export var recoil_return_speed: float = 1.5
@export var reset_delay: float = 1.0

var health: float = 100.0
var state: String = "IDLE"
var elapsed: float = 0.0
var cooldown: float = 1.4
var stagger_remaining: float = 0.0
var freeze_remaining: float = 0.0
var flash_remaining: float = 0.0
var reset_remaining: float = 0.0
var attack_yaw: float = 0.0
var aim_point := Vector3.ZERO
var hit_player: bool = false
var debug_enabled: bool = true
var spawn_position := Vector3.ZERO
var melee_shape := ConvexPolygonShape3D.new()
var melee_debug: MeshInstance3D
var visual: MeshInstance3D
var material: StandardMaterial3D
var weapon: MeshInstance3D
@onready var player = get_node("../Player")

func _ready() -> void:
	health = max_health
	spawn_position = global_position
	collision_layer = 8
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	var collider := CollisionShape3D.new()
	collider.position.y = 0.9
	collider.shape = shape
	add_child(collider)
	var hurtbox := Area3D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	hurtbox.set_script(preload("res://sandbox/enemy_hurtbox.gd"))
	var hurt_shape := CollisionShape3D.new()
	hurt_shape.position.y = 0.0
	hurt_shape.shape = shape
	hurtbox.position.y = 0.9
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)
	visual = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.8
	material = StandardMaterial3D.new()
	mesh.material = material
	visual.mesh = null
	visual.position.y = 0.9
	add_child(visual)
	var humanoid = preload("res://sandbox/humanoid.gd").new()
	humanoid.name = "Humanoid"
	humanoid.position.y = -0.9
	visual.add_child(humanoid)
	weapon = MeshInstance3D.new()
	var blade := BoxMesh.new()
	blade.size = Vector3(0.15, 0.1, 1.4)
	weapon.mesh = blade
	weapon.position = Vector3(0.4, 1, -0.7)
	add_child(weapon)
	var points := PackedVector3Array()
	for height in [-melee_height / 2.0, melee_height / 2.0]:
		points.append(Vector3(0, height, 0))
		for index in range(13):
			var angle := deg_to_rad(-melee_arc / 2 + melee_arc * index / 12.0)
			points.append(Vector3(sin(angle) * melee_range, height, -cos(angle) * melee_range))
	melee_shape.points = points
	melee_debug = MeshInstance3D.new()
	melee_debug.mesh = melee_shape.get_debug_mesh()
	melee_debug.position.y = melee_height / 2.0
	add_child(melee_debug)
	update_visuals()

func begin_melee() -> void:
	state = "MELEE_STARTUP"
	elapsed = 0.0
	attack_yaw = rotation.y
	hit_player = false

func begin_fireball() -> void:
	state = "FIREBALL_STARTUP"
	elapsed = 0.0
	attack_yaw = rotation.y
	aim_point = player.global_position + Vector3(0, 1, 0)

func _physics_process(delta: float) -> void:
	if health <= 0.0:
		reset_remaining -= delta
		if reset_remaining <= 0.0:
			health = max_health
			stagger_remaining = 0.0
			freeze_remaining = 0.0
			visual.position = Vector3(0, 0.9, 0)
			global_position = spawn_position
			state = "IDLE"
			cooldown = attack_interval
		update_visuals()
		return
	flash_remaining = maxf(0, flash_remaining - delta)
	if freeze_remaining > 0.0:
		freeze_remaining = maxf(0, freeze_remaining - delta)
		update_visuals()
		return
	visual.position = visual.position.move_toward(Vector3(0, 0.9, 0), recoil_return_speed * delta)
	if stagger_remaining > 0.0:
		stagger_remaining = maxf(0, stagger_remaining - delta)
		if stagger_remaining <= 0.0:
			state = "IDLE"
			cooldown = attack_interval
	elif state == "IDLE":
		if ai_enabled and player.health > 0.0:
			var direction: Vector3 = player.global_position - global_position
			direction.y = 0.0
			rotation.y = atan2(-direction.x, -direction.z)
			cooldown -= delta
			if cooldown <= 0.0:
				if direction.length() <= melee_range + 0.2:
					begin_melee()
				else:
					begin_fireball()
			elif direction.length() > 1.8:
				velocity.x = direction.normalized().x * move_speed
				velocity.z = direction.normalized().z * move_speed
	else:
		rotation.y = attack_yaw
		elapsed += delta
		if state == "MELEE_STARTUP" and elapsed >= melee_startup:
			state = "MELEE_ACTIVE"
			elapsed = 0.0
		elif state == "MELEE_ACTIVE" and elapsed >= melee_active:
			state = "MELEE_RECOVERY"
			elapsed = 0.0
		elif state == "MELEE_RECOVERY" and elapsed >= melee_recovery:
			state = "IDLE"
			cooldown = attack_interval
		elif state == "FIREBALL_STARTUP" and elapsed >= fireball_startup:
			fire_projectile()
			state = "FIREBALL_RECOVERY"
			elapsed = 0.0
		elif state == "FIREBALL_RECOVERY" and elapsed >= fireball_recovery:
			state = "IDLE"
			cooldown = attack_interval
		if state == "MELEE_ACTIVE" and not hit_player:
			query_melee()
	if state != "IDLE" or not ai_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
	velocity.y -= 28.0 * delta
	move_and_slide()
	velocity.x = 0.0
	velocity.z = 0.0
	update_visuals()

func query_melee() -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = melee_shape
	query.transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(0, melee_height / 2.0, 0))
	query.collision_mask = 4
	for result in get_world_3d().direct_space_state.intersect_shape(query):
		if result.collider != player:
			continue
		var ray := PhysicsRayQueryParameters3D.create(query.transform.origin, player.global_position + Vector3(0, 1, 0), 1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var impact = Impact.new()
		impact.damage = melee_damage
		impact.melee = true
		impact.blockable = true
		impact.parryable = true
		hit_player = true
		player.receive_attack(impact, global_position, self)

func fire_projectile():
	var projectile = Projectile.new()
	projectile.attacker = self
	projectile.speed = projectile_speed
	projectile.impact = Impact.new()
	projectile.impact.damage = projectile_damage
	projectile.impact.blockable = projectile_blockable
	projectile.impact.reflectable = projectile_reflectable
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector3(0, 1, 0) - global_basis.z * 0.7
	projectile.direction = (aim_point - projectile.global_position).normalized()
	return projectile

func receive_attack(impact: Resource, origin: Vector3, _attacker: Node) -> String:
	if health <= 0.0:
		return "DEAD"
	var incoming := origin - global_position
	incoming.y = 0
	var in_front := not incoming.is_zero_approx() and (-global_basis.z).dot(incoming.normalized()) >= 0.5
	if test_guard_mode > 0 and in_front and not impact.guard_break:
		if test_guard_mode == 2 and impact.melee and impact.parryable:
			if is_instance_valid(_attacker) and _attacker.has_method("stagger"):
				_attacker.stagger(0.6, 0.035)
			return "PARRY"
		if impact.blockable:
			return "BLOCK"
	health = maxf(0, health - impact.damage)
	flash_remaining = flash_duration
	var away := global_position - origin
	away.y = 0.0
	visual.position = Vector3(0, 0.9, 0) + global_basis.inverse() * away.normalized() * hit_recoil_distance
	freeze_remaining = maxf(freeze_remaining, impact.hit_stop)
	if impact.stagger_duration > 0.0:
		stagger(impact.stagger_duration, impact.hit_stop)
	if health <= 0.0:
		state = "DEAD"
		reset_remaining = reset_delay
	return "HIT"

func stagger(duration: float, freeze_time: float = 0.0) -> void:
	if health <= 0.0:
		return
	stagger_remaining = maxf(stagger_remaining, duration)
	freeze_remaining = maxf(freeze_remaining, freeze_time)
	state = "STAGGER"
	elapsed = 0.0
	visual.position = Vector3(0, 0.9, stagger_recoil_distance)
	velocity = Vector3.ZERO

func update_visuals() -> void:
	var color := Color("b9554c")
	if state in ["MELEE_STARTUP", "FIREBALL_STARTUP"]:
		color = Color("edbc45")
	elif state == "STAGGER":
		color = Color("77bddd")
	elif state == "DEAD":
		color = Color("333333")
	material.albedo_color = Color.WHITE if flash_remaining > 0.0 else color
	weapon.rotation.y = -0.9 if state == "MELEE_STARTUP" else (0.9 if state == "MELEE_ACTIVE" else 0.0)
	melee_debug.visible = debug_enabled and state in ["MELEE_STARTUP", "MELEE_ACTIVE"]