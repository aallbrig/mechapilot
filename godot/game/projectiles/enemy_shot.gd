class_name EnemyShot
extends Node3D
## One enemy or boss projectile in flight: it falls under its spec's gravity,
## homes if its spec says so, and points along its velocity. EnemyShotPool owns
## and recycles it and steps it from its own tick, so motion is deterministic.
## It draws nothing itself: the pool draws every live shot of a style as one
## MultiMesh (one draw per style, #84's draw-call budget).

## Glowing colours per style, and the drawn size per style (units).
const STYLE_COLORS: Dictionary[ShotSpec.Style, Color] = {
	ShotSpec.Style.BULLET: Color(1.0, 0.35, 0.2),
	ShotSpec.Style.SHELL: Color(1.0, 0.6, 0.1),
	ShotSpec.Style.BOMB: Color(0.95, 0.2, 0.15),
	ShotSpec.Style.MISSILE: Color(1.0, 0.85, 0.3),
	ShotSpec.Style.BOLT: Color(1.0, 0.2, 0.6),
}
const STYLE_SIZES: Dictionary[ShotSpec.Style, Vector3] = {
	ShotSpec.Style.BULLET: Vector3(0.3, 0.3, 0.9),
	ShotSpec.Style.SHELL: Vector3(0.5, 0.5, 0.7),
	ShotSpec.Style.BOMB: Vector3(0.6, 0.6, 0.9),
	ShotSpec.Style.MISSILE: Vector3(0.35, 0.35, 1.2),
	ShotSpec.Style.BOLT: Vector3(0.6, 0.6, 1.6),
}
const GLOW: float = 4.0
## Below this speed (units/s) the shot keeps its last orientation.
const MIN_ORIENT_SPEED: float = 1e-3

static var _mesh: BoxMesh
static var _material: StandardMaterial3D

var spec: ShotSpec
var velocity: Vector3 = Vector3.ZERO
var life_left: float = 0.0


func _init() -> void:
	park()


## Start flying from `origin` at `launch_velocity` as `shot_spec` describes.
func launch(shot_spec: ShotSpec, origin: Vector3, launch_velocity: Vector3) -> void:
	spec = shot_spec
	position = Vector3(origin.x, origin.y, 0.0)
	velocity = Vector3(launch_velocity.x, launch_velocity.y, 0.0)
	life_left = shot_spec.life
	visible = true
	_orient()


## Out of play: hidden and inert until the pool reuses it.
func park() -> void:
	life_left = 0.0
	velocity = Vector3.ZERO
	visible = false


func is_live() -> bool:
	return life_left > 0.0


## Advance `delta` seconds. A homing shot turns toward `homing_target`.
func step(delta: float, homing_target: Vector3, homing_on: bool) -> void:
	if not is_live():
		return
	if homing_on and spec.homing > 0.0:
		var want: Vector3 = FiringSolution.aimed(position, homing_target) * velocity.length()
		velocity = velocity.lerp(want, 1.0 - exp(-spec.homing * delta))
	velocity = Ballistics.fall(velocity, spec.gravity, delta)
	position += velocity * delta
	position.z = 0.0
	_orient()
	life_left = maxf(life_left - delta, 0.0)
	if life_left <= 0.0:
		park()


func _orient() -> void:
	if velocity.length() > MIN_ORIENT_SPEED:
		basis = Basis.looking_at(velocity.normalized(), Vector3.BACK)


## The unit box every shot is drawn with (the pool scales it per style).
static func unit_mesh() -> BoxMesh:
	if _mesh == null:
		_mesh = BoxMesh.new()
		_mesh.size = Vector3.ONE
	return _mesh


## The glowing material every shot shares: unshaded, coloured per instance.
static func shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.vertex_color_use_as_albedo = true
	return _material


## A style's colour at its glow (HDR, so the Environment's glow blooms it).
static func shine(style: ShotSpec.Style) -> Color:
	var lit: Color = STYLE_COLORS[style] * GLOW
	lit.a = 1.0
	return lit
