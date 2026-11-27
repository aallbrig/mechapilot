class_name CloudLayer
extends MultiMeshInstance3D
## One parallax layer of cloud puffs at a fixed depth behind the play plane,
## drawn as a single MultiMesh (one draw call). Perspective gives the parallax:
## deeper layers move slower on screen. The puffs wrap around the focus (the
## player or camera) on both axes, so the sky never runs out however far the
## player flies, and they drift with the wind. Placement is seeded, so a layer
## always looks the same.

## Lobes per puff mesh, and their spread (in puff radii).
const PUFF_LOBES: int = 7
const PUFF_SPREAD: Vector2 = Vector2(1.0, 0.45)
const PUFF_LOBE_SCALE: Vector2 = Vector2(0.55, 1.0)
const PUFF_SEGMENTS: int = 10
const PUFF_RINGS: int = 5
## The flattened depth of a puff relative to its width.
const PUFF_DEPTH_RATIO: float = 0.6
const PUFF_HEIGHT_RATIO: float = 0.75

## Puffs in the layer.
@export_range(1, 256) var count: int = 24
## The wrap window (width, height) centred on the focus, in world units.
@export var span: Vector2 = Vector2(200.0, 120.0)
## The layer's z (negative is behind the play plane).
@export var depth: float = -30.0
## Puff size range (world units, the puff's half-width before stretching).
@export var size_range: Vector2 = Vector2(2.0, 5.0)
## How much wider than tall the puffs are (min, max).
@export var stretch_range: Vector2 = Vector2(1.6, 3.0)
## Opacity of the puffs (carried in each instance's colour alpha).
@export_range(0.0, 1.0) var opacity: float = 0.35
## Drift in world units per second.
@export var wind: Vector2 = Vector2(-1.0, 0.0)
## Seed for placement, sizes and the puff shape.
@export var seed_value: int = 1

var _anchors: PackedVector2Array = PackedVector2Array()
var _bases: Array[Basis] = []
var _positions: PackedVector2Array = PackedVector2Array()
var _focus: Vector2 = Vector2.ZERO
var _drift: Vector2 = Vector2.ZERO


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	_anchors.clear()
	_bases.clear()
	for i: int in count:
		var _anchor: bool = _anchors.push_back(
			Vector2(rng.randf_range(-0.5, 0.5) * span.x, rng.randf_range(-0.5, 0.5) * span.y)
		)
		var size: float = rng.randf_range(size_range.x, size_range.y)
		var stretch: float = rng.randf_range(stretch_range.x, stretch_range.y)
		_bases.append(
			Basis.from_scale(
				Vector3(size * stretch, size * PUFF_HEIGHT_RATIO, size * PUFF_DEPTH_RATIO)
			)
		)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _puff_mesh(rng)
	mm.instance_count = count
	for i: int in count:
		mm.set_instance_color(i, Color(1.0, 1.0, 1.0, opacity))
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The layer moves its puffs, not itself: never cull it as one small box.
	custom_aabb = AABB(Vector3(-span.x, -span.y, depth - 1.0) * 0.5, Vector3(span.x, span.y, 2.0))
	_apply()


func _process(delta: float) -> void:
	# Kept inside one span so it never grows large enough to lose precision.
	_drift = (_drift + wind * delta).posmodv(span)
	_apply()


## Centre the wrap window on a new focus (the player or camera position).
func follow(focus: Vector2) -> void:
	_focus = focus
	_apply()


## Where each puff currently is (x, y), after drift and wrapping.
func puff_positions() -> PackedVector2Array:
	return _positions.duplicate()


## Wrap a point into the window of the given span centred on focus, on both axes.
static func wrap_point(point: Vector2, focus: Vector2, window: Vector2) -> Vector2:
	return Vector2(
		focus.x + wrapf(point.x - focus.x, -window.x * 0.5, window.x * 0.5),
		focus.y + wrapf(point.y - focus.y, -window.y * 0.5, window.y * 0.5)
	)


func _apply() -> void:
	if multimesh == null:
		return
	var _sized: int = _positions.resize(count)
	for i: int in count:
		var at: Vector2 = wrap_point(_anchors[i] + _drift, _focus, span)
		_positions[i] = at
		multimesh.set_instance_transform(i, Transform3D(_bases[i], Vector3(at.x, at.y, depth)))
	custom_aabb = AABB(
		Vector3(_focus.x - span.x * 0.5, _focus.y - span.y * 0.5, depth - 1.0),
		Vector3(span.x, span.y, 2.0)
	)


## A puff: a few overlapping low-poly spheres in a flattened row.
func _puff_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radial_segments = PUFF_SEGMENTS
	sphere.rings = PUFF_RINGS
	var shapes: Array[PrimitiveMesh] = []
	var xforms: Array[Transform3D] = []
	var colors: PackedColorArray = PackedColorArray()
	for i: int in PUFF_LOBES:
		var t: float = (float(i) / float(PUFF_LOBES - 1)) * 2.0 - 1.0
		var lobe: float = (
			rng.randf_range(PUFF_LOBE_SCALE.x, PUFF_LOBE_SCALE.y) * (1.0 - absf(t) * 0.4)
		)
		var at: Vector3 = Vector3(t * PUFF_SPREAD.x, rng.randf_range(0.0, PUFF_SPREAD.y), 0.0)
		shapes.append(sphere)
		xforms.append(Transform3D(Basis.from_scale(Vector3.ONE * lobe), at))
		var _added: bool = colors.push_back(Color.WHITE)
	return MeshBaker.bake_shapes(shapes, xforms, colors)
