extends Node3D

const Art = preload("res://prototype_art.gd")
const PATH := [Vector3(-12, 0, -8), Vector3(-6, 0, -8), Vector3(-6, 0, 2), Vector3(1, 0, 2), Vector3(1, 0, -5), Vector3(8, 0, -5), Vector3(8, 0, 8)]
const TREES := [Vector3(-12, 0, 7), Vector3(-12, 0, 4), Vector3(-2, 0, -9), Vector3(11, 0, -9), Vector3(12, 0, 6)]
const CATALOG := {
	"watch": {"name": "Watchtower", "cost": 50, "range": 5.6, "damage": 24.0, "interval": 0.65, "description": "Fast crossbow fire / single target"},
	"bombard": {"name": "Bombard", "cost": 80, "range": 5.0, "damage": 38.0, "interval": 1.65, "description": "Slow cannon fire / splash damage"},
	"hex": {"name": "Hex Obelisk", "cost": 65, "range": 4.6, "damage": 7.0, "interval": 0.9, "description": "Curses one enemy / slows by 45%"}
}
const BUILDER_SPEED := 5.5
const BUILD_TIME := 2.0
const GRID_ORIGIN := Vector3(-13.5, 0, -10.0)
const GRID_STEP := 0.5
var gold := 150
var lives := 20
var wave := 0
var remaining := 0
var spawn_timer := 0.0
var active := false
var finished := false
var selected := -1
var build_kind := ""
var towers: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var pending: Dictionary = {}
var builder_path := PackedVector3Array()
var navigation := AStarGrid2D.new()
var builder: Node3D
var ghost: Node3D
var destination_ring: MeshInstance3D
var range_ring: MeshInstance3D
var camera: Camera3D
var stats: Label
var detail: Label
var status: Label
var builder_status: Label
var action: Button
var cancel_button: Button
var next_wave: Button
var build_buttons: Dictionary = {}
var top_panel: PanelContainer
var bottom_panel: PanelContainer

func _ready() -> void:
	make_world()
	builder = Art.builder(self)
	builder.position = Vector3(-3, 0, 0)
	destination_ring = Art.ring(self, 0.4, Color("d1ba81"))
	destination_ring.visible = false
	range_ring = Art.ring(self, 1, Color("c4b886"))
	range_ring.visible = false
	ghost = Node3D.new()
	add_child(ghost)
	navigation.region = Rect2i(0, 0, 55, 41)
	navigation.cell_size = Vector2.ONE * GRID_STEP
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	rebuild_navigation()
	make_ui()
	refresh_ui()

func make_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("232a2b")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b6bdc1")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color("edddc3")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 37
	camera.v_offset = -2.0
	add_child(camera)
	camera.position = Vector3(21, 29, 26)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	Art.box(self, Vector3(0, -0.45, 0), Vector3(29, 0.8, 23), Color("505849"))
	for i in range(PATH.size() - 1):
		var start: Vector3 = PATH[i]
		var end: Vector3 = PATH[i + 1]
		Art.box(self, (start + end) / 2.0, Vector3(absf(end.x - start.x) + 1.5, 0.12, absf(end.z - start.z) + 1.5), Color("706354"))
	for point in TREES:
		Art.cylinder(self, point + Vector3(0, 0.9, 0), 0.2, 1.8, Color("4e4439"))
		var branch := Art.box(self, point + Vector3(0.3, 1.5, 0), Vector3(1.2, 0.15, 0.15), Color("4e4439"))
		branch.rotation_degrees.z = 35
	Art.box(self, PATH[-1] + Vector3(0, 1, 1), Vector3(3, 2, 2), Color("6b6c65"))
	for offset in [-1.2, 1.2]:
		Art.cylinder(self, PATH[-1] + Vector3(offset, 1.6, 1), 0.5, 3.2, Color("77786f"))
		for tooth in [-0.3, 0.3]:
			Art.box(self, PATH[-1] + Vector3(offset + tooth, 3.35, 1), Vector3(0.24, 0.45, 0.7), Color("77786f"))
	Art.box(self, PATH[-1] + Vector3(0, 0.7, -0.03), Vector3(0.9, 1.4, 0.08), Color("302b28"))
	for x in [-1.0, 1.0]:
		Art.cylinder(self, PATH[-1] + Vector3(x, 1.0, -0.15), 0.1, 0.7, Color("c78e4d"))

func button(parent: Node, text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = Control.FOCUS_NONE
	result.custom_minimum_size.y = 36
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var theme := Theme.new()
	theme.default_font_size = 16
	var style := StyleBoxFlat.new()
	style.bg_color = Color("252725")
	style.border_color = Color("74694e")
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	theme.set_stylebox("panel", "PanelContainer", style)
	top_panel = PanelContainer.new()
	top_panel.theme = theme
	top_panel.position = Vector2(16, 12)
	layer.add_child(top_panel)
	var column := VBoxContainer.new()
	top_panel.add_child(column)
	stats = Label.new()
	stats.add_theme_font_size_override("font_size", 22)
	column.add_child(stats)
	status = Label.new()
	status.text = "Build your defenses. Protect the keep through 10 waves."
	column.add_child(status)
	bottom_panel = PanelContainer.new()
	bottom_panel.theme = theme
	layer.add_child(bottom_panel)
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_left = 16
	bottom_panel.offset_right = -16
	bottom_panel.offset_top = -177
	bottom_panel.offset_bottom = -12
	var controls := VBoxContainer.new()
	bottom_panel.add_child(controls)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	controls.add_child(row)
	var index := 1
	for kind in CATALOG:
		var data: Dictionary = CATALOG[kind]
		var item := button(row, "%d  %s  [%dg]" % [index, data.name, data.cost], choose_build.bind(kind))
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.tooltip_text = data.description
		item.toggle_mode = true
		build_buttons[kind] = item
		index += 1
	action = button(row, "Upgrade", order_upgrade)
	next_wave = button(row, "Start wave", start_wave)
	cancel_button = button(row, "Cancel / Esc", cancel_orders)
	button(row, "Restart", func(): get_tree().reload_current_scene())
	detail = Label.new()
	controls.add_child(detail)
	builder_status = Label.new()
	builder_status.modulate = Color("dec891")
	controls.add_child(builder_status)
	var help := Label.new()
	help.text = "Right-click: move builder  |  1 / 2 / 3: choose tower  |  Left-click: place or select\nEsc: cancel + refund unfinished work  |  Wheel: zoom  |  Space: next wave"
	help.modulate = Color("b9bcb5")
	controls.add_child(help)

func cursor_on_ui() -> bool:
	var point := get_viewport().get_mouse_position()
	return top_panel.get_global_rect().has_point(point) or bottom_panel.get_global_rect().has_point(point)

func ground_at(screen: Vector2) -> Variant:
	return Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: start_wave()
			KEY_1: choose_build("watch")
			KEY_2: choose_build("bombard")
			KEY_3: choose_build("hex")
			KEY_ESCAPE: cancel_orders()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(23, camera.size - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(45, camera.size + 1)
		else:
			var hit = ground_at(event.position)
			if hit == null or finished:
				return
			if event.button_index == MOUSE_BUTTON_RIGHT:
				order_move(hit)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				if build_kind != "":
					order_build(hit)
				else:
					selected = -1
					for i in range(towers.size()):
						if hit.distance_to(towers[i].node.position) < 1.35:
							selected = i
					refresh_ui()

func choose_build(kind: String) -> void:
	if finished:
		return
	cancel_pending()
	builder_path.clear()
	build_kind = kind
	selected = -1
	for child in ghost.get_children():
		ghost.remove_child(child)
		child.queue_free()
	Art.tower(ghost, kind, 1)
	status.text = "Choose open ground. The builder will walk over and construct the tower."
	refresh_ui()

func solid_scenery(point: Vector3, margin: float) -> bool:
	if absf(point.x - 8) < 1.8 + margin and absf(point.z - 9) < 1.15 + margin:
		return true
	for tree in TREES:
		if point.distance_to(tree) < 0.4 + margin:
			return true
	return false

func placement_error(point: Vector3, kind: String) -> String:
	if absf(point.x) > 12.5 or absf(point.z) > 9.3:
		return "Too close to the map edge"
	if solid_scenery(point, 1.1):
		return "Keep clear of the keep and trees"
	for i in range(PATH.size() - 1):
		var nearest := Geometry3D.get_closest_point_to_segment(point, PATH[i], PATH[i + 1])
		if point.distance_to(nearest) < 1.95:
			return "Keep the road clear"
	for tower in towers:
		if point.distance_to(tower.node.position) < 2.5:
			return "Too close to another tower"
	if point.distance_to(builder.position) < 1.45:
		return "Move the builder out of the footprint"
	if gold < int(CATALOG[kind].cost):
		return "Not enough gold"
	return ""

func cell_for(point: Vector3) -> Vector2i:
	return Vector2i(roundi((point.x - GRID_ORIGIN.x) / GRID_STEP), roundi((point.z - GRID_ORIGIN.z) / GRID_STEP))

func world_for(cell: Vector2i) -> Vector3:
	return GRID_ORIGIN + Vector3(cell.x * GRID_STEP, 0, cell.y * GRID_STEP)

func rebuild_navigation() -> void:
	for x in range(navigation.region.size.x):
		for y in range(navigation.region.size.y):
			var cell := Vector2i(x, y)
			var point := world_for(cell)
			var blocked := solid_scenery(point, 0.4)
			for tower in towers:
				if absf(point.x - tower.node.position.x) < 1.2 and absf(point.z - tower.node.position.z) < 1.2:
					blocked = true
			navigation.set_point_solid(cell, blocked)

func route_to(point: Vector3) -> PackedVector3Array:
	var start := cell_for(builder.position)
	var end := cell_for(point)
	var route := PackedVector3Array()
	if not navigation.is_in_boundsv(start) or not navigation.is_in_boundsv(end):
		return route
	if navigation.is_point_solid(start) or navigation.is_point_solid(end):
		return route
	var ids := navigation.get_id_path(start, end)
	for cell in ids:
		route.append(world_for(cell))
	return route

func approach_route(point: Vector3) -> PackedVector3Array:
	var best := PackedVector3Array()
	for i in range(16):
		var angle := TAU * i / 16.0
		var candidate := point + Vector3(cos(angle), 0, sin(angle)) * 1.85
		var route := route_to(candidate)
		if not route.is_empty() and (best.is_empty() or route.size() < best.size()):
			best = route
	return best

func order_move(point: Vector3) -> void:
	if finished:
		return
	cancel_pending()
	build_kind = ""
	ghost.visible = false
	builder_path = route_to(point)
	status.text = "Builder moving." if not builder_path.is_empty() else "That destination is blocked or unreachable."
	refresh_ui()

func order_build(point: Vector3) -> void:
	if finished or build_kind == "":
		return
	var reason := placement_error(point, build_kind)
	if reason != "":
		status.text = reason + ". Choose a different location."
		return
	var root := Node3D.new()
	add_child(root)
	root.position = point
	Art.box(root, Vector3(0, 0.12, 0), Vector3(1.65, 0.24, 1.65), Color("88785d"))
	var progress := Art.box(root, Vector3(0, 0.5, 0), Vector3(1.4, 0.12, 0.15), Color("d4b77a"))
	progress.scale.x = 0.01
	var tower := {"node": root, "kind": build_kind, "level": 1, "ready": false, "cooldown": 0.0}
	towers.append(tower)
	rebuild_navigation()
	var route := approach_route(point)
	if route.is_empty():
		towers.pop_back()
		root.queue_free()
		rebuild_navigation()
		status.text = "The builder cannot reach that construction site."
		return
	var cost: int = CATALOG[build_kind].cost
	gold -= cost
	selected = towers.size() - 1
	pending = {"tower": tower, "cost": cost, "elapsed": 0.0, "upgrade": false, "bar": progress}
	builder_path = route
	build_kind = ""
	ghost.visible = false
	status.text = "Construction ordered. Gold reserved; cancel unfinished work for a full refund."
	refresh_ui()

func order_upgrade() -> void:
	if finished or selected < 0 or not pending.is_empty():
		return
	var tower: Dictionary = towers[selected]
	var cost := upgrade_cost(tower)
	if not tower.ready or tower.level >= 3 or gold < cost:
		return
	var route := approach_route(tower.node.position)
	if route.is_empty():
		status.text = "The builder cannot reach this tower."
		return
	gold -= cost
	pending = {"tower": tower, "cost": cost, "elapsed": 0.0, "upgrade": true}
	builder_path = route
	status.text = "Builder dispatched to upgrade the tower."
	refresh_ui()

func upgrade_cost(tower: Dictionary) -> int:
	return int(CATALOG[tower.kind].cost * 0.8) * int(tower.level)

func cancel_pending() -> void:
	if pending.is_empty():
		return
	gold += int(pending.cost)
	if not pending.upgrade:
		var tower: Dictionary = pending.tower
		towers.erase(tower)
		tower.node.queue_free()
		selected = -1
	pending = {}
	rebuild_navigation()

func cancel_orders() -> void:
	if finished:
		return
	cancel_pending()
	builder_path.clear()
	build_kind = ""
	ghost.visible = false
	status.text = "Orders canceled. Unfinished construction refunded."
	refresh_ui()

func tick_builder(delta: float) -> void:
	if not builder_path.is_empty():
		var goal: Vector3 = builder_path[0]
		if builder.position.distance_to(goal) > 0.01:
			builder.look_at(goal)
		builder.position = builder.position.move_toward(goal, BUILDER_SPEED * delta)
		if builder.position.distance_to(goal) < 0.01:
			builder_path.remove_at(0)
		builder_status.text = "Builder: walking to construction" if not pending.is_empty() else "Builder: moving"
	elif not pending.is_empty():
		pending.elapsed += delta
		var fraction := minf(pending.elapsed / BUILD_TIME, 1.0)
		builder_status.text = "Builder: %s %d%%" % ["upgrading" if pending.upgrade else "constructing", roundi(fraction * 100)]
		if pending.has("bar"):
			pending.bar.scale.x = maxf(0.01, fraction)
		if pending.elapsed >= BUILD_TIME:
			var tower: Dictionary = pending.tower
			if pending.upgrade:
				tower.level += 1
			tower.ready = true
			for child in tower.node.get_children():
				tower.node.remove_child(child)
				child.queue_free()
			Art.tower(tower.node, tower.kind, tower.level)
			pending = {}
			status.text = "%s ready." % CATALOG[tower.kind].name
			refresh_ui()
	else:
		builder_status.text = "Builder: idle / invulnerable"
	destination_ring.visible = not builder_path.is_empty()
	if destination_ring.visible:
		destination_ring.position = builder_path[-1] + Vector3(0, 0.15, 0)

func update_preview() -> void:
	ghost.visible = false
	range_ring.visible = false
	if finished:
		return
	if build_kind != "":
		if cursor_on_ui():
			return
		var hit = ground_at(get_viewport().get_mouse_position())
		if hit == null:
			return
		var reason := placement_error(hit, build_kind)
		ghost.visible = true
		ghost.position = hit
		Art.tint(ghost, Color(0.55, 0.85, 0.62, 0.5) if reason == "" else Color(0.95, 0.28, 0.2, 0.5))
		show_range(hit, CATALOG[build_kind].range)
		detail.text = "%s: %s" % [CATALOG[build_kind].name, "Click to order construction" if reason == "" else reason]
	elif selected >= 0 and selected < towers.size():
		show_range(towers[selected].node.position, tower_range(towers[selected]))

func show_range(point: Vector3, radius: float) -> void:
	range_ring.visible = true
	range_ring.position = point + Vector3(0, 0.13, 0)
	range_ring.scale = Vector3(radius, 0.1, radius)

func tower_range(tower: Dictionary) -> float:
	return float(CATALOG[tower.kind].range) + (int(tower.level) - 1) * 0.5

func start_wave() -> void:
	if active or finished:
		return
	wave += 1
	remaining = 6 + wave * 2
	spawn_timer = 0
	active = true
	status.text = "Wave %d approaches. You can keep building during combat." % wave
	refresh_ui()

func spawn_enemy() -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = PATH[0]
	var health := 34.0 + wave * 13.0
	Art.box(root, Vector3(0, 0.55, 0), Vector3(0.65, 0.9, 0.65), Color("70524a"))
	Art.box(root, Vector3(0, 1.1, 0), Vector3(0.45, 0.35, 0.45), Color("969787"))
	var bar := Art.box(root, Vector3(0, 1.5, 0), Vector3(0.8, 0.09, 0.12), Color("a3b878"))
	enemies.append({"node": root, "hp": health, "max_hp": health, "segment": 1, "bar": bar, "slow": 0.0})

func damage_enemy(enemy: Dictionary, damage: float) -> void:
	enemy.hp -= damage
	enemy.bar.scale.x = maxf(0.01, enemy.hp / enemy.max_hp)

func fire(tower: Dictionary, target: Dictionary) -> void:
	var data: Dictionary = CATALOG[tower.kind]
	var damage: float = data.damage * (1.0 + (tower.level - 1) * 0.65)
	var point: Vector3 = target.node.position
	if tower.kind == "bombard":
		for enemy in enemies:
			if enemy.hp > 0 and enemy.node.position.distance_to(point) <= 1.8:
				damage_enemy(enemy, damage)
		var blast := Art.ring(self, 1.8, Color("d39255"))
		blast.position = point + Vector3(0, 0.2, 0)
		effects.append({"node": blast, "ttl": 0.3})
	else:
		damage_enemy(target, damage)
		if tower.kind == "hex":
			target.slow = 2.0
	var start: Vector3 = tower.node.position + Vector3(0, 2.1 if tower.kind != "bombard" else 1.0, 0)
	var end := point + Vector3(0, 0.65, 0)
	var color := Color("c8b893")
	if tower.kind == "hex":
		color = Color("9babc6")
	elif tower.kind == "bombard":
		color = Color("d39960")
	var trace := Art.box(self, (start + end) / 2, Vector3(0.06, 0.06, start.distance_to(end)), color)
	trace.look_at(end)
	effects.append({"node": trace, "ttl": 0.13})
	tower.cooldown = float(data.interval) / (1.0 + (tower.level - 1) * 0.12)

func _process(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		effects[i].ttl -= delta
		if effects[i].ttl <= 0:
			effects[i].node.queue_free()
			effects.remove_at(i)
	if finished:
		return
	tick_builder(delta)
	update_preview()
	if active and remaining > 0:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_enemy()
			remaining -= 1
			spawn_timer = 0.85
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		var root: Node3D = enemy.node
		enemy.slow = maxf(0, enemy.slow - delta)
		var speed := (1.65 + wave * 0.07) * (0.55 if enemy.slow > 0 else 1.0)
		root.position = root.position.move_toward(PATH[enemy.segment], speed * delta)
		if root.position.distance_to(PATH[enemy.segment]) < 0.01:
			enemy.segment += 1
			if enemy.segment >= PATH.size():
				root.queue_free()
				enemies.remove_at(i)
				lives -= 1
				if lives <= 0:
					end_match(false)
				refresh_ui()
				if finished:
					return
	for tower in towers:
		if not tower.ready:
			continue
		tower.cooldown -= delta
		if tower.cooldown > 0:
			continue
		for enemy in enemies:
			if enemy.hp > 0 and tower.node.position.distance_to(enemy.node.position) <= tower_range(tower):
				fire(tower, enemy)
				break
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].hp <= 0:
			enemies[i].node.queue_free()
			enemies.remove_at(i)
			gold += 8
			refresh_ui()
	if active and remaining == 0 and enemies.is_empty():
		active = false
		gold += 25 + wave * 5
		if wave == 10:
			end_match(true)
		else:
			status.text = "Wave cleared. Reinvest your gold, then send the next wave."
		refresh_ui()

func end_match(won: bool) -> void:
	cancel_pending()
	builder_path.clear()
	build_kind = ""
	ghost.visible = false
	range_ring.visible = false
	destination_ring.visible = false
	active = false
	finished = true
	status.text = "Victory! Stonewatch survived all 10 waves." if won else "The keep has fallen. Restart to try another defense."
	builder_status.text = "Match complete. Restart begins a fresh match."

func refresh_ui() -> void:
	stats.text = "STONEWATCH     Gold: %d     Lives: %d     Wave: %d / 10" % [gold, lives, wave]
	next_wave.text = "In progress" if active else "Wave %d / Space" % (wave + 1)
	if finished:
		next_wave.text = "Match complete"
	next_wave.disabled = active or finished
	cancel_button.disabled = finished
	for kind in build_buttons:
		build_buttons[kind].disabled = finished
		build_buttons[kind].set_pressed_no_signal(build_kind == kind)
	action.disabled = true
	action.text = "Upgrade"
	detail.text = "Choose a tower, then place it on open ground. The builder handles construction."
	if build_kind != "":
		detail.text = "%s / %s" % [CATALOG[build_kind].name, CATALOG[build_kind].description]
	elif selected >= 0 and selected < towers.size():
		var tower: Dictionary = towers[selected]
		var data: Dictionary = CATALOG[tower.kind]
		detail.text = "%s / Level %d / %s%s" % [data.name, tower.level, data.description, " / under construction" if not tower.ready else ""]
		action.text = "Max level" if tower.level >= 3 else "Upgrade [%dg]" % upgrade_cost(tower)
		action.disabled = finished or not tower.ready or tower.level >= 3 or gold < upgrade_cost(tower) or not pending.is_empty()