class_name Explosion
extends Node3D
## One pooled explosion (#26), ported from the LAN prototype's feel: a white-hot
## flash, a burst of sparks that cool to the blast colour, tumbling debris that
## falls under gravity, and a shock ring. ExplosionPool owns it: play() starts
## it, advance() runs it, and it reports `finished` once, after LIFETIME.
## Everything is built once and reused. Unshaded and additive, so it is cheap
## in the Compatibility renderer.

## Reported once per play(), when the blast is over and it can be reused.
signal finished(explosion: Explosion)

## How long one blast lasts (s), debris included.
const LIFETIME: float = 1.2
const SPARK_COUNT: int = 40
const SPARK_LIFETIME: float = 0.75
const SPARK_SIZE: float = 0.5
const SPARK_SPEED: Vector2 = Vector2(7.0, 26.0)
const SPARK_DAMPING: Vector2 = Vector2(10.0, 20.0)
const SPARK_SCALE: Vector2 = Vector2(0.5, 1.5)
const SPARK_SPIN: float = 400.0
const DEBRIS_COUNT: int = 10
const DEBRIS_LIFETIME: float = 1.1
const DEBRIS_SIZE: float = 0.35
const DEBRIS_SPEED: Vector2 = Vector2(5.0, 13.0)
const DEBRIS_GRAVITY: Vector3 = Vector3(0.0, -18.0, 0.0)
const DEBRIS_SPIN: float = 540.0
const DEBRIS_COLOR: Color = Color(0.22, 0.2, 0.2)
## The flash: how long it lasts and how big it grows (units, before size).
const FLASH_SECONDS: float = 0.18
const FLASH_RADIUS: Vector2 = Vector2(0.6, 2.4)
## The shock ring: how long it takes to spread, and its final radius.
const RING_SECONDS: float = 0.3
const RING_RADIUS: float = 4.0
const RING_START: float = 0.3
## The ring is drawn just in front of the play plane, toward the camera.
const RING_LIFT: float = 0.5
const SPARK_RAMP_MID: float = 0.25
const SPARK_TAIL_DARKEN: float = 0.3

var _sparks: CPUParticles3D = CPUParticles3D.new()
var _debris: CPUParticles3D = CPUParticles3D.new()
var _flash: MeshInstance3D = MeshInstance3D.new()
var _ring: MeshInstance3D = MeshInstance3D.new()
var _flash_material: StandardMaterial3D = _additive_material()
var _ring_material: StandardMaterial3D = _additive_material()
var _ramp: Gradient = Gradient.new()
var _age: float = 0.0
var _size: float = 1.0
var _color: Color = Color.WHITE
var _active: bool = false
var _flashes: bool = true


func _init() -> void:
	_build_sparks()
	_build_debris()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	_flash.mesh = sphere
	_flash.material_override = _flash_material
	add_child(_flash)
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.material_override = _ring_material
	_ring.rotation.x = PI * 0.5
	_ring.position.z = RING_LIFT
	add_child(_ring)
	_hide()


## Start a blast at `at`, `blast_size` times the base size, in `color`.
## With `flashes` off (reduced motion) there is no flash and no ring.
func play(at: Vector3, blast_size: float, color: Color, flashes: bool) -> void:
	position = at
	_size = blast_size
	_color = color
	_flashes = flashes
	_age = 0.0
	_active = true
	visible = true
	var tail: Color = color.darkened(1.0 - SPARK_TAIL_DARKEN)
	tail.a = 0.0
	_ramp.colors = PackedColorArray([Color.WHITE, color, tail])
	_sparks.initial_velocity_min = SPARK_SPEED.x * blast_size
	_sparks.initial_velocity_max = SPARK_SPEED.y * blast_size
	_sparks.scale_amount_min = SPARK_SCALE.x * blast_size
	_sparks.scale_amount_max = SPARK_SCALE.y * blast_size
	_debris.initial_velocity_min = DEBRIS_SPEED.x * blast_size
	_debris.initial_velocity_max = DEBRIS_SPEED.y * blast_size
	_debris.scale_amount_min = blast_size
	_debris.scale_amount_max = blast_size * 1.6
	_sparks.restart()
	_debris.restart()
	_flash.visible = flashes
	_ring.visible = flashes
	_animate()


## Run the blast on by `delta` seconds.
func advance(delta: float) -> void:
	if not _active:
		return
	_age += delta
	if _age >= LIFETIME:
		_active = false
		_hide()
		finished.emit(self)
		return
	_animate()


func is_active() -> bool:
	return _active


## The blast's size factor and colour (for the pool and tests).
func size_factor() -> float:
	return _size


func tint() -> Color:
	return _color


func flash_visible() -> bool:
	return _flash.visible


func _animate() -> void:
	var flash_t: float = clampf(_age / FLASH_SECONDS, 0.0, 1.0)
	_flash.visible = _flashes and flash_t < 1.0
	var radius: float = lerpf(FLASH_RADIUS.x, FLASH_RADIUS.y, ease(flash_t, 0.4)) * _size
	_flash.scale = Vector3.ONE * radius * 2.0
	_flash_material.albedo_color = Color(1.0, 0.95, 0.85, 1.0 - flash_t)
	var ring_t: float = clampf(_age / RING_SECONDS, 0.0, 1.0)
	_ring.visible = _flashes and ring_t < 1.0
	_ring.scale = Vector3.ONE * lerpf(RING_START, RING_RADIUS * _size, ease(ring_t, 0.2))
	var ring_color: Color = _color.lightened(0.4)
	ring_color.a = 1.0 - ring_t
	_ring_material.albedo_color = ring_color


func _hide() -> void:
	visible = false
	_sparks.emitting = false
	_debris.emitting = false


func _build_sparks() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE * SPARK_SIZE
	var material: StandardMaterial3D = _additive_material()
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = material
	_sparks.mesh = quad
	_sparks.amount = SPARK_COUNT
	_sparks.lifetime = SPARK_LIFETIME
	_sparks.one_shot = true
	_sparks.explosiveness = 1.0
	_sparks.emitting = false
	_sparks.local_coords = false
	_sparks.direction = Vector3.UP
	_sparks.spread = 180.0
	_sparks.gravity = Vector3.ZERO
	_sparks.damping_min = SPARK_DAMPING.x
	_sparks.damping_max = SPARK_DAMPING.y
	_sparks.angular_velocity_min = -SPARK_SPIN
	_sparks.angular_velocity_max = SPARK_SPIN
	_sparks.scale_amount_curve = _fade_curve()
	_ramp.offsets = PackedFloat32Array([0.0, SPARK_RAMP_MID, 1.0])
	_ramp.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color.TRANSPARENT])
	_sparks.color_ramp = _ramp
	add_child(_sparks)


func _build_debris() -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE * DEBRIS_SIZE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	box.material = material
	_debris.mesh = box
	_debris.amount = DEBRIS_COUNT
	_debris.lifetime = DEBRIS_LIFETIME
	_debris.one_shot = true
	_debris.explosiveness = 1.0
	_debris.emitting = false
	_debris.local_coords = false
	_debris.direction = Vector3.UP
	_debris.spread = 180.0
	_debris.gravity = DEBRIS_GRAVITY
	_debris.angular_velocity_min = -DEBRIS_SPIN
	_debris.angular_velocity_max = DEBRIS_SPIN
	_debris.color = DEBRIS_COLOR
	add_child(_debris)


static func _fade_curve() -> Curve:
	var curve: Curve = Curve.new()
	var _start: int = curve.add_point(Vector2(0.0, 1.0))
	var _end: int = curve.add_point(Vector2(1.0, 0.0))
	return curve


static func _additive_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.disable_fog = true
	return material
