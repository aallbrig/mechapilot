class_name EnemyLook
extends Node3D
## An enemy's model, driven by Enemy and owning no game logic. It shows the
## kind's merged model from the visual pass (VisualLibrary.enemy_for, #27),
## sized so its length matches the hit geometry the rules were tuned on, and the
## state of its muzzle glow through the attack telegraph. The glow itself is
## drawn by the field's TelegraphGlows, one draw for every enemy, so an enemy
## costs just its model's draws. The model kit's contract holds: the nose
## points along +X, the top along +Y, and set_flash() swaps in the shared
## white hit flash.

## The model's length (along +X) at a look_scale of 1, in world units.
const MODEL_LENGTH: float = 2.4
const GLOW_COLOR: Color = Color(1.0, 0.8, 0.2)
## Muzzle glow energy as the telegraph starts and at full charge; the glow's
## size at full charge.
const GLOW_IDLE: float = 0.5
const GLOW_FULL: float = 8.0
const GLOW_GROW: float = 2.2
## How fast the model turns to its heading (1/s).
const TURN_RATE: float = 10.0

var _pivot: Node3D = Node3D.new()
var _model: EnemyVisual
## Where the glow shows: on the muzzle, turning with the model.
var _glow: Node3D = Node3D.new()
var _glow_energy: float = GLOW_IDLE
var _glowing: bool = false
var _flashing: bool = false


## The model of `kind` at `size` times its base scale.
func _init(kind: EnemyKind.Kind, size: float) -> void:
	scale = Vector3.ONE * size
	add_child(_pivot)
	_model = VisualLibrary.enemy_for(kind)
	var length: float = _model.bounds().size.x
	_model.scale = Vector3.ONE * (MODEL_LENGTH / length if length > 0.0 else 1.0)
	_pivot.add_child(_model)
	_pivot.add_child(_glow)
	_glow.position = _model.transform * _model.to_rig(_model.muzzle()).origin
	set_charge(0.0)


## The merged model shown (a VisualLibrary enemy scene).
func model() -> EnemyVisual:
	return _model


## Show the white hit flash, or the normal colours.
func set_flash(on: bool) -> void:
	_flashing = on
	_model.set_flash(on)


func is_flashing() -> bool:
	return _flashing


## The attack telegraph: 0 is idle (no glow), 1 is about to fire.
func set_charge(amount: float) -> void:
	var t: float = clampf(amount, 0.0, 1.0)
	_glow_energy = lerpf(GLOW_IDLE, GLOW_FULL, t)
	_glow.scale = Vector3.ONE * lerpf(1.0, GLOW_GROW, t)
	_glowing = t > 0.0


## The telegraph glow's brightness now (for tests and juice).
func glow_energy() -> float:
	return _glow_energy


## Whether the telegraph glow shows.
func is_glowing() -> bool:
	return _glowing


## The glow's place and size in the world (a unit glow scaled by the charge).
func glow_transform() -> Transform3D:
	return _glow.global_transform


## Turn smoothly toward `heading` (a play-plane direction) over `delta` seconds,
## keeping the top up.
func face(heading: Vector3, delta: float) -> void:
	if heading.length() < FiringSolution.MIN_DISTANCE:
		return
	var angle: float = atan2(heading.y, heading.x)
	var want: Basis = Basis(Vector3.BACK, angle)
	if heading.x < 0.0:
		# Roll over so the top stays up when flying left.
		want = want * Basis(Vector3.RIGHT, PI)
	_pivot.basis = _pivot.basis.slerp(want, 1.0 - exp(-TURN_RATE * delta)).orthonormalized()
