extends MeshInstance3D
# Brief ribbons sampled from the visible blade during authoritative active frames.
var weapon
var tip_distance: float = 2.0
var tips: Array[Vector3] = []
var roots: Array[Vector3] = []
var ages: Array[float] = []
@export var fade_time: float = 0.20
var ribbon := ImmediateMesh.new()

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = ribbon
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1, 1, 1, 0.28)
	material_override = material

func _process(delta: float) -> void:
	var swing = weapon.active_swing()
	if not weapon.visible or not swing.busy():
		tips.clear()
		roots.clear()
		ages.clear()
	for i in range(ages.size()):
		ages[i] += delta
	while not ages.is_empty() and ages[0] >= fade_time:
		ages.pop_front()
		tips.pop_front()
		roots.pop_front()
	if weapon.visible and swing.state == swing.ACTIVE and not swing.shield_bash and not swing.guard_break:
		var pivot: Node3D = get_parent()
		var tip := pivot.to_global(Vector3(0, 0, -tip_distance))
		if tips.is_empty() or tips.back().distance_squared_to(tip) > 0.00001:
			tips.append(tip)
			roots.append(pivot.to_global(Vector3(0, 0, -0.25)))
			ages.append(0)
	ribbon.clear_surfaces()
	if tips.size() < 2:
		return
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(tips.size()):
		ribbon.surface_set_color(Color(0.85, 0.94, 1, 1 - ages[i] / fade_time))
		ribbon.surface_add_vertex(roots[i])
		ribbon.surface_add_vertex(tips[i])
	ribbon.surface_end()
