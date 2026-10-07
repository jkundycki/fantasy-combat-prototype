extends SceneTree

var game: Node3D

func _initialize() -> void:
	call_deferred("run_checks")

func fresh() -> void:
	if is_instance_valid(game):
		root.remove_child(game)
		game.queue_free()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)

func finish_work() -> void:
	for tick in range(2400):
		game.tick_builder(1.0 / 60.0)
		if game.pending.is_empty():
			break
	assert(game.pending.is_empty(), "Construction must finish")

func place(kind: String, point: Vector3) -> void:
	game.choose_build(kind)
	assert(game.placement_error(point, kind) == "", "Test location must be buildable")
	game.order_build(point)
	assert(not game.pending.is_empty(), "Build order must be accepted")
	finish_work()

func run_checks() -> void:
	fresh()
	assert(game.towers.is_empty(), "No fixed pads or prebuilt towers")
	assert(game.placement_error(Vector3(-6, 0, 0), "watch") != "", "Road placement blocked")
	assert(game.placement_error(Vector3(14, 0, 0), "watch") != "", "Boundary placement blocked")
	assert(game.placement_error(Vector3(8, 0, 9), "watch") != "", "Keep placement blocked")
	assert(game.placement_error(Vector3(-12, 0, 7), "watch") != "", "Tree placement blocked")
	assert(game.placement_error(game.builder.position, "watch") != "", "Builder footprint blocked")
	game.choose_build("watch")
	game.order_build(Vector3(-3, 0, -4))
	assert(game.gold == 100 and game.towers.size() == 1 and not game.towers[0].ready, "Reserve gold for unfinished tower")
	assert(game.placement_error(Vector3(-3, 0, -3), "watch") != "", "Tower overlap blocked")
	game.tick_builder(0.1)
	assert(not game.towers[0].ready, "Construction cannot finish remotely")
	game.cancel_orders()
	assert(game.gold == 150 and game.towers.is_empty(), "Cancel refunds and removes footprint")
	place("watch", Vector3(-3, 0, -4))
	assert(game.gold == 100 and game.towers[0].ready, "Builder completes construction")
	assert(game.builder.position.distance_to(Vector3(-3, 0, -4)) < 2.3, "Builder must reach the site")
	game.selected = 0
	game.order_upgrade()
	assert(game.gold == 60 and game.towers[0].level == 1, "Upgrade reserves gold, not instant")
	game.cancel_orders()
	assert(game.gold == 100 and game.towers[0].level == 1, "Canceled upgrade keeps original tower")
	game.order_upgrade()
	finish_work()
	assert(game.gold == 60 and game.towers[0].level == 2, "Upgrade completed by builder")
	game.order_upgrade()
	assert(game.pending.is_empty() and game.gold == 60, "Unaffordable upgrade blocked")
	game.gold = 0
	assert(game.placement_error(Vector3(-9, 0, 0), "watch") == "Not enough gold", "Unaffordable build blocked")
	game.gold = 100
	game.builder.position = Vector3(-3, 0, -7)
	var route: PackedVector3Array = game.route_to(Vector3(-3, 0, -1))
	assert(not route.is_empty(), "Builder can route around towers")
	for point in route:
		assert(absf(point.x + 3) >= 1.2 or absf(point.z + 4) >= 1.2, "Route cannot cross a tower")
	game.choose_build("hex")
	game.order_build(Vector3(-9, 0, 0))
	assert(not game.pending.is_empty(), "Second construction accepted")
	game.order_move(Vector3(-10, 0, 3))
	assert(game.gold == 100 and game.pending.is_empty() and game.towers.size() == 1, "Move order cancels and refunds construction")
	print("PASS: free placement, road/keep/tree/edge/overlap checks, navigation, construction, cancellation, upgrades, funds")
	fresh()
	game.gold = 1000
	place("watch", Vector3(-3, 0, -4))
	place("bombard", Vector3(-3, 0, 0))
	place("hex", Vector3(4, 0, 0))
	game.wave = 1
	for i in range(3):
		game.spawn_enemy()
		game.enemies[i].node.position = Vector3(-4 + i * 0.6, 0, 0)
	var initial: float = game.enemies[0].hp
	game.fire(game.towers[0], game.enemies[0])
	assert(game.enemies[0].hp < initial and game.enemies[1].hp == initial, "Watchtower is single target")
	game.fire(game.towers[1], game.enemies[0])
	assert(game.enemies[1].hp < initial and game.enemies[2].hp < initial, "Bombard damages nearby enemies")
	game.fire(game.towers[2], game.enemies[2])
	assert(game.enemies[2].slow == 2.0, "Hex applies a timed slow")
	for tower in game.towers:
		tower.cooldown = 100
	game.enemies[0].hp = 0
	var before: int = game.gold
	game._process(0.01)
	assert(game.gold == before + 8, "Kills award gold once")
	print("PASS: distinct tower attacks, splash damage, timed slow, kill rewards")
	fresh()
	# Exercise a complete match with only starting gold and earned rewards.
	place("watch", Vector3(-3, 0, -4))
	place("bombard", Vector3(-3, 0, 0))
	for wave_index in range(10):
		game.start_wave()
		for tick in range(24000):
			game._process(1.0 / 30.0)
			if not game.active or game.finished:
				break
		assert(not game.active, "Wave must resolve")
		assert(game.lives > 0, "Budget-based strategy must survive")
		if game.finished:
			break
		for i in range(game.towers.size()):
			game.selected = i
			if game.towers[i].level < 3 and game.gold >= game.upgrade_cost(game.towers[i]):
				game.order_upgrade()
				finish_work()
		if game.towers.size() == 2 and game.gold >= 65:
			place("hex", Vector3(4, 0, 0))
		if game.towers.size() == 3 and game.gold >= 50:
			place("watch", Vector3(5, 0, 5))
	assert(game.finished and game.wave == 10 and game.lives > 0, "Victory achievable with earned gold")
	print("PASS: 10-wave match with earned gold; lives left: ", game.lives)
	fresh()
	game.lives = 1
	game.start_wave()
	for tick in range(10000):
		game._process(1.0 / 30.0)
		if game.finished:
			break
	assert(game.finished and game.lives == 0, "Escaping enemies trigger defeat")
	game.choose_build("watch")
	assert(game.build_kind == "", "Match end blocks new build orders")
	fresh()
	assert(game.gold == 150 and game.wave == 0 and game.lives == 20 and game.towers.is_empty(), "New matches reset progression")
	print("PASS: defeat, post-match lockout, fresh match reset")
	quit()