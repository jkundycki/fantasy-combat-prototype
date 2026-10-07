extends Node3D

const Impact = preload("res://sandbox/incoming_attack.gd")
@export var speed: float = 5.0
@export var lifetime: float = 8.0
@export_range(0.0, 0.2) var reflection_offset: float = 0.05
var base_speed: float = 0.0
var impact: Resource = Impact.new()
var attacker: Node3D
var direction := Vector3.FORWARD
var reflected: bool = false
var consumed: bool = false
var visual: MeshInstance3D

func _ready() -> void:
	base_speed = speed
	add_to_group("test_projectiles")
	visual = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ff752c")
	sphere.material = material
	visual.mesh = sphere
	add_child(visual)

func _physics_process(delta: float) -> void:
	if consumed:
		return
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	var next := global_position + direction * speed * delta
	# Sweep each traveled segment so a fast shot cannot tunnel between ticks.
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 1 | (8 if reflected else 4))
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		global_position = next
		return
	var target = result.collider
	if target.has_method("receive_attack"):
		var outcome: String = target.receive_attack(impact, global_position, attacker)
		if outcome == "REFLECT" and impact.reflectable and not reflected:
			reflected = true
			global_position = result.position
			# Character facing determines aim; damage ownership is a separate change.
			direction = (-target.visual.global_basis.z).normalized()
			attacker = target
			speed = base_speed * target.weapon_set.spell_reflect_speed_multiplier
			# Reflected collision mask excludes player/shield; leave the contact point.
			global_position += direction * reflection_offset
			visual.mesh.material.albedo_color = Color.CYAN
			lifetime = 8.0
			return
	consumed = true
	queue_free()