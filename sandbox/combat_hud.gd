extends Control
# Player HUD and one projected opponent panel; no duplicate fixed enemy bars.
@export var opponent_head_height: float = 2.1
var player
var opponent
var player_bar: ProgressBar
var opponent_bar: ProgressBar
var player_health: Label
var opponent_health: Label
var player_action: Label
var opponent_action: Label
var feedback: Label
var player_guard: ProgressBar
var opponent_guard: ProgressBar
var player_guard_value: Label
var opponent_guard_value: Label
var player_guard_panel: VBoxContainer
var opponent_guard_panel: VBoxContainer
var opponent_panel: VBoxContainer
var opponent_title: Label
var player_panel: VBoxContainer
var roll_timer: Label

func panel(width: float) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size.x = width
	box.size.x = width
	add_child(box)
	return box

func label_in(box: VBoxContainer, font_size: int = 18) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	box.add_child(label)
	return label

func bar_in(box: VBoxContainer, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 16
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.04, 0.04, 0.9)
	background.border_width_left = 1
	background.border_width_right = 1
	background.border_width_top = 1
	background.border_width_bottom = 1
	background.border_color = Color(0.8, 0.8, 0.8, 0.7)
	bar.add_theme_stylebox_override("background", background)
	box.add_child(bar)
	return bar

func guard_panel(box: VBoxContainer) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(group)
	return group

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player = get_node("../../Player")
	opponent = get_node("../../TestEnemy")
	var p := panel(340)
	player_panel = p
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	p.offset_left = 20
	p.offset_top = -180
	p.offset_right = 360
	p.offset_bottom = -20
	player_health = label_in(p)
	player_bar = bar_in(p, Color("da4f4f"))
	player_guard_panel = guard_panel(p)
	player_guard_value = label_in(player_guard_panel)
	player_guard = bar_in(player_guard_panel, Color("4bc775"))
	player_action = label_in(p, 16)
	player_action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback = label_in(p, 20)
	feedback.modulate = Color("ffcf71")
	opponent_panel = panel(210)
	opponent_title = label_in(opponent_panel, 15)
	opponent_health = label_in(opponent_panel, 14)
	opponent_bar = bar_in(opponent_panel, Color("da4f4f"))
	opponent_guard_panel = guard_panel(opponent_panel)
	opponent_guard_value = label_in(opponent_guard_panel, 14)
	opponent_guard = bar_in(opponent_guard_panel, Color("4bc775"))
	opponent_action = label_in(opponent_panel, 15)
	var roll_box := PanelContainer.new()
	roll_box.name = "RollCooldown"
	roll_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(roll_box)
	roll_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	roll_box.offset_left = -52
	roll_box.offset_right = 52
	roll_box.offset_top = -88
	roll_box.offset_bottom = -20
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.05, 0.07, 0.9)
	background.set_border_width_all(2)
	background.border_color = Color("748294")
	roll_box.add_theme_stylebox_override("panel", background)
	roll_timer = Label.new()
	roll_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roll_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roll_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	roll_timer.add_theme_font_size_override("font_size", 18)
	roll_box.add_child(roll_timer)
	call_deferred("bind_values")

func bind_values() -> void:
	player.health_changed.connect(update_values)
	opponent.health_changed.connect(update_values)
	player.get_node("SwordShield/Guard").changed.connect(update_values)
	opponent.guard.changed.connect(update_values)
	update_values()

func update_values() -> void:
	player_bar.max_value = player.max_health
	player_bar.value = player.health
	opponent_bar.max_value = opponent.max_health
	opponent_bar.value = opponent.health
	player_health.text = "HEALTH  %.0f / %.0f" % [player.health, player.max_health]
	opponent_health.text = "%.0f / %.0f HP" % [opponent.health, opponent.max_health]
	var guard = player.get_node("SwordShield/Guard")
	player_guard_panel.visible = player.weapon_set == player.get_node("SwordShield")
	player_guard.max_value = guard.max_guard
	player_guard.value = guard.current
	player_guard_value.text = "GUARD  %.0f / %.0f" % [guard.current, guard.max_guard]
	opponent_guard_panel.visible = opponent.has_shield_guard()
	opponent_guard.max_value = opponent.guard.max_guard
	opponent_guard.value = opponent.guard.current
	opponent_guard_value.text = "%.0f / %.0f Guard" % [opponent.guard.current, opponent.guard.max_guard]

func _process(_delta: float) -> void:
	var remaining: float = maxf(player.cooldown_remaining, 0.0)
	roll_timer.text = "ROLL\n%.1f s" % (ceilf(remaining * 10.0) / 10.0) if remaining > 0.0 else "ROLL\nREADY"
	roll_timer.modulate = Color("ffcf71") if remaining > 0.0 else Color("78df94")
	update_values() # Also covers Inspector max-health edits and weapon changes.
	var full_debug: bool = get_node("../State").debug_enabled
	player_panel.offset_top = -280 if full_debug else -180
	var weapon = player.weapon_set
	var swing = weapon.active_swing()
	player_action.text = str(weapon.name).to_upper() + " | "
	if player.health <= 0:
		player_action.text += "DEAD / RESETTING"
	elif player.guard_broken():
		player_action.text += "\nGUARD BREAK | STAGGERED %.2f s" % player.get_node("SwordShield/Guard").stun_remaining
	elif player.stagger_remaining > 0:
		player_action.text += "STAGGERED"
	elif swing.busy() or weapon.feint_recovery_remaining > 0:
		player_action.text += weapon.grammar_text()
		if swing.can_feint():
			player_action.text += "
Bash: F/RB | Cancel: R/R3"
	else:
		player_action.text += weapon.shield_state() if weapon.has_method("shield_state") and weapon.shield_raised else (weapon.parry_state if not weapon.has_method("shield_state") and weapon.parry_state != "DOWN" else player.movement_state())
		if weapon.has_method("shield_state"):
			player_action.text += "
" + weapon.guard.debug_text()
	feedback.text = "GUARD BREAK" if player.guard_broken() else (weapon.last_event if weapon.event_remaining > 0 else "")
	if not full_debug:
		player_action.text = "SWORD & SHIELD" if weapon.has_method("shield_state") else str(weapon.name).to_upper()
		feedback.text = "GUARD BREAK" if player.guard_broken() else (weapon.last_event if weapon.event_remaining > 0 and weapon.last_event in ["PARRY", "SPELL REFLECT"] else "")
	opponent_title.text = "SPARRING | " + opponent.weapon_label()
	opponent_title.text += "\n" + ("MIRROR" if opponent.mirror_weapon else "MANUAL") + (" | ALL_OUT" if opponent.personality == 6 else "")
	opponent_action.text = "GUARD BREAK\nSTAGGERED %.2f s" % opponent.guard.stun_remaining if opponent.guard_broken() else opponent.state.replace("_", " ")
	if not full_debug:
		opponent_action.text = "GUARD BREAK" if opponent.guard_broken() else (opponent.state.replace("_", " ") if opponent.state in ["BLOCK", "PARRY_WINDOW", "STAGGER"] else "")
	opponent_action.modulate = Color("ff80de") if opponent.guard_broken() else (Color.CYAN if "PARRY" in opponent.state else Color.WHITE)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		opponent_panel.hide()
		return
	var head: Vector3 = opponent.global_position + Vector3(0, opponent_head_height, 0)
	opponent_panel.visible = not camera.is_position_behind(head)
	if opponent_panel.visible:
		var screen := camera.unproject_position(head)
		opponent_panel.position = screen - Vector2(opponent_panel.size.x / 2, opponent_panel.size.y + 8)
