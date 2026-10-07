extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	var arena = load("res://sandbox/arena.tscn").instantiate()
	root.add_child(arena)
	var player = arena.get_node("Player")
	var enemy = arena.get_node("TestEnemy")
	enemy.ai_enabled = false
	for i in range(100):
		await physics_frame
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	enemy.global_position = Vector3(15, 0, 15)
	arena.get_node("TrainingDummy").global_position = Vector3(15, 1, 15)
	Input.action_press("camera_facing")
	player.camera_rig.rotation.y = 0.7
	Input.action_release("camera_facing")
	var hud = arena.get_node("MovementDebug/CombatHUD")
	player.health = 73
	enemy.health = 41
	hud._process(0)
	check(hud.player_bar.value == 73 and hud.opponent_bar.value == 41, "HUD follows both current health values")
	arena.get_node("MovementDebug/State").hide()
	check(hud.is_visible_in_tree(), "Health feedback survives F3 debug visibility")
	check(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD cannot capture combat clicks")
	var mannequin = player.visual.get_node("Humanoid")
	player.stagger_remaining = 0.5
	mannequin._process(0)
	check(mannequin.pose == "STAGGER" and mannequin.torso.rotation.x > 0, "Readable player stagger pose")
	var opponent_model = enemy.visual.get_node("Humanoid")
	enemy.state = "PARRY_WINDOW"
	opponent_model._process(0)
	check(opponent_model.pose == "PARRY_WINDOW" and opponent_model.right_arm.rotation.x < -1, "Readable opponent parry pose")
	if failures == 0:
		print("PASS: HUD health/debug independence, humanoid combat poses")
	quit(1 if failures else 0)
