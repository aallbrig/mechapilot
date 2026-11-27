class_name CloudField
extends Node3D
## Parallax cloud puffs behind the play plane, so speed and direction read at a
## glance. Perspective does the parallax: deeper puffs drift slower on screen.
## Puffs wrap around the camera focus, so the sky never runs out. The visual
## pass (#27) replaces the look; the motion reference stays.

const COUNT: int = 48
const SPAN: Vector2 = Vector2(230.0, 150.0)
const DEPTH: Vector2 = Vector2(-62.0, -12.0)
const SIZE: Vector2 = Vector2(2.0, 6.0)
## Near puffs are bigger and more opaque than far ones.
const NEAR_GROWTH: float = 2.0
const ALPHA: Vector2 = Vector2(0.1, 0.45)
const ALPHA_STEP: float = 0.05
const STRETCH: Vector2 = Vector2(1.6, 3.0)
const FLATTEN: Vector2 = Vector2(0.45, 0.6)
const SEGMENTS: int = 14
const RINGS: int = 7

var _puffs: Array[Node3D] = []


## Scatter the puffs with `rng`, so a seeded run always has the same sky.
func scatter(rng: RandomNumberGenerator) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radial_segments = SEGMENTS
	mesh.rings = RINGS
	var materials: Dictionary[float, StandardMaterial3D] = {}
	for _i: int in COUNT:
		var depth: float = rng.randf_range(DEPTH.x, DEPTH.y)
		var near: float = inverse_lerp(DEPTH.x, DEPTH.y, depth)
		var alpha: float = snappedf(lerpf(ALPHA.y, ALPHA.x, near), ALPHA_STEP)
		if not materials.has(alpha):
			materials[alpha] = _material(alpha)
		var puff: MeshInstance3D = MeshInstance3D.new()
		puff.mesh = mesh
		puff.material_override = materials[alpha]
		var s: float = rng.randf_range(SIZE.x, SIZE.y) * lerpf(1.0, NEAR_GROWTH, near)
		puff.scale = Vector3(
			s * rng.randf_range(STRETCH.x, STRETCH.y), s * FLATTEN.x, s * FLATTEN.y
		)
		puff.position = Vector3(
			rng.randf_range(-0.5, 0.5) * SPAN.x, rng.randf_range(-0.5, 0.5) * SPAN.y, depth
		)
		add_child(puff)
		_puffs.append(puff)


## Keep every puff within half a span of `focus`.
func wrap_around(focus: Vector3) -> void:
	for puff: Node3D in _puffs:
		var d: Vector3 = puff.position - focus
		if d.x > SPAN.x * 0.5:
			puff.position.x -= SPAN.x
		elif d.x < -SPAN.x * 0.5:
			puff.position.x += SPAN.x
		if d.y > SPAN.y * 0.5:
			puff.position.y -= SPAN.y
		elif d.y < -SPAN.y * 0.5:
			puff.position.y += SPAN.y


func _material(alpha: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	return m
