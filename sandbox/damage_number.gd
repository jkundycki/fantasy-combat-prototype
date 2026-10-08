extends Label3D
@export var lifetime: float = 0.8
@export var rise_distance: float = 0.55
var amount: float = 0.0
var target: Node3D
var world_offset := Vector3(0, 2.05, 0)
var elapsed: float = 0.0

static func show_damage(actor: Node3D, actual_loss: float, height: float = 2.05) -> void:
	if actual_loss <= 0:
		return
	var number = load("res://sandbox/damage_number.gd").new()
	number.target = actor
	number.amount = actual_loss
	var index: int = actor.get_meta("damage_number_index", 0)
	actor.set_meta("damage_number_index", index + 1)
	number.world_offset = Vector3((index % 5 - 2) * 0.3, height + (index % 3) * 0.08, 0)
	actor.get_parent().add_child(number)

func _ready() -> void:
	add_to_group("damage_numbers")
	text = ("%.2f" % amount).rstrip("0").rstrip(".")
	font_size = 48
	pixel_size = 0.004
	outline_size = 12
	outline_modulate = Color.BLACK
	modulate = Color("ffe3a3")
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	shaded = false
	global_position = target.global_position + world_offset

func _process(delta: float) -> void:
	elapsed += delta
	if not is_instance_valid(target) or elapsed >= lifetime:
		queue_free()
		return
	global_position = target.global_position + world_offset + Vector3.UP * rise_distance * elapsed / lifetime
	modulate.a = 1.0 - clampf(elapsed / lifetime, 0, 1)
