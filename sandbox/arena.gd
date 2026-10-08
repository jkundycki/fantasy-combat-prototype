extends Node3D

func _ready() -> void:
	box("Floor", Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color("4c514a"))
	box("NorthWall", Vector3(0, 1, -20), Vector3(40, 3, 0.5), Color("77786b"))
	box("SouthWall", Vector3(0, 1, 20), Vector3(40, 3, 0.5), Color("77786b"))
	box("WestWall", Vector3(-20, 1, 0), Vector3(0.5, 3, 40), Color("77786b"))
	box("EastWall", Vector3(20, 1, 0), Vector3(0.5, 3, 40), Color("77786b"))
	# Heights and gaps for testing jump timing and air steering.
	box("LowPlatform", Vector3(-5, 0.3, -5), Vector3(3, 0.6, 3), Color("827b67"))
	box("MiddlePlatform", Vector3(-5, 0.7, -10), Vector3(3, 1.4, 3), Color("827b67"))
	box("HighPlatform", Vector3(0, 1.1, -10), Vector3(3, 2.2, 3), Color("827b67"))
	box("Pillar", Vector3(7, 1.5, -4), Vector3(2, 3, 2), Color("646c64"))
	var ramp := box("Ramp", Vector3(7, 0.6, 7), Vector3(4, 0.4, 7), Color("646c64"))
	ramp.rotation_degrees.x = -12.0
	# Flush inset stone paving; visual only, preserving the flat physics floor.
	var paving := StandardMaterial3D.new()
	paving.albedo_color = Color("706e64")
	paving.roughness = 0.95
	var alternate := paving.duplicate()
	alternate.albedo_color = Color("7c796e")
	for x in range(-9, 10):
		for z in range(-9, 10):
			var tile := MeshInstance3D.new()
			var slab := BoxMesh.new()
			slab.size = Vector3(1.97, 0.012, 1.97)
			tile.mesh = slab
			tile.material_override = paving if (x + z) % 3 else alternate
			tile.position = Vector3(x * 2, 0.006, z * 2)
			add_child(tile)
	# Edge buttresses and banners frame the open training court.
	for x in [-18.0, -10.0, 10.0, 18.0]:
		for z in [-19.6, 19.6]:
			decor(Vector3(x, 1.8, z), Vector3(0.9, 3.6, 1), Color("666960"))
			decor(Vector3(x, 3.65, z), Vector3(1.15, 0.22, 1.2), Color("96917e"))
	for x in [-12.0, 12.0]:
		decor(Vector3(x, 2.1, -19.25), Vector3(1.1, 1.8, 0.06), Color("365466"))
		decor(Vector3(x, 3.05, -19.2), Vector3(1.4, 0.1, 0.12), Color("b8985c"))
	decor(Vector3(7, 3.05, -4), Vector3(2.16, 0.16, 2.16), Color("96917e"))
	decor(Vector3(7, 0.1, -4), Vector3(2.12, 0.2, 2.12), Color("77766a"))
	# A restrained central sparring ring replaces the debug speed grid.
	for i in range(48):
		var angle := TAU * i / 48
		var marker := decor(Vector3(sin(angle) * 8, 0.022, cos(angle) * 8), Vector3(0.05, 0.012, 0.72), Color("b0a080"))
		marker.rotation.y = angle + PI / 2

func box(label: String, center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = center
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	body.add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	return body

func decor(center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	add_child(instance)
	return instance
