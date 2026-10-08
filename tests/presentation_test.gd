extends SceneTree
const Feedback = preload("res://sandbox/combat_feedback.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	var arena = load("res://sandbox/arena.tscn").instantiate()
	preload("res://tests/baseline_tuning.gd").apply(arena)
	root.add_child(arena)
	var player = arena.get_node("Player")
	var enemy = arena.get_node("TestEnemy")
	enemy.ai_enabled = false
	for i in range(100):
		await physics_frame
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	enemy.global_position = Vector3(15, 0.05, 15)
	arena.get_node("TrainingDummy").global_position = Vector3(15, 1, 15)
	var debug = arena.get_node("MovementDebug/State")
	var hud = arena.get_node("MovementDebug/CombatHUD")
	check(not debug.debug_enabled and not debug.visible, "Startup defaults to Playtest")
	for weapon in player.weapon_sets:
		check(not weapon.debug_enabled, "Both weapons default to hidden diagnostics")
	var floor = arena.get_node("Floor")
	check(floor.get_child(1).shape.size == Vector3(40, 1, 40) and floor.position == Vector3(0, -0.5, 0), "Presentation preserves floor collision")
	check(arena.get_node("LowPlatform").position == Vector3(-5, 0.3, -5) and arena.get_node("Pillar").position == Vector3(7, 1.5, -4), "Traversal/test layout preserved")
	var weapon = player.weapon_set
	weapon.heavy_attack()
	hud._process(0)
	check(not hud.player_action.text.contains("HEAVY_STARTUP") and hud.player_bar.visible, "Default HUD hides instrumentation but keeps essentials")
	var event := InputEventAction.new()
	event.action = "combat_debug"
	event.pressed = true
	debug._unhandled_input(event)
	hud._process(0)
	check(debug.visible and weapon.heavy.debug_mesh.visible and hud.player_action.text.contains("HEAVY_STARTUP"), "F3 restores full instrumentation and hitbox")
	debug._unhandled_input(event)
	check(not debug.visible and not weapon.heavy.debug_mesh.visible and hud.is_visible_in_tree(), "F3 returns to clean view without hiding HUD")
	weapon.reset_combat()
	# Impact cues are presentation only and self-clean.
	var before: float = player.health
	var guard_before: float = weapon.guard.current
	for cue in ["hit", "heavy", "block", "parry", "reflect", "guard_break"]:
		Feedback.impact(player, cue)
	check(player.health == before and weapon.guard.current == guard_before and not weapon.busy(), "Effects have no health/resource/combat authority")
	check(get_nodes_in_group("combat_effects").size() == 6, "Every requested impact has its own visible cue")
	for effect in get_nodes_in_group("combat_effects"):
		effect._process(effect.lifetime + 0.01)
		check(effect.is_queued_for_deletion(), "Impact lifetime frees itself")
	for cue in Feedback.SOUNDS:
		check(Feedback.SOUNDS[cue].get_length() > 0 and Feedback.SOUNDS[cue].get_length() < 0.5, "Short local audio is present")
	# Actual active blade path produces a ribbon; reset removes it.
	player.weapon_set = player.get_node("Greatsword")
	weapon = player.weapon_set
	weapon.visible = true
	weapon.reset_combat()
	weapon.primary()
	var trail = weapon.blade_pivot.get_child(1)
	weapon.tick(0.23)
	trail._process(0.01)
	weapon.tick(0.02)
	trail._process(0.01)
	check(trail.tips.size() >= 2 and trail.ribbon.get_surface_count() > 0, "Active weapon motion builds visible trail")
	weapon.reset_combat()
	trail._process(0.01)
	check(trail.tips.is_empty() and trail.ribbon.get_surface_count() == 0, "Interrupted/idle swings cannot leave trails")
	if failures == 0:
		print("PASS: default Playtest/F3 separation, preserved collision layout, feedback no gameplay authority/lifetime, local audio assets, active blade trails/reset")
	quit(1 if failures else 0)
