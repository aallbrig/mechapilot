class_name VisualRig
extends Node3D
## The root of every model scene (player mech, enemies, bosses). It owns no game
## logic: logic scenes instance it and drive its pivots and read its markers.
## Conventions shared by every model, so logic can treat them alike:
## - Side profile: the nose points along +X, the top along +Y, and the camera
##   looks from +Z. Flip or rotate the rig, never its pieces.
## - Every rig has a `Hull` piece (its main body).
## - Markers and pivots are scene-unique nodes (`%Name`), listed by
##   required_markers(); marker() returns them typed.
## - A nozzle or muzzle marker's local -Z points the way shots or exhaust leave.
## - Phase parts live under `Phase<N>` nodes; set_phase(N) shows only that group.
## On ready, every VisualPiece below the rig is baked into one mesh, so a piece
## costs one draw call whatever its part count.

## Every rig's main body piece.
const HULL: StringName = &"Hull"

## Palette slot -> colour. A part's material resource_name names its slot.
## Set it before the rig enters the tree: the pieces bake once, on ready, and
## a later change is rejected with a warning (the parts are gone by then).
@export var palette: Dictionary[StringName, Color] = {}:
	set(value):
		if is_node_ready():
			push_warning("%s: palette changes after ready are ignored; set it before" % name)
			return
		palette = value
## How many `Phase<N>` groups the rig has (0 for none).
@export_range(0, 9) var phase_count: int = 0
## Cosmetic idle spin: pivot name -> rate in rad/s about the pivot's local Y
## (rotors, radar dishes). Logic never needs to drive these.
@export var spin_rates: Dictionary[StringName, float] = {}

var _pieces: Array[VisualPiece] = []
var _phase: int = 0
var _spinners: Dictionary[Node3D, float] = {}


func _ready() -> void:
	_pieces.clear()
	_collect_pieces(self, _pieces)
	for piece: VisualPiece in _pieces:
		piece.bake(palette, bake_key(piece), piece_material())
	for marker_name: StringName in required_markers():
		if marker(marker_name) == null:
			push_error("%s: missing required marker %%%s" % [name, marker_name])
	if phase_count > 0:
		# A phase set before the rig entered the tree is kept.
		set_phase(maxi(_phase, 1))
	_spinners.clear()
	for pivot_name: StringName in spin_rates:
		var pivot: Node3D = marker(pivot_name)
		if pivot != null:
			_spinners[pivot] = spin_rates[pivot_name]
	set_process(not _spinners.is_empty())


func _process(delta: float) -> void:
	for pivot: Node3D in _spinners:
		pivot.rotate_object_local(Vector3.UP, _spinners[pivot] * delta)


## The scene-unique markers and pivots this rig promises to logic.
func required_markers() -> Array[StringName]:
	var names: Array[StringName] = [HULL]
	for phase: int in range(1, phase_count + 1):
		names.append(phase_name(phase))
	return names


## The shared material every piece of this rig wears: the hull's.
func piece_material() -> ShaderMaterial:
	return VisualPiece.HULL_MATERIAL


## The cache key a piece's baked mesh is shared under: the scene, the piece's
## path in it and the palette, so a copy recoloured with its own palette (set
## before it enters the tree) bakes its own mesh instead of reusing another's.
## Empty (no caching) for rigs built outside a saved scene.
func bake_key(piece: VisualPiece) -> StringName:
	if scene_file_path == "":
		return &""
	return StringName("%s|%s|%x" % [scene_file_path, get_path_to(piece), palette.hash()])


## A scene-unique marker or pivot by name, or null if the rig has none.
func marker(marker_name: StringName) -> Node3D:
	return get_node_or_null(NodePath("%" + String(marker_name))) as Node3D


## The box around every mesh of the rig, in the rig's own space (its scale
## ignored). It holds before and after the bake (parts, then baked pieces), so
## logic can size a model to its hit geometry before it enters the tree.
func bounds() -> AABB:
	var box: AABB = AABB()
	var found: bool = false
	var meshes: Dictionary[MeshInstance3D, Transform3D] = {}
	_meshes_below(self, Transform3D.IDENTITY, meshes)
	for mesh_node: MeshInstance3D in meshes:
		if mesh_node.mesh == null:
			continue
		var part: AABB = meshes[mesh_node] * mesh_node.mesh.get_aabb()
		box = part if not found else box.merge(part)
		found = true
	return box


## A node's transform in the rig's own space (its scale ignored), from the
## local transforms alone, so it holds before the rig enters the tree.
## Identity if the node is not below the rig.
func to_rig(node: Node3D) -> Transform3D:
	var found: Array[Transform3D] = []
	_find_below(self, node, Transform3D.IDENTITY, found)
	return found[0] if not found.is_empty() else Transform3D.IDENTITY


## Every baked piece of the rig (each is one draw call while visible).
func pieces() -> Array[VisualPiece]:
	return _pieces.duplicate()


## Swap every piece to the shared hit-flash material, or back.
func set_flash(on: bool) -> void:
	for piece: VisualPiece in _pieces:
		piece.show_flash(on)


## Show only the parts of the given phase (1-based); parts outside any
## `Phase<N>` group stay visible in every phase.
func set_phase(phase: int) -> void:
	_phase = clampi(phase, 1, maxi(phase_count, 1))
	for i: int in range(1, phase_count + 1):
		var group: Node3D = marker(phase_name(i))
		if group != null:
			group.visible = i == _phase


## The phase currently shown (0 before any phase is set).
func current_phase() -> int:
	return _phase


## The name of the node that groups one phase's parts.
static func phase_name(phase: int) -> StringName:
	return StringName("Phase%d" % phase)


## The name of the i-th (1-based) marker in a numbered family, e.g. Turret2.
static func indexed_name(prefix: String, index: int) -> StringName:
	return StringName("%s%d" % [prefix, index])


## Every mesh below `node`, with its transform from `node`'s space (`into`).
static func _meshes_below(
	node: Node, into: Transform3D, out: Dictionary[MeshInstance3D, Transform3D]
) -> void:
	for child: Node in node.get_children():
		var at: Transform3D = into
		var spatial: Node3D = child as Node3D
		if spatial != null:
			at = into * spatial.transform
		var mesh_node: MeshInstance3D = child as MeshInstance3D
		if mesh_node != null:
			out[mesh_node] = at
		_meshes_below(child, at, out)


static func _find_below(
	node: Node, target: Node3D, into: Transform3D, found: Array[Transform3D]
) -> void:
	for child: Node in node.get_children():
		if not found.is_empty():
			return
		var at: Transform3D = into
		var spatial: Node3D = child as Node3D
		if spatial != null:
			at = into * spatial.transform
		if child == target:
			found.append(at)
			return
		_find_below(child, target, at, found)


static func _collect_pieces(node: Node, out: Array[VisualPiece]) -> void:
	for child: Node in node.get_children():
		var piece: VisualPiece = child as VisualPiece
		if piece != null:
			out.append(piece)
		_collect_pieces(child, out)
