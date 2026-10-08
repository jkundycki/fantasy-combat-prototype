extends Node
# One shield resource shared by player and training opponent; no movement costs.
signal changed
signal broken
signal recovered
@export var actor_path: NodePath = NodePath("../..")
@export_range(1.0, 500.0) var max_guard: float = 100.0
@export_range(0.0, 500.0) var starting_guard: float = 100.0
@export_range(0.0, 200.0) var regeneration_rate: float = 12.5
@export_range(0.0, 5.0) var regeneration_delay: float = 2.5
@export_range(0.1, 5.0) var break_stun_duration: float = 3.2
@export_range(0.0, 1.0) var post_break_guard_fraction: float = 0.3
@export_range(0.0, 3.0) var post_break_immunity: float = 1.5
var current: float = 100.0
var delay_remaining: float = 0.0
var stun_remaining: float = 0.0
var immunity_remaining: float = 0.0
var last_damage: float = 0.0
var actor

func _ready() -> void:
	actor = get_node(actor_path)
	broken.connect(actor.on_guard_break)
	recovered.connect(actor.on_guard_recovered)
	reset()

func reset() -> void:
	current = clampf(starting_guard, 0, max_guard)
	delay_remaining = 0
	stun_remaining = 0
	immunity_remaining = 0
	last_damage = 0
	changed.emit()

func is_broken() -> bool:
	return stun_remaining > 0

func absorb(cost: float) -> void:
	if cost <= 0 or is_broken():
		return
	last_damage = minf(current, cost)
	current = maxf(0, current - cost)
	delay_remaining = regeneration_delay
	if current <= 0:
		if immunity_remaining > 0:
			# Brief post-break protection cannot repeatedly extend a stun.
			current = minf(1, max_guard)
		else:
			stun_remaining = break_stun_duration
			broken.emit()
	changed.emit()

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if actor.health <= 0:
		return
	if is_broken():
		stun_remaining = maxf(0, stun_remaining - delta)
		if stun_remaining <= 0:
			current = maxf(current, max_guard * post_break_guard_fraction)
			immunity_remaining = post_break_immunity
			delay_remaining = 0
			recovered.emit()
			changed.emit()
		return
	immunity_remaining = maxf(0, immunity_remaining - delta)
	var regeneration_delta := maxf(0, delta - delay_remaining)
	delay_remaining = maxf(0, delay_remaining - delta)
	if regeneration_delta > 0 and not actor.is_guard_held() and current < max_guard:
		current = minf(max_guard, current + regeneration_rate * regeneration_delta)
		changed.emit()

func debug_text() -> String:
	if is_broken():
		return "GUARD BREAK | STAGGERED %.2f s" % stun_remaining
	if delay_remaining <= 0 and current < max_guard and not actor.is_guard_held():
		return "GUARD REGENERATING"
	return "GUARD %.0f / %.0f | GUARD DAMAGE %.0f | Regen delay %.2f | Protection %.2f" % [current, max_guard, last_damage, delay_remaining, immunity_remaining]
