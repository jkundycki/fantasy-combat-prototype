extends Node3D

signal blocked(outcome: String, impact: Resource, attacker: Node)
@export_group("Shield defense")
@export_range(10.0, 180.0) var defensive_arc_degrees: float = 120.0
@export_range(0.0, 0.5) var block_startup: float = 0.0
@export_range(0.0, 0.5) var perfect_block_duration: float = 0.16
@export_range(0.0, 3.0) var parry_stagger_duration: float = 0.85
@export_range(0.0, 1.0) var defender_recovery: float = 0.08
@export_range(0.0, 0.15) var parry_hit_stop: float = 0.045
@export_range(0.0, 0.15) var block_hit_stop: float = 0.015
@export_range(0.0, 1.0) var blocked_damage_multiplier: float = 0.0
@export_range(0.0, 1.0) var defense_movement_multiplier: float = 0.7

@onready var player = get_parent()
@onready var sword = $Sword
@onready var bash = $Bash
@onready var heavy = $Heavy
@onready var chain = $PrimaryChain
@onready var feint = $Feint
@export_range(0.0, 0.5) var hard_feint_recovery: float = 0.15
var feint_recovery_remaining: float = 0.0
var bash_soft_feint: bool = false
@export var spell_reflect_speed_multiplier: float = 2.0
var defense_held: bool = false
var shield_raised: bool = false
var raise_elapsed: float = 0.0
var recovery_remaining: float = 0.0
var freeze_remaining: float = 0.0
var hold_movement_this_tick: bool = false
var debug_enabled: bool = true
var last_event: String = ""
var event_remaining: float = 0.0
var shield_flash: float = 0.0
var sword_pivot: Node3D
var shield_mesh: MeshInstance3D
var shield_material: StandardMaterial3D
var defense_debug: MeshInstance3D

func _ready() -> void:
	chain.attacks = [$Sword, $Reverse, $Finisher]
	sword_pivot = Node3D.new()
	add_child(sword_pivot)
	sword_pivot.position.y = 1.0
	var blade := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.08, sword.reach)
	blade.mesh = mesh
	blade.position.z = -sword.reach / 2.0
	sword_pivot.add_child(blade)
	shield_mesh = MeshInstance3D.new()
	var shield := BoxMesh.new()
	shield.size = Vector3(0.75, 0.9, 0.15)
	shield_material = StandardMaterial3D.new()
	shield_material.albedo_color = Color("577db8")
	shield.material = shield_material
	shield_mesh.mesh = shield
	add_child(shield_mesh)
	make_defense_debug()
	update_visuals()

func make_defense_debug() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	mesh.surface_add_vertex(Vector3.ZERO)
	for index in range(25):
		var angle := deg_to_rad(-defensive_arc_degrees / 2.0 + defensive_arc_degrees * index / 24.0)
		mesh.surface_add_vertex(Vector3(sin(angle) * 1.5, 0, -cos(angle) * 1.5))
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_end()
	defense_debug = MeshInstance3D.new()
	defense_debug.mesh = mesh
	defense_debug.position.y = 0.08
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.CYAN
	defense_debug.material_override = material
	add_child(defense_debug)

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
	return begin_swing(bash)

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
	if bash.busy():
		return "BASH"
	if feint.busy():
		return "BASH_SOFT_FEINT" if bash_soft_feint else "BASH"
	if chain.busy():
		return "LIGHT_COMBO_STEP %d | %s" % [chain.step + 1, chain.active().state]
	return "NEUTRAL"

func begin_swing(swing) -> bool:
	if busy() or recovery_remaining > 0.0 or player.dodge_remaining > 0.0 or player.recovery_remaining > 0.0 or freeze_remaining > 0.0:
		return false
	lower_shield()
	player.visual.global_rotation.y = player.facing_yaw()
	swing.begin()
	return true

func defense(held: bool) -> void:
	defense_held = held
	if held:
		chain.cancel_continuation()
	if not held:
		lower_shield()

func lower_shield() -> void:
	shield_raised = false
	raise_elapsed = 0.0

func busy() -> bool:
	return chain.busy() or heavy.busy() or bash.busy() or feint.busy() or feint_recovery_remaining > 0

func active_swing():
	return feint if feint.busy() else (heavy if heavy.busy() else (bash if bash.busy() else chain.active()))

func movement_scale() -> float:
	if feint_recovery_remaining > 0:
		return 1.0
	if busy():
		return active_swing().movement_multiplier
	return defense_movement_multiplier if shield_raised else 1.0

func tick(delta: float) -> void:
	event_remaining = maxf(0.0, event_remaining - delta)
	shield_flash = maxf(0.0, shield_flash - delta)
	hold_movement_this_tick = freeze_remaining > 0.0
	if hold_movement_this_tick:
		freeze_remaining = maxf(0.0, freeze_remaining - delta)
		update_visuals()
		return
	recovery_remaining = maxf(0.0, recovery_remaining - delta)
	if defense_held and not busy() and player.dodge_remaining <= 0.0:
		if not shield_raised:
			shield_raised = true
			raise_elapsed = 0.0
		else:
			raise_elapsed += delta
	else:
		lower_shield()
	feint_recovery_remaining = maxf(0, feint_recovery_remaining - delta)
	chain.tick(delta)
	bash.tick(delta)
	heavy.tick(delta)
	feint.tick(delta)

	update_visuals()

func shield_state() -> String:
	if not shield_raised:
		return "DOWN"
	if raise_elapsed < block_startup:
		return "RAISING"
	if perfect_block_duration > 0.0 and raise_elapsed < block_startup + perfect_block_duration:
		return "PERFECT BLOCK"
	return "BLOCK"

func defend(impact: Resource, origin: Vector3, attacker: Node) -> String:
	if impact.guard_break or shield_state() not in ["BLOCK", "PERFECT BLOCK"] or busy() or player.dodge_remaining > 0.0:
		return "HIT"
	var incoming: Vector3 = origin - player.global_position
	incoming.y = 0.0
	if incoming.is_zero_approx():
		return "HIT"
	var forward: Vector3 = -player.visual.global_basis.z
	if forward.dot(incoming.normalized()) < cos(deg_to_rad(defensive_arc_degrees / 2.0)):
		return "HIT"
	var result := "HIT"
	if shield_state() == "PERFECT BLOCK":
		if impact.melee and impact.parryable:
			result = "PARRY"
			if is_instance_valid(attacker) and attacker.has_method("stagger"):
				attacker.stagger(parry_stagger_duration, parry_hit_stop)
		elif not impact.melee and impact.reflectable:
			result = "REFLECT"
	if result == "HIT" and impact.blockable:
		result = "BLOCK"
	if result != "HIT":
		shield_flash = 0.12
		recovery_remaining = defender_recovery
		freeze(parry_hit_stop if result in ["PARRY", "REFLECT"] else block_hit_stop)
		feedback("SPELL REFLECT" if result == "REFLECT" else result)
		blocked.emit(result, impact, attacker) # Future guard cost attaches here.
	return result

func freeze(duration: float) -> void:
	freeze_remaining = maxf(freeze_remaining, duration)

func feedback(message: String) -> void:
	last_event = message
	event_remaining = 1.0

func update_visuals() -> void:
	rotation.y = player.get_node("Visual").rotation.y
	if busy():
		var swing = active_swing()
		var progress: float = clampf(swing.elapsed / maxf(swing.active_duration, 0.001), 0, 1)
		if not swing.shield_bash:
			var half_arc := deg_to_rad(swing.arc_degrees / 2.0) * (-1.0 if swing.reverse_swing else 1.0)
			if swing.state == swing.STARTUP:
				sword_pivot.rotation.y = lerpf(-0.35, -half_arc, clampf(swing.elapsed / maxf(swing.startup_duration, 0.001), 0, 1))
			elif swing.state == swing.ACTIVE:
				sword_pivot.rotation.y = lerpf(-half_arc, half_arc, progress)
			else:
				sword_pivot.rotation.y = lerpf(half_arc, -0.35, clampf(swing.elapsed / maxf(swing.recovery_duration, 0.001), 0, 1))
	else:
		sword_pivot.rotation.y = -0.35
	shield_mesh.position = Vector3(-0.35, 1.0, -0.55 if shield_raised else -0.05)
	if busy() and active_swing().shield_bash:
		var shield_attack = active_swing()
		if shield_attack.state == bash.STARTUP:
			shield_mesh.position.z = lerpf(-0.35, -0.15, clampf(shield_attack.elapsed / maxf(shield_attack.startup_duration, 0.001), 0, 1))
		elif shield_attack.state == shield_attack.ACTIVE:
			shield_mesh.position.z = lerpf(-0.15, -1.0, shield_attack.elapsed / shield_attack.active_duration)
		else:
			shield_mesh.position.z = lerpf(-1.0, -0.35, clampf(shield_attack.elapsed / maxf(shield_attack.recovery_duration, 0.001), 0, 1))
	shield_material.albedo_color = Color.WHITE if shield_flash > 0.0 else (Color("e6ce55") if shield_state() == "PERFECT BLOCK" else Color("577db8"))
	for swing in chain.attacks:
		swing.debug_update(debug_enabled)
	bash.debug_update(debug_enabled)
	heavy.debug_update(debug_enabled)
	feint.debug_update(debug_enabled)

	defense_debug.visible = debug_enabled and shield_raised
func reset_combat() -> void:
	chain.reset()
	feint.state = feint.IDLE
	feint_recovery_remaining = 0.0
	bash_soft_feint = false
	bash.state = bash.IDLE
	heavy.state = heavy.IDLE
	defense(false)
	freeze_remaining = 0.0
	recovery_remaining = 0.0
	hold_movement_this_tick = false
func debug_text() -> String:
	var extra := "GUARD-BREAK FEINT BASH" if feint.busy() else ("QUICK BASH" if bash.busy() else "PRIMARY")
	return "SWORD & SHIELD | %s | Shield %s\n%s" % [extra, shield_state(), grammar_text() + "\n" + chain.debug_text(active_swing())]

func reset_combo() -> void:
	chain.reset()