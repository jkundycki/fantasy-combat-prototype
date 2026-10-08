extends Node3D
# One physical shot. Ownership and collision faction change only on reflection.
const Impact = preload("res://sandbox/incoming_attack.gd")
@export var speed: float = 18.0
@export var radius: float = 0.22
@export var lifetime: float = 3.0
var impact = Impact.new()
var attacker: Node3D
var direction := Vector3.FORWARD
var arrow: bool = false
var charge_fraction: float = 0.0
var reflected: bool = false
var consumed: bool = false
var base_speed: float
var initial_lifetime: float
var sweep: ShapeCast3D
var material := StandardMaterial3D.new()

func _ready() -> void:
	add_to_group("test_projectiles")
	base_speed = speed
	initial_lifetime = lifetime
	sweep = ShapeCast3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(radius, 0.001)
	sweep.shape = sphere
	sweep.margin = 0.0
	sweep.collide_with_areas = true
	sweep.max_results = 16
	add_child(sweep)
	configure_faction()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffe4b0") if arrow else Color("70bfff")
	var body := MeshInstance3D.new()
	if arrow:
		var shaft := BoxMesh.new()
		shaft.size = Vector3(0.035, 0.035, 0.65)
		body.mesh = shaft
		var tip := MeshInstance3D.new()
		var head := PrismMesh.new()
		head.size = Vector3(0.12, 0.08, 0.18)
		tip.mesh = head
		tip.position.z = -0.36
		tip.material_override = material
		body.add_child(tip)
	else:
		var orb := SphereMesh.new()
		orb.radius = radius
		orb.height = radius * 2
		body.mesh = orb
		var tail := MeshInstance3D.new()
		var streak := BoxMesh.new()
		streak.size = Vector3(radius * 0.65, radius * 0.65, radius * 3)
		tail.mesh = streak
		tail.position.z = radius * 1.5
		tail.material_override = material
		body.add_child(tail)
	body.material_override = material
	add_child(body)

func configure_faction() -> void:
	sweep.clear_exceptions()
	var from_player: bool = is_instance_valid(attacker) and attacker.has_method("movement_state")
	sweep.collision_mask = 1 | (8 | 2 if from_player else 4)
	if attacker is CollisionObject3D:
		sweep.add_exception(attacker)

func _physics_process(delta: float) -> void:
	if consumed:
		return
	lifetime -= delta
	if lifetime <= 0:
		consumed = true
		queue_free()
		return
	direction = direction.normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		look_at(global_position + direction, Vector3.UP)
	# Swept sphere, including starting overlaps: radius affects actual hits.
	sweep.target_position = global_basis.inverse() * direction * speed * delta
	sweep.force_shapecast_update()
	if not sweep.is_colliding():
		global_position += direction * speed * delta
		return
	var index: int = 0
	var nearest: float = INF
	for i in range(sweep.get_collision_count()):
		var distance := global_position.distance_squared_to(sweep.get_collision_point(i))
		if distance < nearest:
			nearest = distance
			index = i
	var target = sweep.get_collider(index)
	if target is Area3D and target.get_parent().has_method("receive_attack"):
		target = target.get_parent()
	var origin := global_position
	global_position += direction * speed * delta * sweep.get_closest_collision_safe_fraction()
	if is_instance_valid(target) and target.has_method("receive_attack"):
		var result: String = target.receive_attack(impact, origin, attacker)
		if result == "REFLECT" and impact.reflectable and not reflected:
			reflected = true
			direction = (-target.visual.global_basis.z if target.has_method("movement_state") else -target.global_basis.z).normalized()
			var multiplier: float = target.weapon_set.spell_reflect_speed_multiplier if target.has_method("movement_state") else target.spell_reflect_speed_multiplier
			speed = base_speed * multiplier
			attacker = target
			configure_faction()
			global_position += direction * 0.05
			lifetime = initial_lifetime
			material.albedo_color = Color.CYAN
			return
	consumed = true
	queue_free()
