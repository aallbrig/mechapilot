class_name VisualPiece
extends MeshInstance3D
## One rigid piece of a model: its primitive part children are authored in the
## scene (so they can be edited in the editor) and baked into this node's single
## mesh when the owning VisualRig is ready, so the piece costs one draw call.
## Pivots and markers are siblings or children that are not primitive parts, and
## are kept. Baked meshes are cached per scene and piece path, so every instance
## of a scene shares one mesh.

const HULL_MATERIAL: ShaderMaterial = preload("res://game/visuals/kit/hull_material.tres")
const FLASH_MATERIAL: ShaderMaterial = preload("res://game/visuals/kit/flash_material.tres")

static var _cache: Dictionary[StringName, ArrayMesh] = {}


## Bake the primitive part children into this piece's mesh and free them.
## An empty cache_key disables caching (for pieces built outside a saved scene).
func bake(palette: Dictionary[StringName, Color], cache_key: StringName) -> void:
	var parts: Array[MeshInstance3D] = primitive_parts()
	var baked: ArrayMesh = null
	if cache_key != &"" and _cache.has(cache_key):
		baked = _cache[cache_key]
	else:
		baked = MeshBaker.bake(parts, palette)
		if cache_key != &"" and baked != null:
			_cache[cache_key] = baked
	for part: MeshInstance3D in parts:
		remove_child(part)
		part.free()
	mesh = baked
	material_override = HULL_MATERIAL
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The direct children that are primitive parts (not pieces, pivots or markers).
func primitive_parts() -> Array[MeshInstance3D]:
	var parts: Array[MeshInstance3D] = []
	for child: Node in get_children():
		if child is VisualPiece:
			continue
		var part: MeshInstance3D = child as MeshInstance3D
		if part != null and part.mesh is PrimitiveMesh:
			parts.append(part)
	return parts


## Show the hit flash (true) or the normal hull (false).
func show_flash(on: bool) -> void:
	material_override = FLASH_MATERIAL if on else HULL_MATERIAL
