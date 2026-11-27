class_name FlameParticles
extends RefCounted
## Particle emitters for the mech's juice: thruster sparks and smoke, and the
## faint motion trails behind the three red eyes. Meshes are shared.

const SPARK_COLOR_START: Color = Color(1.0, 0.95, 0.6, 1.0)
const SPARK_COLOR_END: Color = Color(1.0, 0.35, 0.05, 0.0)
const SPARK_QUAD: float = 0.14
const SPARK_AMOUNT: int = 6
const SPARK_LIFE: float = 0.22
const SPARK_SPREAD: float = 14.0
const SPARK_GRAVITY: Vector3 = Vector3(0.0, -6.0, 0.0)
const SPARK_SPEED: Vector2 = Vector2(10.0, 18.0)
const SPARK_SCALE: Vector2 = Vector2(0.5, 1.0)

const SMOKE_COLOR_START: Color = Color(0.95, 0.9, 0.85, 0.3)
const SMOKE_COLOR_END: Color = Color(0.5, 0.5, 0.55, 0.0)
const SMOKE_QUAD: float = 0.6
const SMOKE_AMOUNT: int = 6
const SMOKE_LIFE: float = 0.9
const SMOKE_SPREAD: float = 20.0
const SMOKE_GRAVITY: Vector3 = Vector3(0.0, 0.6, 0.0)
const SMOKE_SPEED: Vector2 = Vector2(1.0, 2.5)
const SMOKE_DAMPING: Vector2 = Vector2(1.0, 2.0)
const SMOKE_SCALE: Vector2 = Vector2(0.5, 0.9)
const SMOKE_GROWTH: Vector2 = Vector2(0.4, 1.8)

const EYE_COLOR: Color = Color(1.0, 0.15, 0.1)
const EYE_COLOR_START: Color = Color(1.0, 0.2, 0.15, 0.5)
const EYE_COLOR_END: Color = Color(1.0, 0.1, 0.1, 0.0)
const EYE_QUAD: float = 0.12
const EYE_AMOUNT: int = 8
const EYE_LIFE: float = 0.22
const EYE_SHRINK: float = 0.2
const SOFT_TEXTURE_SIZE: int = 32

static var _spark_mesh: QuadMesh
static var _smoke_mesh: QuadMesh
static var _eye_mesh: QuadMesh


static func sparks(size: float) -> CPUParticles3D:
	if _spark_mesh == null:
		_spark_mesh = _soft_quad(Color.WHITE, SPARK_QUAD, true)
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = SPARK_AMOUNT
	p.lifetime = SPARK_LIFE
	p.local_coords = false
	p.mesh = _spark_mesh
	p.direction = Vector3.UP
	p.spread = SPARK_SPREAD
	p.gravity = SPARK_GRAVITY
	p.initial_velocity_min = SPARK_SPEED.x * size
	p.initial_velocity_max = SPARK_SPEED.y * size
	p.scale_amount_min = SPARK_SCALE.x
	p.scale_amount_max = SPARK_SCALE.y
	p.color_ramp = _ramp(SPARK_COLOR_START, SPARK_COLOR_END)
	p.emitting = false
	return p


static func smoke(size: float) -> CPUParticles3D:
	if _smoke_mesh == null:
		_smoke_mesh = _soft_quad(Color.WHITE, SMOKE_QUAD, false)
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = SMOKE_AMOUNT
	p.lifetime = SMOKE_LIFE
	p.local_coords = false
	p.mesh = _smoke_mesh
	p.position = Vector3(0.0, size, 0.0)
	p.direction = Vector3.UP
	p.spread = SMOKE_SPREAD
	p.gravity = SMOKE_GRAVITY
	p.initial_velocity_min = SMOKE_SPEED.x
	p.initial_velocity_max = SMOKE_SPEED.y
	p.damping_min = SMOKE_DAMPING.x
	p.damping_max = SMOKE_DAMPING.y
	p.scale_amount_min = SMOKE_SCALE.x * size
	p.scale_amount_max = SMOKE_SCALE.y * size
	p.scale_amount_curve = _curve(SMOKE_GROWTH.x, SMOKE_GROWTH.y)
	p.color_ramp = _ramp(SMOKE_COLOR_START, SMOKE_COLOR_END)
	p.emitting = false
	return p


## A short red streak that trails an eye through world space.
static func eye_trail() -> CPUParticles3D:
	if _eye_mesh == null:
		_eye_mesh = _soft_quad(EYE_COLOR, EYE_QUAD, true)
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = EYE_AMOUNT
	p.lifetime = EYE_LIFE
	p.local_coords = false
	p.mesh = _eye_mesh
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.scale_amount_curve = _curve(1.0, EYE_SHRINK)
	p.color_ramp = _ramp(EYE_COLOR_START, EYE_COLOR_END)
	p.emitting = false
	return p


static func _ramp(start: Color, end: Color) -> Gradient:
	var g: Gradient = Gradient.new()
	g.set_color(0, start)
	g.set_color(1, end)
	return g


static func _curve(start: float, end: float) -> Curve:
	var c: Curve = Curve.new()
	c.max_value = maxf(maxf(start, end), 1.0)
	var _a: int = c.add_point(Vector2(0.0, start))
	var _b: int = c.add_point(Vector2(1.0, end))
	return c


static func _soft_quad(color: Color, quad_size: float, additive: bool) -> QuadMesh:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE * quad_size
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var soft: GradientTexture2D = GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.gradient = _ramp(Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	soft.width = SOFT_TEXTURE_SIZE
	soft.height = SOFT_TEXTURE_SIZE
	m.albedo_texture = soft
	q.material = m
	return q
