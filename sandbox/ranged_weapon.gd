extends Node3D
# Staff/Bow share only the simple one-shot timing and existing weapon interface.
const Projectile = preload("res://sandbox/ranged_projectile.gd")
const Feedback = preload("res://sandbox/combat_feedback.gd")
const STARTUP = "ATTACK_STARTUP"
const ACTIVE = "ATTACK_ACTIVE"
const RECOVERY = "ATTACK_RECOVERY"
const IDLE = "IDLE"
@export_enum("STAFF", "BOW") var kind: int = 0
@export var startup_duration: float = 0.32
@export var recovery_duration: float = 0.48
@export var damage: float = 24.0
@export var guard_damage: float = 15.0
@export var projectile_speed: float = 9.0
@export var projectile_radius: float = 0.22
@export var projectile_lifetime: float = 6.0
@export_range(0, 1) var movement_multiplier: float = 0.85
@export_group("Staff continuous charge")
@export var max_charge_time: float = 2.4
@export var auto_release_time: float = 2.4 # Zero disables the cutoff for tuning.
@export_range(0, 1) var staff_charge_move_multiplier: float = 0.5
@export var staff_min_damage: float = 12.0
@export var staff_max_damage: float = 30.0
@export var staff_min_radius: float = 0.22
@export var staff_max_radius: float = 0.44
@export_group("Bow draw")
@export var draw_duration: float = 1.5
@export_range(0, 1) var draw_movement_multiplier: float = 0.5
@export var full_draw_damage_multiplier: float = 1.35
@export var full_draw_speed_multiplier: float = 1.20
@onready var player = get_parent()
var state: String = IDLE
var elapsed: float = 0
var attack_serial: int = 0
var defense_held: bool = false
var parry_state: String = "DOWN"
var feint_recovery_remaining: float = 0
var recovery_remaining: float = 0
var freeze_remaining: float = 0
var hold_movement_this_tick: bool = false
var blocked_damage_multiplier: float = 0
var debug_enabled: bool = false
var last_event: String = ""
var event_remaining: float = 0
var primary_held: bool = false
var release_direction := Vector3.FORWARD
var release_fraction: float = 0
var charge_orb: MeshInstance3D
var pivot: Node3D
var drawn_arrow: MeshInstance3D
var aim_debug: MeshInstance3D

static func build_model(parent: Node3D, bow: bool) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("825c39")
	for i in range(5 if bow else 1):
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.075, 0.34 if bow else 1.8, 0.075)
		mesh.mesh = box
		mesh.material_override = wood
		mesh.position.y = (i - 2) * 0.28 if bow else 0
		if bow:
			mesh.position.z = -0.18 * (1 - absf(i - 2) / 2.0)
			mesh.rotation.x = (i - 2) * 0.2
		root.add_child(mesh)
	var accent := MeshInstance3D.new()
	if bow:
		accent.name = "String"
		var string := BoxMesh.new()
		string.size = Vector3(0.012, 1.2, 0.012)
		accent.mesh = string
	else:
		var orb := SphereMesh.new()
		orb.radius = 0.16
		orb.height = 0.32
		accent.mesh = orb
		accent.position.y = 0.95
	var color := StandardMaterial3D.new()
	color.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	color.albedo_color = Color("ddd8c5") if bow else Color("70bfff")
	accent.material_override = color
	root.add_child(accent)
	return root

func _ready() -> void:
	pivot = build_model(self, kind == 1)
	pivot.position = Vector3(-0.32 if kind == 1 else 0.4, 1.0, -0.45)
	drawn_arrow = MeshInstance3D.new()
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.035, 0.035, 0.65)
	drawn_arrow.mesh = shaft
	drawn_arrow.position = Vector3(0, 1.25, -0.5)
	add_child(drawn_arrow)
	aim_debug = MeshInstance3D.new()
	var line := BoxMesh.new()
	line.size = Vector3(projectile_radius * 2, projectile_radius * 2, 3)
	aim_debug.mesh = line
	aim_debug.position = Vector3(0, 1.15, -2.1)
	var tint := StandardMaterial3D.new()
	tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tint.albedo_color = Color(0.2, 0.8, 1, 0.15)
	aim_debug.material_override = tint
	add_child(aim_debug)
	charge_orb = make_charge_orb(self)
	update_visuals()

static func make_charge_orb(parent: Node3D) -> MeshInstance3D:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	orb.mesh = sphere
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("8bd6ff")
	orb.material_override = glow
	orb.visible = false
	parent.add_child(orb)
	return orb

func primary_pressed() -> bool:
	if not primary():
		return false
	primary_held = true
	state = "STAFF_CHARGE" if kind == 0 else "BOW_DRAW"
	update_visuals()
	return true

func primary_released() -> void:
	primary_held = false
	if state == "STAFF_CHARGE":
		release_fraction = charge_fraction()
		player.visual.global_rotation.y = player.facing_yaw()
		release_direction = -player.visual.global_basis.z
		# Staff release is immediate: no queued cast or camera-based aim.
		fire(release_fraction, release_direction)
		state = RECOVERY
		elapsed = 0
	elif state == "BOW_DRAW":
		release_fraction = draw_fraction()
		player.visual.global_rotation.y = player.facing_yaw()
		release_direction = -player.visual.global_basis.z
		if elapsed >= startup_duration:
			fire(release_fraction, release_direction)
			state = RECOVERY
			elapsed = 0
		else:
			state = "BOW_RELEASE_PENDING"
	update_visuals()

func cancel_draw() -> void:
	if state in ["BOW_DRAW", "STAFF_CHARGE"]:
		reset_combat()
		update_visuals()

func cancel_primary() -> void:
	if state in ["STAFF_CHARGE", "BOW_DRAW"]:
		reset_combat()
	update_visuals()

func charging() -> bool:
	return state == "STAFF_CHARGE"

func draw_fraction() -> float:
	return clampf((elapsed - startup_duration) / maxf(draw_duration - startup_duration, 0.001), 0, 1) if state == "BOW_DRAW" else release_fraction

static func staff_fraction(held_time: float, maximum_time: float) -> float:
	return clampf(held_time / maxf(maximum_time, 0.001), 0, 1)

func charge_fraction() -> float:
	return staff_fraction(elapsed, max_charge_time) if charging() else release_fraction

func apply_staff_charge(shot, fraction: float) -> void:
	# Player and bot share these exact rules; reflection keeps this same object.
	var amount := clampf(fraction, 0, 1)
	shot.charge_fraction = amount
	shot.speed = projectile_speed
	shot.radius = lerpf(staff_min_radius, staff_max_radius, amount)
	shot.lifetime = projectile_lifetime
	shot.impact.damage = lerpf(staff_min_damage, staff_max_damage, amount)
	shot.impact.feedback_kind = "charged_magic" if amount >= 0.5 else "magic"

func primary() -> bool:
	if busy() or freeze_remaining > 0 or player.dodge_remaining > 0 or player.recovery_remaining > 0 or player.health <= 0:
		return false
	state = STARTUP
	elapsed = 0
	attack_serial += 1
	update_visuals()
	return true

func tick(delta: float) -> void:
	event_remaining = maxf(0, event_remaining - delta)
	hold_movement_this_tick = freeze_remaining > 0
	if hold_movement_this_tick:
		freeze_remaining = maxf(0, freeze_remaining - delta)
		return
	# Facing stays authoritative; firing never writes the actor's velocity.
	player.visual.global_rotation.y = player.facing_yaw()
	if state != IDLE:
		elapsed += delta
		if charging() and auto_release_time > 0 and elapsed >= auto_release_time:
			elapsed = auto_release_time
			primary_released() # One cutoff shot; continuing to hold never repeats.
		elif state in [STARTUP, "BOW_RELEASE_PENDING"] and elapsed >= startup_duration:
			fire(release_fraction, release_direction) if state == "BOW_RELEASE_PENDING" else fire()
			state = RECOVERY
			elapsed -= startup_duration
		elif state == RECOVERY and elapsed >= recovery_duration:
			state = IDLE
			elapsed = 0
	update_visuals()

func spawn_origin() -> Vector3:
	# Model/hand socket and heading are independent. Never use camera origin/pitch.
	return pivot.to_global(Vector3(0, 0.45, -0.2)) if kind == 0 else drawn_arrow.to_global(Vector3(0, 0, -0.36))

func fire(strength: float = 0, heading: Vector3 = Vector3.ZERO):
	update_visuals()
	var shot = Projectile.new()
	shot.attacker = player
	shot.arrow = kind == 1
	shot.speed = projectile_speed * (lerpf(1, full_draw_speed_multiplier, strength) if kind == 1 else 1)
	shot.radius = projectile_radius
	shot.lifetime = projectile_lifetime
	shot.direction = heading.normalized() if not heading.is_zero_approx() else (-player.visual.global_basis.z).normalized()
	shot.impact.damage = damage * (lerpf(1, full_draw_damage_multiplier, strength) if kind == 1 else 1)
	shot.impact.guard_damage = guard_damage
	shot.impact.blockable = true
	shot.impact.reflectable = kind == 0
	shot.impact.feedback_kind = "arrow" if kind == 1 else "magic"
	if kind == 0:
		apply_staff_charge(shot, strength)
	player.get_parent().add_child(shot)
	shot.global_position = spawn_origin()
	Feedback.sound(player, "light_swing" if kind == 1 else "cast")
	return shot

func busy() -> bool:
	return state != IDLE or player.guard_broken()
func active_swing():
	return self
func can_feint() -> bool:
	return false
func movement_scale() -> float:
	return staff_charge_move_multiplier if charging() else (draw_movement_multiplier if state == "BOW_DRAW" else (movement_multiplier if state != IDLE else 1.0))
func heavy_attack() -> bool:
	return false
func special() -> bool:
	return false
func hard_feint() -> bool:
	return false
func defense(_held: bool) -> void:
	pass
func lower_shield() -> void:
	pass
func reset_combo() -> void:
	pass
func defend(_impact: Resource, _origin: Vector3, _attacker: Node) -> String:
	return "HIT"
func reset_combat() -> void:
	state = IDLE
	primary_held = false
	release_fraction = 0
	elapsed = 0
	freeze_remaining = 0
	hold_movement_this_tick = false
func freeze(duration: float) -> void:
	freeze_remaining = maxf(freeze_remaining, duration)
func feedback(message: String) -> void:
	last_event = message
	event_remaining = 1
func grammar_text() -> String:
	return ("DRAW" if kind == 1 else "CAST") + " | " + state
func debug_text() -> String:
	return "%s | %s | Charge %.0f%% | %.1f m/s" % [name, state, charge_fraction() * 100, projectile_speed] if kind == 0 else "%s | %s | %.1f m/s | radius %.2f m | %.0f damage" % [name, state, projectile_speed, projectile_radius, damage]
func update_visuals() -> void:
	if pivot == null:
		return
	rotation.y = player.get_node("Visual").rotation.y
	pivot.rotation.x = -0.3 * sin(clampf(elapsed / maxf(startup_duration, 0.001), 0, 1) * PI / 2) if state == STARTUP else 0
	drawn_arrow.visible = kind == 1 and state in [STARTUP, "BOW_DRAW", "BOW_RELEASE_PENDING"]
	drawn_arrow.position.z = lerpf(-0.5, -0.2, clampf(elapsed / maxf(startup_duration, 0.001), 0, 1))
	aim_debug.visible = debug_enabled and state != IDLE
	if kind == 1:
		var fraction := draw_fraction()
		drawn_arrow.position = Vector3(-0.32, 1.25, lerpf(-0.5, -0.1, fraction))
		var string = pivot.get_node("String")
		string.position.z = fraction * 0.20
		string.scale.y = 1.0 + fraction * 0.08
	if charge_orb != null:
		charge_orb.visible = charging()
		charge_orb.scale = Vector3.ONE * lerpf(staff_min_radius, staff_max_radius, charge_fraction()) / 0.4
		charge_orb.material_override.albedo_color = Color("70bfff").lerp(Color("b9efff"), charge_fraction())
		if charging():
			pivot.rotation.x = -0.45 - charge_fraction() * 0.25
		elif kind == 0 and state == RECOVERY:
			pivot.rotation.x = lerpf(0.15, 0, clampf(elapsed / maxf(recovery_duration, 0.001), 0, 1))
		charge_orb.global_position = spawn_origin()
