extends Node3D

@export_group("Timed melee parry")
@export var parry_startup: float = 0.04
@export var parry_window: float = 0.18
@export var parry_recovery: float = 0.3
@export var successful_parry_recovery: float = 0.08
@export var defensive_arc_degrees: float = 110.0
@export var parry_stagger_duration: float = 0.9
@export var parry_hit_stop: float = 0.055
@export var parry_movement_multiplier: float = 0.65

@onready var player = get_parent()
@onready var slash = $Slash
@onready var heavy = $Heavy
@onready var chain = $PrimaryChain
@onready var feint = $Feint
@export_range(0.0, 0.5) var hard_feint_recovery: float = 0.15
var feint_recovery_remaining: float = 0.0
var bash_soft_feint: bool = false
var defense_held: bool = false
var parry_state: String = "DOWN"
var parry_elapsed: float = 0.0
var recovery_remaining: float = 0.0
var freeze_remaining: float = 0.0
var hold_movement_this_tick: bool = false
var debug_enabled: bool = true
var last_event: String = ""
var event_remaining: float = 0.0
var blade_pivot: Node3D
var material: StandardMaterial3D

func _ready() -> void:
	chain.attacks = [$Slash, $Reverse, $Finisher]
	blade_pivot = Node3D.new()
	blade_pivot.position.y = 1.15
	add_child(blade_pivot)
	var blade := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.3, 0.16, slash.reach)
	material = StandardMaterial3D.new()
	material.albedo_color = Color("bac5d1")
	mesh.material = material
	blade.mesh = mesh
	blade.position.z = -slash.reach / 2.0
	blade_pivot.add_child(blade)
	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.85, 0.2, 0.15)
	guard.mesh = guard_mesh
	guard.position.z = -0.15
	blade_pivot.add_child(guard)
	update_visuals()

func primary() -> bool:
	return chain.primary()

func heavy_attack() -> bool:
	if chain.running:
		return chain.queue_heavy()
	if busy():
		return false
	chain.reset()
	bash_soft_feint = false
	return begin_swing(heavy)

func special() -> bool:
	if heavy.busy() and heavy.can_feint() and freeze_remaining <= 0:
		chain.reset()
		heavy.state = heavy.IDLE
		bash_soft_feint = true
		feint.begin()
		return true
	if busy():
		return false
	chain.reset()
	bash_soft_feint = false
	return begin_swing(feint)

func hard_feint() -> bool:
	if not heavy.busy() or not heavy.can_feint() or freeze_remaining > 0:
		return false
	chain.reset()
	heavy.state = heavy.IDLE
	feint_recovery_remaining = hard_feint_recovery
	bash_soft_feint = false
	feedback("HARD_FEINT")
	update_visuals()
	return true

func grammar_text() -> String:
	if feint_recovery_remaining > 0:
		return "HARD_FEINT | FEINT_RECOVERY %.2f s" % feint_recovery_remaining
	if heavy.busy():
		if heavy.state == heavy.STARTUP:
			return "HEAVY_STARTUP %.0f%% | %s | Cutoff %.0f%%" % [100 * heavy.elapsed / maxf(heavy.startup_duration, 0.001), "HEAVY_FEINTABLE" if heavy.can_feint() else "HEAVY_COMMITTED", 100 * heavy.feint_startup_fraction]
		return "HEAVY_COMMITTED | " + heavy.state
	if feint.busy():
		return "BASH_SOFT_FEINT" if bash_soft_feint else "BASH"
	if chain.busy():
		return "LIGHT_COMBO_STEP %d | %s" % [chain.step + 1, chain.active().state]
	return "NEUTRAL"

func begin_swing(swing) -> bool:
	if busy() or parry_state != "DOWN" or freeze_remaining > 0 or player.dodge_remaining > 0 or player.recovery_remaining > 0:
		return false
	player.visual.global_rotation.y = player.facing_yaw()
	swing.begin()
	return true

func defense(held: bool) -> void:
	var pressed := held and not defense_held
	defense_held = held
	if pressed:
		chain.cancel_continuation()
	if pressed and not busy() and parry_state == "DOWN" and freeze_remaining <= 0 and player.dodge_remaining <= 0 and player.recovery_remaining <= 0:
		parry_state = "PARRY_STARTUP"
		parry_elapsed = 0.0
	# Release does not cancel the finite attempt; holding does not repeat it.

func busy() -> bool:
	return chain.busy() or heavy.busy() or feint.busy() or feint_recovery_remaining > 0 or parry_state != "DOWN"
func active_swing():
	return feint if feint.busy() else (heavy if heavy.busy() else chain.active())
func movement_scale() -> float:
	if feint_recovery_remaining > 0:
		return 1.0
	if chain.busy() or heavy.busy() or feint.busy():
		return active_swing().movement_multiplier
	return parry_movement_multiplier if parry_state != "DOWN" else 1.0
func lower_shield() -> void:
	pass # Mobility uses the same small hook; this weapon has no held shield.

func tick(delta: float) -> void:
	event_remaining = maxf(0, event_remaining - delta)
	hold_movement_this_tick = freeze_remaining > 0
	if hold_movement_this_tick:
		freeze_remaining = maxf(0, freeze_remaining - delta)
		update_visuals()
		return
	if parry_state in ["PARRY_STARTUP", "PARRY_WINDOW"]:
		player.visual.global_rotation.y = player.facing_yaw()
		parry_elapsed += delta
		if parry_state == "PARRY_STARTUP" and parry_elapsed >= parry_startup:
			parry_elapsed -= parry_startup
			parry_state = "PARRY_WINDOW"
		if parry_state == "PARRY_WINDOW" and parry_elapsed >= parry_window:
			parry_state = "RECOVERY"
			recovery_remaining = parry_recovery
	elif parry_state == "RECOVERY":
		recovery_remaining = maxf(0, recovery_remaining - delta)
		if recovery_remaining <= 0:
			parry_state = "DOWN"
	feint_recovery_remaining = maxf(0, feint_recovery_remaining - delta)
	chain.tick(delta)
	heavy.tick(delta)
	feint.tick(delta)

	update_visuals()

func defend(impact: Resource, origin: Vector3, attacker: Node) -> String:
	# Projectiles are never blocked/reflected, regardless of their reflectable flag.
	if impact.guard_break or parry_state != "PARRY_WINDOW" or not impact.melee or not impact.parryable or player.dodge_remaining > 0:
		return "HIT"
	var incoming: Vector3 = origin - player.global_position
	incoming.y = 0
	if incoming.is_zero_approx() or (-player.visual.global_basis.z).dot(incoming.normalized()) < cos(deg_to_rad(defensive_arc_degrees / 2)):
		return "HIT"
	if is_instance_valid(attacker) and attacker.has_method("stagger"):
		attacker.stagger(parry_stagger_duration, parry_hit_stop)
	parry_state = "RECOVERY"
	recovery_remaining = successful_parry_recovery
	freeze(parry_hit_stop)
	feedback("PARRY")
	return "PARRY"

func freeze(duration: float) -> void:
	freeze_remaining = maxf(freeze_remaining, duration)
func feedback(message: String) -> void:
	last_event = message
	event_remaining = 1.0
func reset_combat() -> void:
	chain.reset()
	feint.state = feint.IDLE
	feint_recovery_remaining = 0.0
	bash_soft_feint = false
	heavy.state = heavy.IDLE
	parry_state = "DOWN"
	defense_held = false
	recovery_remaining = 0
	freeze_remaining = 0
	hold_movement_this_tick = false
func debug_text() -> String:
	var extra := "GUARD-BREAK HILT BASH" if feint.busy() else ("STANDALONE HEAVY" if heavy.busy() else parry_state)
	return "GREATSWORD | %s\n%s" % [extra, grammar_text() + "\n" + chain.debug_text(active_swing())]

func reset_combo() -> void:
	chain.reset()
func update_visuals() -> void:
	rotation.y = player.get_node("Visual").rotation.y
	blade_pivot.rotation = Vector3.ZERO
	var overhead = heavy if heavy.busy() else $Finisher
	var broad = chain.active()
	if heavy.busy():
		if overhead.state == overhead.STARTUP:
			blade_pivot.rotation.x = lerpf(0, -1.5, clampf(overhead.elapsed / maxf(overhead.startup_duration, 0.001), 0, 1))
		elif overhead.state == overhead.ACTIVE:
			blade_pivot.rotation.x = lerpf(-1.5, 0.6, overhead.elapsed / overhead.active_duration)
		else:
			blade_pivot.rotation.x = lerpf(0.6, 0, clampf(overhead.elapsed / maxf(overhead.recovery_duration, 0.001), 0, 1))
	elif chain.busy():
		var half_arc := deg_to_rad(broad.arc_degrees / 2) * (-1.0 if broad.reverse_swing else 1.0)
		if broad.state == broad.STARTUP:
			blade_pivot.rotation.y = lerpf(-0.25, -half_arc, clampf(broad.elapsed / maxf(broad.startup_duration, 0.001), 0, 1))
		elif broad.state == broad.ACTIVE:
			blade_pivot.rotation.y = lerpf(-half_arc, half_arc, broad.elapsed / broad.active_duration)
		else:
			blade_pivot.rotation.y = lerpf(half_arc, -0.25, clampf(broad.elapsed / maxf(broad.recovery_duration, 0.001), 0, 1))
	elif parry_state != "DOWN":
		blade_pivot.rotation.z = -0.7
	material.albedo_color = Color.CYAN if parry_state == "PARRY_WINDOW" else Color("bac5d1")
	if feint.busy():
		blade_pivot.position.z = -0.25 if feint.state == feint.ACTIVE else 0.0
	else:
		blade_pivot.position.z = 0.0
	for swing in chain.attacks:
		swing.debug_update(debug_enabled)
	heavy.debug_update(debug_enabled)
	feint.debug_update(debug_enabled)
