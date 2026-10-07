extends Label

@export var player_path: NodePath = NodePath("../../Player")
@onready var player = get_node(player_path)
@onready var dummy = get_node("../../TrainingDummy")
@onready var enemy = get_node("../../TestEnemy")
var debug_enabled: bool = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("combat_debug") and not event.is_echo():
		debug_enabled = not debug_enabled
		visible = debug_enabled
		player.weapon_set.debug_enabled = debug_enabled
		enemy.debug_enabled = debug_enabled
		player.weapon_set.update_visuals()
		enemy.update_visuals()

func _process(_delta: float) -> void:
	var weapon = player.weapon_set
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var properties := "none"
	for projectile in get_tree().get_nodes_in_group("test_projectiles"):
		properties = "block:%s parry:%s reflect:%s reflected:%s" % [projectile.impact.blockable, projectile.impact.parryable, projectile.impact.reflectable, projectile.reflected]
		break
	text = "%s | %.1f m/s | Player %.0f HP\n%s\nEnemy: %s | %.0f HP | Stagger %.2f s\nDummy: %.0f HP\nProjectile: %s\n%s\nF3 debug | Q/Y switch | LMB/X primary | E/RT heavy | F/RB bash | R/R3 cancel\nLeft Ctrl/LB defense | RMB facing" % [player.movement_state(), speed, player.health, weapon.debug_text(), enemy.state, enemy.health, enemy.stagger_remaining, dummy.health, properties, weapon.last_event if weapon.event_remaining > 0 else ""]
	text += "\nGuard fixture: %s | Player stagger %.2f s" % [["OFF", "BLOCK", "PARRY" ][enemy.test_guard_mode], player.stagger_remaining]

	text += "\n" + enemy.ai_debug_text()
