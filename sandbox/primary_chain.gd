extends Node

@export var combo_timeout: float = 0.65
@export_range(0.0, 1.0) var buffer_recovery_fraction: float = 0.35
var attacks: Array = []
var step: int = 0
var next_step: int = 0
var buffered: bool = false
var buffered_heavy: bool = false
var reset_remaining: float = 0.0
var running: bool = false
var reset_after_swing: bool = false
@onready var weapon = get_parent()

func primary() -> bool:
	if running:
		var swing = attacks[step]
		if step < attacks.size() - 1 and swing.state == swing.RECOVERY and swing.elapsed >= swing.recovery_duration * buffer_recovery_fraction and not reset_after_swing:
			buffered_heavy = false
			buffered = true # One slot; extra presses never queue extra attacks.
			return true
		return false
	if not weapon.begin_swing(attacks[next_step]):
		return false
	step = next_step
	running = true
	buffered_heavy = false
	buffered = false
	reset_after_swing = false
	reset_remaining = 0.0
	return true

func active():
	return attacks[step] if running else attacks[0]

func busy() -> bool:
	return running and attacks[step].busy()

func tick(delta: float) -> void:
	if not running:
		reset_remaining = maxf(0, reset_remaining - delta)
		if reset_remaining <= 0:
			next_step = 0
		return
	attacks[step].tick(delta)
	if not running:
		return # A parry/interrupt may reset us inside the hit query.
	if attacks[step].busy():
		return
	var continue_heavy := buffered_heavy and not reset_after_swing and step == 1
	var continue_chain := buffered and not reset_after_swing and step < attacks.size() - 1
	running = false
	buffered_heavy = false
	buffered = false
	next_step = 0 if reset_after_swing or step == attacks.size() - 1 else step + 1
	reset_remaining = combo_timeout if next_step > 0 else 0.0
	if continue_heavy:
		reset()
		weapon.begin_swing(weapon.heavy)
	elif continue_chain:
		primary() # Only after the preceding attack's entire recovery completes.

func cancel_continuation() -> void:
	buffered_heavy = false
	buffered = false
	reset_after_swing = true
	next_step = 0
	reset_remaining = 0

func reset() -> void:
	for swing in attacks:
		swing.state = swing.IDLE
	running = false
	buffered_heavy = false
	buffered = false
	step = 0
	next_step = 0
	reset_remaining = 0
	reset_after_swing = false

func debug_text(swing_override = null) -> String:
	var swing = swing_override if swing_override != null else active()
	return "Combo %d/3 | Buffered Light %s / Heavy %s | Reset %.2f s\n%s | Feint %s | Facing locked %s\nTiming %.2f / %.2f / %.2f | Guard-break %s" % [step + 1 if running else next_step + 1, buffered, buffered_heavy, reset_remaining, swing.state, swing.can_feint() if busy() else false, swing.facing_committed() if busy() else false, swing.startup_duration, swing.active_duration, swing.recovery_duration, swing.guard_break]
# Same single recovery buffer as Primary; the latest valid choice wins.
func queue_heavy() -> bool:
	if step != 1 or reset_after_swing:
		return false
	var swing = attacks[step]
	if swing.state != swing.RECOVERY or swing.elapsed < swing.recovery_duration * buffer_recovery_fraction:
		return false
	buffered = false
	buffered_heavy = true
	return true
