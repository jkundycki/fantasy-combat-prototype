extends Node3D

@export var mouse_sensitivity: float = 0.0025
@export_range(-89.0, 0.0) var minimum_pitch_degrees: float = -65.0
@export_range(0.0, 89.0) var maximum_pitch_degrees: float = 65.0
@export var camera_distance: float = 5.5
@onready var pitch_pivot: Node3D = $Pitch
@onready var spring_arm: SpringArm3D = $Pitch/SpringArm3D

func _ready() -> void:
	Input.use_accumulated_input = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.spring_length = camera_distance
	spring_arm.add_excluded_object((get_parent() as CollisionObject3D).get_rid())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_action_pressed("primary") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		pitch_pivot.rotation.x = clampf(
			pitch_pivot.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(minimum_pitch_degrees), deg_to_rad(maximum_pitch_degrees))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

@export var controller_look_speed: float = 2.8

func _process(delta: float) -> void:
	var axis := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	rotation.y -= axis.x * controller_look_speed * delta
	pitch_pivot.rotation.x = clampf(pitch_pivot.rotation.x - axis.y * controller_look_speed * delta, deg_to_rad(minimum_pitch_degrees), deg_to_rad(maximum_pitch_degrees))