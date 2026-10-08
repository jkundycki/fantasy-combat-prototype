extends Area3D

@export var max_health: float = 100.0
@export var flash_duration: float = 0.09
@export var recoil_distance: float = 0.12
@export var recoil_return_speed: float = 2.0
@export var reset_delay: float = 0.6
const Feedback = preload("res://sandbox/combat_feedback.gd")
const DamageNumber = preload("res://sandbox/damage_number.gd")
var health: float = 100.0
var flash_remaining: float = 0.0
var freeze_remaining: float = 0.0
var reset_remaining: float = 0.0
var hits_received: int = 0
var material: StandardMaterial3D
var visual: MeshInstance3D
const BASE_COLOR := Color(0.65, 0.42, 0.2, 1)

func _ready() -> void:
	health = max_health
	collision_layer = 2
	collision_mask = 0
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	add_child(collider)
	visual = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = capsule.radius
	mesh.height = capsule.height
	material = StandardMaterial3D.new()
	material.albedo_color = BASE_COLOR
	mesh.material = material
	visual.mesh = mesh
	add_child(visual)

func receive_hit(amount: float, direction: Vector3, freeze_time: float, impact_kind: String = "hit") -> bool:
	if health <= 0.0:
		return false
	var before := health
	health = maxf(0.0, health - maxf(0, amount))
	DamageNumber.show_damage(self, before - health, 1.1)
	if before > health:
		Feedback.impact(self, impact_kind)
	hits_received += 1
	flash_remaining = flash_duration
	freeze_remaining = freeze_time
	visual.position = direction * recoil_distance
	if health <= 0.0:
		reset_remaining = reset_delay
	return true

func _physics_process(delta: float) -> void:
	if freeze_remaining > 0.0:
		freeze_remaining = maxf(0.0, freeze_remaining - delta)
	else:
		flash_remaining = maxf(0.0, flash_remaining - delta)
		visual.position = visual.position.move_toward(Vector3.ZERO, recoil_return_speed * delta)
	material.albedo_color = Color.WHITE if flash_remaining > 0.0 else BASE_COLOR
	if health <= 0.0:
		reset_remaining = maxf(0.0, reset_remaining - delta)
		if reset_remaining <= 0.0:
			health = max_health
			visual.position = Vector3.ZERO
func receive_attack(impact: Resource, origin: Vector3, _attacker: Node) -> String:
	var away := global_position - origin
	away.y = 0.0
	return "HIT" if receive_hit(impact.damage, away.normalized(), impact.hit_stop, impact.feedback_kind) else "DEAD"