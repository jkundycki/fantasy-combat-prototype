extends SceneTree

var failures: int = 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func ticks(count: int) -> void:
	for index in range(count):
		await physics_frame
func action(name: String, pressed: bool = true) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	var arena = load("res://sandbox/arena.tscn").instantiate()
	preload("res://tests/baseline_tuning.gd").apply(arena)
	root.add_child(arena)
	var player = arena.get_node("Player")
	arena.get_node("TestEnemy").ai_enabled = false
	await ticks(100)
	check(player.is_on_floor(), "Player must land")
	Input.action_press("move_forward")
	await ticks(15)
	check(player.velocity.z < -8.5, "Ground acceleration must remain responsive")
	Input.action_press("move_right")
	await ticks(15)
	check(Vector2(player.velocity.x, player.velocity.z).length() <= player.move_speed + 0.01, "Diagonal speed must be normalized")
	Input.action_release("move_forward")
	Input.action_release("move_right")
	await ticks(15)
	check(Vector2(player.velocity.x, player.velocity.z).length() < 0.01, "Ground input release must brake")
	player.camera_rig.rotation.y = PI / 2
	Input.action_press("move_forward")
	await ticks(15)
	check(player.velocity.x < -8.5, "Ground steering must follow camera yaw")
	Input.action_release("move_forward")
	await ticks(15)
	player.global_position = Vector3(0, 0.05, 3)
	player.camera_rig.rotation.y = 0.0
	await ticks(10)
	Input.action_press("move_forward")
	await ticks(15)
	action("mobility")
	await ticks(3)
	check(player.dodge_remaining > 0 and player.velocity.z < -17.5, "Mobility must retain dodge")
	await ticks(50)
	check(absf(player.velocity.z + player.move_speed) < 0.1 and player.movement_state() == "NORMAL", "Holding mobility must not enable sprint or repeat dodge")
	action("mobility", false)
	player.jump_buffer_time = 0.0
	player.coyote_time = 0.0
	action("jump")
	await ticks(3)
	check(player.velocity.y > 0 and not player.is_on_floor(), "Zero forgiveness must still allow immediate jump")
	var launch_z: float = player.velocity.z
	player.camera_rig.rotation.y = PI
	await ticks(12)
	check(player.velocity.z < -8.5 and absf(player.velocity.z - launch_z) < 0.2, "180-degree camera turn must not reverse jump trajectory even with forward input held")
	check(absf(angle_difference(player.visual.global_rotation.y, PI)) < 0.01, "Airborne facing must follow camera independently")
	check(player.weapon_set.primary(), "Airborne primary should be available")
	await ticks(3)
	check(absf(angle_difference(player.weapon_set.sword.locked_yaw, PI)) < 0.01 and player.velocity.z < -8.0, "Airborne attack must use new facing and retain original momentum")
	Input.action_release("move_forward")
	action("jump", false)
	await ticks(100)
	player.global_position = Vector3(0, 0.3, 3)
	player.velocity = Vector3(0, -3, 0)
	player.jump_buffer_time = 0.15
	await ticks(3)
	action("jump")
	await ticks(14)
	check(player.velocity.y > 0, "Buffered landing jump must work")
	action("jump", false)
	await ticks(100)
	player.coyote_time = 0.08
	await ticks(3)
	player.global_position.y = 0.5
	await ticks(3)
	action("jump")
	await ticks(3)
	check(player.velocity.y > 0, "Coyote jump must remain available")
	action("jump", false)
	if failures == 0:
		print("PASS: ground acceleration/braking/diagonals/camera, dodge without sprint, jumping/buffer/coyote, independent air momentum and facing, airborne attack")
	quit(1 if failures else 0)