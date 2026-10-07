extends SceneTree

const Impact = preload("res://sandbox/incoming_attack.gd")
var failures: int = 0
var player
var weapon
var dummy
var enemy
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
func pose(distance: float, angle: float = 0.0) -> void:
	weapon.reset_combo()
	player.global_position = Vector3(0, 0.05, 3)
	player.velocity = Vector3.ZERO
	player.camera_rig.rotation.y = 0.0
	dummy.global_position = Vector3(sin(deg_to_rad(angle)) * distance, 0.9, 3 - cos(deg_to_rad(angle)) * distance)
	dummy.health = dummy.max_health
	await ticks(10)
	player.visual.rotation.y = 0.0
func swing(name: String = "primary") -> void:
	action(name)
	await ticks(2)
	action(name, false)
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	var arena = load("res://sandbox/arena.tscn").instantiate()
	root.add_child(arena)
	player = arena.get_node("Player")
	weapon = player.weapon_set
	dummy = arena.get_node("TrainingDummy")
	enemy = arena.get_node("TestEnemy")
	enemy.ai_enabled = false
	await ticks(100)
	await pose(1.5)
	await swing()
	check(weapon.sword.state == weapon.sword.STARTUP and dummy.health == 100, "Sword startup must not damage")
	check(not weapon.primary() and not weapon.special(), "Committed swing must reject spam and bash chaining")
	await ticks(60)
	check(dummy.health == 75 and weapon.sword.hit_targets.size() == 1, "Primary hits once per swing")
	for scenario in [[1.5, 35.0, 75.0], [1.5, 90.0, 100.0], [1.5, 180.0, 100.0], [3.2, 0.0, 100.0]]:
		await pose(scenario[0], scenario[1])
		await swing()
		await ticks(60)
		check(dummy.health == scenario[2], "Sword must respect facing/arc/range")
	await pose(1.5)
	dummy.global_position.y = 4
	await swing()
	await ticks(60)
	check(dummy.health == 100, "Sword must respect vertical separation")
	await pose(1.8)
	await swing("special")
	await ticks(60)
	check(dummy.health == 100, "Bash must have shorter reach than sword")
	await pose(1.0)
	await swing("special")
	await ticks(60)
	check(dummy.health == 92, "Bash must deal modest damage")
	await pose(1.8)
	var wall = arena.box("TestWall", Vector3(0, 1, 2.1), Vector3(3, 2, 0.2), Color.GRAY)
	await ticks(3)
	await swing()
	await ticks(60)
	check(dummy.health == 100, "Solid walls must block sword hits")
	wall.queue_free()
	await ticks(3)
	await pose(1.5)
	await swing()
	Input.action_press("move_right")
	await ticks(10)
	check(absf(player.visual.rotation.y) < 0.01, "Swing must lock facing by default")
	check(player.velocity.x <= player.move_speed * weapon.sword.movement_multiplier + 0.01, "Swing must reduce ground movement")
	Input.action_release("move_right")
	await ticks(60)
	await pose(1.0)
	dummy.global_position = Vector3(-10, 0.9, 10)
	enemy.global_position = Vector3(0, 0.05, 2)
	enemy.health = 100
	enemy.state = "MELEE_STARTUP"
	await ticks(3)
	await swing("special")
	await ticks(20)
	check(enemy.health == 92 and enemy.state == "STAGGER" and enemy.stagger_remaining > 0, "Bash must interrupt enemy startup with stagger")
	await ticks(100)
	enemy.global_position = Vector3(8, 0.05, -4)
	await pose(1.5)
	dummy.health = 25
	await swing()
	await ticks(20)
	check(dummy.health == 0, "Sword must kill dummy")
	await ticks(100)
	check(dummy.health == 100, "Dummy must reset")
	if failures == 0:
		print("PASS: sword phases/single hits/misses/range/arc/height/walls, commitment/movement, bash damage/short reach/stagger interrupt, dummy reset")
	quit(1 if failures else 0)