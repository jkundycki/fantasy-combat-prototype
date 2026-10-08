extends Node3D
# Disposable presentation only. No damage, timing, camera or AI authority.
@export var lifetime: float = 0.48
var kind: String = "hit"
var strength: float = 1.0
var elapsed: float = 0.0
var tint := Color("ffd6a0")
var material: StandardMaterial3D
const SOUNDS := {
	"light_swing": preload("res://sandbox/audio/light_swing.wav"),
	"heavy_swing": preload("res://sandbox/audio/heavy_swing.wav"),
	"hit": preload("res://sandbox/audio/hit.wav"),
	"heavy": preload("res://sandbox/audio/heavy.wav"),
	"block": preload("res://sandbox/audio/block.wav"),
	"parry": preload("res://sandbox/audio/parry.wav"),
	"bash": preload("res://sandbox/audio/bash.wav"),
	"cast": preload("res://sandbox/audio/cast.wav"),
	"reflect": preload("res://sandbox/audio/reflect.wav"),
	"guard_break": preload("res://sandbox/audio/guard_break.wav"),
}
static func sound(actor: Node3D, cue: String) -> void:
	if DisplayServer.get_name() == "headless" or not SOUNDS.has(cue):
		return
	var voice := AudioStreamPlayer3D.new()
	voice.stream = SOUNDS[cue]
	voice.volume_db = -12
	voice.unit_size = 6
	voice.max_distance = 22
	actor.get_parent().add_child(voice)
	voice.global_position = actor.global_position + Vector3.UP
	voice.finished.connect(voice.queue_free)
	voice.play()

static func impact(actor: Node3D, cue: String) -> void:
	var effect = load("res://sandbox/combat_feedback.gd").new()
	effect.kind = cue
	effect.strength = 1.6 if cue in ["heavy", "parry", "reflect", "guard_break", "charged_magic"] else 1.0
	effect.lifetime = 0.72 if cue == "guard_break" else 0.48
	actor.get_parent().add_child(effect)
	var point := actor.global_position + Vector3(0, 1.15, 0)
	var camera := actor.get_viewport().get_camera_3d()
	if camera != null:
		point += (camera.global_position - point).normalized() * 0.4
	effect.global_position = point
	sound(actor, "cast" if cue in ["magic", "charged_magic"] else ("hit" if cue == "arrow" else cue))

func _ready() -> void:
	add_to_group("combat_effects")
	tint = {"charged_magic": Color("b9efff"), "magic": Color("70bfff"), "arrow": Color("ffe4b0"), "block": Color("82bfff"), "parry": Color("e1fcff"), "reflect": Color("59fff1"), "guard_break": Color("ff70c2"), "heavy": Color("ffbd66")}.get(kind, Color("ffe2b5"))
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = tint
	material.no_depth_test = false
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.13
	mesh.outer_radius = 0.16
	mesh.rings = 16
	mesh.ring_segments = 6
	ring.mesh = mesh
	ring.material_override = material
	ring.rotation.x = PI / 2
	add_child(ring)
	for i in range(8):
		var spark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.018, 0.11, 0.018)
		spark.mesh = box
		spark.material_override = material
		var angle: float = TAU * i / 8.0
		spark.position = Vector3(sin(angle), cos(angle), 0) * 0.21
		spark.rotation.z = -angle
		add_child(spark)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null and global_position.distance_squared_to(camera.global_position) > 0.01:
		look_at(camera.global_position, Vector3.UP)
	scale = Vector3.ONE * strength * (0.55 + elapsed / lifetime * 1.3)
	material.albedo_color = Color(tint, 1.0 - elapsed / lifetime)
