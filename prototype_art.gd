extends RefCounted
## Procedural placeholder art; replace these factories with imported scenes later.

static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = at
	return node

static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = at
	return node

static func ring(parent: Node3D, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.035
	mesh.outer_radius = radius
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	return node

static func tower(parent: Node3D, kind: String, level: int) -> void:
	var stone := Color("656760")
	var wood := Color("504034")
	var iron := Color("343b3e")
	box(parent, Vector3(0, 0.16, 0), Vector3(1.65, 0.32, 1.65), stone)
	match kind:
		"watch":
			for x in [-0.52, 0.52]:
				for z in [-0.52, 0.52]:
					box(parent, Vector3(x, 1.0, z), Vector3(0.2, 1.8, 0.2), wood)
			box(parent, Vector3(0, 1.7, 0), Vector3(1.65, 0.22, 1.65), wood)
			for z in [-0.7, 0.7]:
				box(parent, Vector3(0, 2.02, z), Vector3(1.6, 0.45, 0.15), stone)
			box(parent, Vector3(0, 2.2, 0), Vector3(0.15, 0.16, 1.65), iron)
			box(parent, Vector3(0, 2.2, -0.4), Vector3(1.1, 0.12, 0.12), wood)
		"bombard":
			box(parent, Vector3(0, 0.5, 0), Vector3(1.25, 0.5, 1.1), wood)
			var barrel := cylinder(parent, Vector3(0, 0.95, -0.22), 0.32, 1.55, iron)
			barrel.rotation_degrees.x = 65
			for x in [-0.67, 0.67]:
				var wheel := cylinder(parent, Vector3(x, 0.6, 0.15), 0.48, 0.18, wood)
				wheel.rotation_degrees.z = 90
		"hex":
			box(parent, Vector3(0, 1.15, 0), Vector3(0.65, 1.9, 0.65), iron)
			var cap := box(parent, Vector3(0, 2.3, 0), Vector3(0.5, 0.5, 0.5), Color("8c9cba"))
			cap.rotation_degrees.z = 45
			for y in [0.8, 1.3, 1.8]:
				box(parent, Vector3(0, y, -0.335), Vector3(0.28, 0.055, 0.025), Color("a7b8d1"))
	for i in range(level):
		box(parent, Vector3(-0.4 + i * 0.4, 0.35, 0.84), Vector3(0.16, 0.13, 0.04), Color("c5a568"))

static func tint(root: Node, color: Color) -> void:
	if root is MeshInstance3D:
		root.material_override = material(color)
		root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in root.get_children():
		tint(child, color)

static func builder(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	box(root, Vector3(0, 0.65, 0), Vector3(0.48, 0.65, 0.32), Color("b29a67"))
	box(root, Vector3(0, 1.1, 0), Vector3(0.3, 0.3, 0.3), Color("c4ab8d"))
	box(root, Vector3(0, 1.26, 0), Vector3(0.4, 0.12, 0.38), Color("4d4740"))
	for x in [-0.15, 0.15]:
		box(root, Vector3(x, 0.22, 0), Vector3(0.16, 0.4, 0.22), Color("393b37"))
	box(root, Vector3(0.4, 0.6, 0), Vector3(0.09, 0.7, 0.09), Color("604e3a"))
	box(root, Vector3(0.4, 0.95, 0), Vector3(0.36, 0.2, 0.22), Color("8d918c"))
	var marker := ring(root, 0.6, Color("e3cc89"))
	marker.position.y = 0.12
	return root