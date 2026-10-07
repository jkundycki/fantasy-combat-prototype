extends Control
# Always-visible test HUD; F3 independently controls the detailed diagnostics.
var player
var opponent
var player_bar: ProgressBar
var opponent_bar: ProgressBar
var player_health: Label
var opponent_health: Label
var player_action: Label
var opponent_action: Label
var feedback: Label

func panel(title: String, right: bool, bottom: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT if bottom else Control.PRESET_TOP_RIGHT)
	box.position = Vector2(-340, 20) if right else Vector2(20, -140)
	box.custom_minimum_size.x = 320
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 22)
	box.add_child(label)
	return box

func label_in(box: VBoxContainer) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 18)
	box.add_child(label)
	return label

func bar_in(box: VBoxContainer, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(320, 20)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	bar.add_theme_stylebox_override("fill", style)
	box.add_child(bar)
	return bar

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player = get_node("../../Player")
	opponent = get_node("../../TestEnemy")
	var p := panel("PLAYER", false, true)
	player_health = label_in(p)
	player_bar = bar_in(p, Color("409fdf"))
	player_action = label_in(p)
	var e := panel("SPARRING OPPONENT", true, false)
	opponent_health = label_in(e)
	opponent_bar = bar_in(e, Color("df6755"))
	opponent_action = label_in(e)
	feedback = label_in(e)

func _process(_delta: float) -> void:
	player_bar.max_value = player.max_health
	player_bar.value = player.health
	opponent_bar.max_value = opponent.max_health
	opponent_bar.value = opponent.health
	player_health.text = "%.0f / %.0f" % [player.health, player.max_health]
	opponent_health.text = "%.0f / %.0f" % [opponent.health, opponent.max_health]
	var weapon = player.weapon_set
	var swing = weapon.active_swing()
	player_action.text = str(weapon.name).to_upper() + " | "
	if player.health <= 0:
		player_action.text += "DEAD / RESETTING"
	elif player.stagger_remaining > 0:
		player_action.text += "STAGGERED"
	elif swing.busy():
		player_action.text += weapon.grammar_text()
		if swing.can_feint():
			player_action.text += "\nBash: F/RB | Cancel: R/R3"
	elif weapon.feint_recovery_remaining > 0:
		player_action.text += weapon.grammar_text()
	else:
		player_action.text += weapon.shield_state() if weapon.has_method("shield_state") and weapon.shield_raised else (weapon.parry_state if not weapon.has_method("shield_state") and weapon.parry_state != "DOWN" else player.movement_state())
	var enemy_state: String = opponent.state
	opponent_action.text = enemy_state.replace("_", " ")
	opponent_action.modulate = Color.CYAN if "PARRY" in enemy_state else (Color("ffd36c") if "STARTUP" in enemy_state else Color.WHITE)
	feedback.text = weapon.last_event if weapon.event_remaining > 0 else ""
