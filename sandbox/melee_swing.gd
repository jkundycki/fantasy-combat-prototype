extends Node3D

const Impact = preload("res://sandbox/incoming_attack.gd")
@export_group("Timing and commitment")
@export_range(0.0, 2.0) var startup_duration: float = 0.09
@export_range(0.0084, 1.0) var active_duration: float = 0.12
@export_range(0.0, 2.0) var recovery_duration: float = 0.2
@export var damage: float = 25.0
@export_range(0.0, 1.0) var movement_multiplier: float = 0.55
@export_range(0.0, 720.0) var turn_speed_degrees: float = 0.0
@export_group("Hitbox")
@export_range(0.1, 5.0) var reach: float = 2.2
@export_range(10.0, 170.0) var arc_degrees: float = 100.0
@export var hitbox_height: float = 1.0
@export var hitbox_center_height: float = 1.0
@export_group("Impact")
@export var stagger_duration: float = 0.0
@export_range(0.0, 0.15) var hit_stop_duration: float = 0.035
@export var shield_bash: bool = false
@export var commitment_time: float = -1.0
@export_range(-1.0, 1.0) var feint_startup_fraction: float = -1.0
@export var feint_window_start: float = -1.0
@export var feint_window_end: float = -1.0
@export var reverse_swing: bool = false
@export var guard_break: bool = false
@export var hit_feedback: String = ""

const IDLE := "IDLE"
const STARTUP := "ATTACK_STARTUP"
const ACTIVE := "ATTACK_ACTIVE"
const RECOVERY := "ATTACK_RECOVERY"
var attack_serial: int = 0
var state: String = IDLE
var elapsed: float = 0.0
var locked_yaw: float = 0.0
var hit_targets: Array[int] = []
var shape := ConvexPolygonShape3D.new()
var debug_mesh: MeshInstance3D
@onready var weapon = get_parent()

func _ready() -> void:
	var points := PackedVector3Array()
	for height in [-hitbox_height / 2.0, hitbox_height / 2.0]:
		points.append(Vector3(0, height, 0))
		for index in range(13):
			var angle := deg_to_rad(-arc_degrees / 2.0 + arc_degrees * index / 12.0)
			points.append(Vector3(sin(angle) * reach, height, -cos(angle) * reach))
	shape.points = points
	debug_mesh = MeshInstance3D.new()
	debug_mesh.mesh = shape.get_debug_mesh()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.CYAN if shield_bash else Color.ORANGE
	debug_mesh.material_override = material
	debug_mesh.position.y = hitbox_center_height
	add_child(debug_mesh)

func begin() -> void:
	attack_serial += 1
	state = STARTUP
	elapsed = 0.0
	locked_yaw = weapon.player.visual.global_rotation.y
	hit_targets.clear()
	weapon.global_rotation.y = locked_yaw
	rotation.y = 0.0

func busy() -> bool:
	return state != IDLE

func tick(delta: float) -> void:
	if not busy():
		return
	if turn_speed_degrees > 0.0 and not facing_committed():
		var desired: float = weapon.player.facing_yaw()
		locked_yaw = rotate_toward(locked_yaw, desired, deg_to_rad(turn_speed_degrees) * delta)
	weapon.global_rotation.y = locked_yaw
	rotation.y = 0.0
	weapon.player.visual.global_rotation.y = locked_yaw
	elapsed += delta
	while busy():
		var duration := startup_duration if state == STARTUP else (active_duration if state == ACTIVE else recovery_duration)
		if elapsed < duration:
			break
		elapsed -= duration
		state = ACTIVE if state == STARTUP else (RECOVERY if state == ACTIVE else IDLE)
	if state == ACTIVE:
		query_hits()

func query_hits() -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(0, hitbox_center_height, 0))
	query.collision_mask = 2
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var hurtbox = result.collider
		var target_id: int = hurtbox.get_instance_id()
		if target_id in hit_targets or not hurtbox.has_method("receive_attack"):
			continue
		var ray := PhysicsRayQueryParameters3D.create(query.transform.origin, hurtbox.global_position, 1, [weapon.player.get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var impact = Impact.new()
		impact.damage = damage
		impact.melee = true
		impact.blockable = not guard_break
		impact.parryable = not guard_break
		impact.guard_break = guard_break
		impact.stagger_duration = stagger_duration
		impact.hit_stop = hit_stop_duration
		var outcome: String = hurtbox.receive_attack(impact, query.transform.origin, weapon.player)
		if outcome == "PARRY":
			return
		if outcome == "BLOCK":
			hit_targets.append(target_id)
			weapon.feedback("STRIKE BLOCKED")
		if outcome == "HIT":
			hit_targets.append(target_id)
			weapon.freeze(hit_stop_duration)
			weapon.feedback(hit_feedback if not hit_feedback.is_empty() else ("SHIELD BASH" if shield_bash else "SWORD HIT"))

func debug_update(enabled: bool) -> void:
	debug_mesh.visible = enabled and busy()
func facing_committed() -> bool:
	if feint_startup_fraction >= 0.0:
		return state != STARTUP or elapsed >= startup_duration * feint_startup_fraction
	if turn_speed_degrees <= 0:
		return true
	return commitment_time >= 0 and (state != STARTUP or elapsed >= minf(commitment_time, startup_duration))

func can_feint() -> bool:
	if feint_startup_fraction >= 0.0:
		return state == STARTUP and elapsed < startup_duration * feint_startup_fraction
	return state == STARTUP and feint_window_start >= 0 and elapsed >= feint_window_start and elapsed < feint_window_end and not (commitment_time >= 0 and elapsed >= minf(commitment_time, startup_duration))
