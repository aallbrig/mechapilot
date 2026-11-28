class_name TelegraphGlows
extends MultiMeshInstance3D
## The muzzle glow of every enemy that is telegraphing an attack, drawn as one
## MultiMesh: one draw call for the whole field, however many glow at once
## (#84's draw-call budget). Each glow is a small unshaded sphere in the shared
## glow colour; its brightness rides on the instance colour (HDR, so the
## Environment's glow blooms it) and its size on the instance transform.

## A glow's radius at a look_scale of 1 (world units).
const GLOW_SIZE: float = 0.35
const GROW_CHUNK: int = 16

static var _mesh: SphereMesh
static var _material: StandardMaterial3D


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _sphere()
	material_override = _glow_material()
	multimesh.visible_instance_count = 0


## Show the glow of every glowing look in `looks`, and nothing else.
func show_glows(looks: Array[EnemyLook]) -> void:
	var glowing: Array[EnemyLook] = []
	for look: EnemyLook in looks:
		if look.is_glowing() and look.is_inside_tree():
			glowing.append(look)
	if glowing.size() > multimesh.instance_count:
		# Resizing clears the buffer; every shown instance is rewritten below.
		multimesh.instance_count = ceili(glowing.size() / float(GROW_CHUNK)) * GROW_CHUNK
	var into_field: Transform3D = global_transform.affine_inverse()
	for i: int in glowing.size():
		var look: EnemyLook = glowing[i]
		multimesh.set_instance_transform(i, into_field * look.glow_transform())
		var shine: Color = EnemyLook.GLOW_COLOR * look.glow_energy()
		shine.a = 1.0
		multimesh.set_instance_color(i, shine)
	multimesh.visible_instance_count = glowing.size()


## How many glows show now.
func shown() -> int:
	return multimesh.visible_instance_count


static func _sphere() -> SphereMesh:
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = GLOW_SIZE
		_mesh.height = GLOW_SIZE * 2.0
	return _mesh


static func _glow_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.vertex_color_use_as_albedo = true
	return _material
