extends SceneTree
const Impact = preload("res://sandbox/incoming_attack.gd")
const Projectile = preload("res://sandbox/fireball.gd")
const Enemy = preload("res://sandbox/test_enemy.gd")
var failures: int = 0
var player
var weapon
var arena
var caster
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func ticks(count: int) -> void:
	for index in range(count):
		await physics_frame
func mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	Input.parse_input_event(event)
func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_CTRL
	event.location = KEY_LOCATION_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
func raise_at(yaw: float) -> void:
	key(false)
	weapon.freeze_remaining = 0
	await ticks(2)
	player.camera_rig.rotation.y = yaw
	key(true)
	await ticks(2)
func launch(position: Vector3, direction: Vector3):
	var shot = Projectile.new()
	shot.attacker = caster
	shot.impact = Impact.new()
	shot.impact.damage = 12
	shot.impact.blockable = true
	shot.impact.reflectable = true
	arena.add_child(shot)
	shot.global_position = position
	shot.direction = direction
	return shot
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	arena = load("res://sandbox/arena.tscn").instantiate()
	root.add_child(arena)
	player = arena.get_node("Player")
	weapon = player.weapon_set
	caster = arena.get_node("TestEnemy")
	caster.ai_enabled = false
	await ticks(100)
	caster.set_physics_process(false)
	caster.global_position = Vector3(0, 0.05, -2)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.global_position = Vector3(0, 0.05, 3)
	player.velocity = Vector3.ZERO
	await ticks(10)
	mouse(true)
	player.camera_rig.rotation.y = 0.7
	Input.action_press("move_right")
	await ticks(3)
	check(Input.is_action_pressed("camera_facing") and not weapon.defense_held and weapon.shield_state() == "DOWN", "RMB must provide facing without raising shield")
	check(absf(angle_difference(player.visual.global_rotation.y, 0.7)) < 0.01, "RMB must retain camera-facing while moving")
	key(true)
	await ticks(2)
	check(Input.is_action_pressed("camera_facing") and weapon.defense_held and weapon.shield_state() == "PERFECT BLOCK", "RMB and Ctrl must operate simultaneously")
	key(false)
	await ticks(2)
	check(weapon.shield_state() == "DOWN" and Input.is_action_pressed("camera_facing"), "Releasing Ctrl must lower shield without cancelling RMB facing")
	Input.action_release("move_right")
	mouse(false)
	player.global_position = Vector3(0, 0.05, 3)
	player.velocity = Vector3.ZERO
	await ticks(10)
	mouse(true)
	await raise_at(deg_to_rad(40))
	var outgoing: Vector3 = -player.visual.global_basis.z
	var other = Enemy.new()
	other.ai_enabled = false
	other.name = "OtherEnemy"
	arena.add_child(other)
	other.set_physics_process(false)
	other.global_position = Vector3(0, 0.05, 2.65) + outgoing * 3.0
	other.global_position.y = 0.05
	var shot = launch(Vector3(0, 1, 2.2), Vector3.BACK)
	shot.speed = 7.5 # Reflect must use stored original 5, not this current speed.
	await ticks(12)
	check(is_instance_valid(shot) and shot.reflected and shot.direction.distance_to(outgoing) < 0.001, "Reflection must exactly match character forward, not caster position")
	check(shot.base_speed == 5.0 and shot.speed == 10.0, "Reflection speed must be base speed times configurable 2x, not compounded current speed")
	check(shot.attacker == player, "Reflection must transfer damage source to player")
	check(player.health == 100, "Reflected projectile must not hit player on contact")
	var committed: Vector3 = shot.direction
	player.camera_rig.rotation.y = -1.0
	await ticks(3)
	check(shot.direction == committed, "Later facing changes must not steer an already reflected shot")
	await ticks(100)
	check(other.health == 88 and caster.health == 100, "Reflected shot must hit another enemy along facing without targeting caster")
	other.queue_free()
	await ticks(2)
	await raise_at(PI / 2)
	shot = launch(Vector3(-0.8, 1, 3), Vector3.RIGHT)
	await ticks(12)
	check(is_instance_valid(shot) and shot.reflected and shot.direction.distance_to(Vector3.LEFT) < 0.001, "Side-facing reflect must travel sideways when projectile approaches frontal arc")
	await ticks(20)
	check(is_instance_valid(shot) and shot.global_position.x < -1.0 and caster.health == 100, "Reflected projectile aimed into empty space must be allowed to miss")
	shot.queue_free()
	await raise_at(PI / 2)
	var before: float = player.health
	shot = launch(Vector3(0, 1, 2.2), Vector3.BACK)
	await ticks(12)
	check(player.health == before - 12 and not is_instance_valid(shot), "Turning outside defensive arc must not bypass existing eligibility")
	key(false)
	mouse(false)
	# Controller defense and right-stick camera remain independent of RMB/Ctrl.
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_LEFT_SHOULDER
	button.pressed = true
	Input.parse_input_event(button)
	await ticks(3)
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	await ticks(5)
	check(weapon.defense_held and absf(angle_difference(player.visual.global_rotation.y, player.camera_rig.global_rotation.y)) < 0.1, "Controller LB defense must preserve right-stick camera-facing")
	stick = InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 0
	Input.parse_input_event(stick)
	button = InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_LEFT_SHOULDER
	button.pressed = false
	Input.parse_input_event(button)
	await ticks(2)
	check(not weapon.defense_held, "Controller release must lower defense")
	if failures == 0:
		print("PASS: actual RMB/Ctrl input independence, preserved RMB facing, directional reflection, ownership, collision safety, another-enemy hit, empty-space miss, defensive arc preserved, controller defense/look")
	quit(1 if failures else 0)