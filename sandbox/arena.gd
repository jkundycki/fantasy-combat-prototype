extends Node3D

func _ready() -> void:
	box("Floor", Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color("52616a"))
	box("NorthWall", Vector3(0, 1, -20), Vector3(40, 3, 0.5), Color("83919a"))
	box("SouthWall", Vector3(0, 1, 20), Vector3(40, 3, 0.5), Color("83919a"))
	box("WestWall", Vector3(-20, 1, 0), Vector3(0.5, 3, 40), Color("83919a"))
	box("EastWall", Vector3(20, 1, 0), Vector3(0.5, 3, 40), Color("83919a"))
	# Heights and gaps for testing jump timing and air steering.
	box("LowPlatform", Vector3(-5, 0.3, -5), Vector3(3, 0.6, 3), Color("bd9a64"))
	box("MiddlePlatform", Vector3(-5, 0.7, -10), Vector3(3, 1.4, 3), Color("bd9a64"))
	box("HighPlatform", Vector3(0, 1.1, -10), Vector3(3, 2.2, 3), Color("bd9a64"))
	box("Pillar", Vector3(7, 1.5, -4), Vector3(2, 3, 2), Color("899e80"))
	var ramp := box("Ramp", Vector3(7, 0.6, 7), Vector3(4, 0.4, 7), Color("899e80"))
	ramp.rotation_degrees.x = -12.0
	# Flat contrasting stripes provide speed references without UI.
	for coordinate in range(-15, 16, 5):
		var stripe := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.04, 0.01, 38)
		stripe.mesh = mesh
		stripe.position = Vector3(coordinate, 0.006, 0)
		add_child(stripe)

func box(label: String, center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = center
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
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
