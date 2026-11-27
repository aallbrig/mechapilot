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
@export var palette: Dictionary[StringName, Color] = {}
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
		var key: StringName = &""
		if scene_file_path != "":
			key = StringName("%s|%s" % [scene_file_path, get_path_to(piece)])
		piece.bake(palette, key)
	for marker_name: StringName in required_markers():
		if marker(marker_name) == null:
			push_error("%s: missing required marker %%%s" % [name, marker_name])
	if phase_count > 0:
		set_phase(1)
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


## A scene-unique marker or pivot by name, or null if the rig has none.
func marker(marker_name: StringName) -> Node3D:
	return get_node_or_null(NodePath("%" + String(marker_name))) as Node3D


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


static func _collect_pieces(node: Node, out: Array[VisualPiece]) -> void:
	for child: Node in node.get_children():
		var piece: VisualPiece = child as VisualPiece
		if piece != null:
			out.append(piece)
		_collect_pieces(child, out)
