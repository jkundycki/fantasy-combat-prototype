extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func click(point: Vector2, code: MouseButton) -> void:
	# Input.parse_input_event expects window pixels, including headless letterboxing.
	point = root.get_final_transform() * point
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run_checks() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await key(KEY_1)
	assert(game.build_kind == "watch", "Hotkey selects a tower")
	await click(game.camera.unproject_position(Vector3(-3, 0, -4)), MOUSE_BUTTON_LEFT)
	assert(game.towers.size() == 1 and game.gold == 100, "World click places a free-position construction site")
	await key(KEY_ESCAPE)
	assert(game.gold == 150 and game.towers.is_empty(), "Escape cancels and refunds")
	var build_button: Button = game.build_buttons["bombard"]
	await click(build_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	assert(game.build_kind == "bombard" and game.towers.is_empty(), "UI chooses tower without placing through panel")
	await click(game.camera.unproject_position(Vector3(-9, 0, 0)), MOUSE_BUTTON_RIGHT)
	assert(game.build_kind == "" and not game.builder_path.is_empty(), "Right-click issues builder movement")
	await key(KEY_SPACE)
	assert(game.wave == 1 and game.active, "Space starts wave after button interaction")
	print("PASS: keyboard selection, mouse placement, Escape refund, build menu click isolation, right-click movement, Space wave")
	quit()