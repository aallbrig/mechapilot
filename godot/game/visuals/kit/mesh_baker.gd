class_name MeshBaker
extends RefCounted
## Merges primitive part meshes (BoxMesh, CylinderMesh, SphereMesh, PrismMesh,
## ...) into one flat-shaded ArrayMesh surface, so a whole model piece costs one
## draw call. Each part's colour comes from its material: the material's
## resource_name is a palette slot, so one scene can be recoloured by a palette.
## A material with emission bakes as glow: the vertex colour's alpha carries the
## glow amount (0 = full glow, 1 = none), which the hull shader turns into emission.
## Works headless: it reads the primitives' CPU-side arrays, never the GPU.
## Colours are baked as authored (sRGB): the Compatibility renderer's hull shader
## reads them as-is, which keeps on-screen colours true to the palette.

## Vertex colour alpha for a part that glows (the hull shader reads 1 - alpha).
const GLOW_ALPHA: float = 0.0
## Vertex colour alpha for a plain, non-glowing part.
const SOLID_ALPHA: float = 1.0
## Triangles smaller than this (squared cross product) are dropped as degenerate.
const DEGENERATE_EPSILON: float = 1e-12


## The colour a part bakes with: its material's albedo, replaced by the palette
## entry named by the material's resource_name when the palette has one.
static func part_color(part: MeshInstance3D, palette: Dictionary[StringName, Color]) -> Color:
	var material: StandardMaterial3D = part.material_override as StandardMaterial3D
	if material == null:
		material = part.mesh.surface_get_material(0) as StandardMaterial3D
	if material == null:
		return Color.MAGENTA
	var slot: StringName = StringName(material.resource_name)
	var color: Color = material.albedo_color
	if palette.has(slot):
		color = palette[slot]
	color.a = GLOW_ALPHA if material.emission_enabled else SOLID_ALPHA
	return color


## Bake the parts, each placed by its own transform, into one ArrayMesh.
## Returns null if no part has a primitive mesh.
static func bake(parts: Array[MeshInstance3D], palette: Dictionary[StringName, Color]) -> ArrayMesh:
	var shapes: Array[PrimitiveMesh] = []
	var xforms: Array[Transform3D] = []
	var colors: PackedColorArray = PackedColorArray()
	for part: MeshInstance3D in parts:
		var primitive: PrimitiveMesh = part.mesh as PrimitiveMesh
		if primitive == null:
			continue
		shapes.append(primitive)
		xforms.append(part.transform)
		var _added: bool = colors.push_back(part_color(part, palette))
	return bake_shapes(shapes, xforms, colors)


## Bake primitives placed by the matching transforms, each in the matching
## colour, into one ArrayMesh. Returns null if there is nothing to bake.
static func bake_shapes(
	shapes: Array[PrimitiveMesh], xforms: Array[Transform3D], shape_colors: PackedColorArray
) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var count: int = mini(shapes.size(), mini(xforms.size(), shape_colors.size()))
	for i: int in count:
		_append_flat(shapes[i], xforms[i], shape_colors[i], vertices, normals, colors)
	if vertices.is_empty():
		return null
	var arrays: Array = []
	var _sized: int = arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Append one primitive as flat-shaded triangles (one normal per face, for the
## faceted low-poly look), keeping the primitive's own winding and facing.
static func _append_flat(
	primitive: PrimitiveMesh,
	xform: Transform3D,
	color: Color,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray
) -> void:
	var arrays: Array = primitive.get_mesh_arrays()
	var src_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis: Basis = xform.basis.inverse().transposed()
	var mirrored: bool = xform.basis.determinant() < 0.0
	var count: int = indices.size() - indices.size() % 3
	for i: int in range(0, count, 3):
		var ia: int = indices[i]
		var ib: int = indices[i + 1]
		var ic: int = indices[i + 2]
		if mirrored:
			var swap: int = ib
			ib = ic
			ic = swap
		var a: Vector3 = xform * src_vertices[ia]
		var b: Vector3 = xform * src_vertices[ib]
		var c: Vector3 = xform * src_vertices[ic]
		var face: Vector3 = (b - a).cross(c - a)
		if face.length_squared() < DEGENERATE_EPSILON:
			continue
		var smooth: Vector3 = normal_basis * (src_normals[ia] + src_normals[ib] + src_normals[ic])
		var normal: Vector3 = face.normalized()
		if normal.dot(smooth) < 0.0:
			normal = -normal
		for vertex: Vector3 in [a, b, c]:
			var _v: bool = vertices.push_back(vertex)
			var _n: bool = normals.push_back(normal)
			var _c: bool = colors.push_back(color)
