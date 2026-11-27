class_name PlayerMech
extends Node3D
## The player's flying mech on the XY play plane. Each physics tick it reads a
## PilotIntent, flies by FlightModel, aims independently of its travel, fires
## gravity shots into its ShotPool and animates its spring limbs.
##
## Damage: take_hit() starts the invulnerability window (it blinks), flashes the
## model white, knocks it back and kicks the limbs. The armor itself is the Run
## ledger's (#21): the mech reports hits and repairs as signals, which
## PlayerBusLink publishes as Game Events. destroy() plays the death ragdoll.
##
## It reaches only the nodes it is given: `input`, `shots`, `debris` and `view`.

## A shot left the muzzle.
signal fired(origin: Vector3, direction: Vector3)
## A hit landed (outside the invulnerability window).
signal hit_taken(damage: int, position: Vector3)
## A repair kit was collected.
signal repaired(amount: int, position: Vector3)
## The mech broke apart.
signal destroyed(position: Vector3)
## The mech is back in play.
signal respawned(position: Vector3)
## One frame of motion, for flames, vapor and eye trails (feedback/).
signal motion_sampled(sample: MechMotionSample)

## Aim at a cursor or tap only when it is at least this far from the mech (units).
const MIN_POINT_AIM: float = 0.5
## Cooldown slack, so float drift never delays a shot by a whole tick (s).
const FIRE_EPSILON: float = 1e-6

@export var tuning: MechTuning = MechTuning.new()

## Where intents come from; without one the mech coasts.
var input: PlayerInput
## Where shots go; without one the mech still reports `fired`.
var shots: ShotPool
## Where the death ragdoll goes.
var debris: MechDebris
## The camera, to turn cursor and tap points into aim directions.
var view: CameraRig
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var velocity: Vector3 = Vector3.ZERO
## +1 faces right, -1 faces left.
var facing: float = 1.0
## The last aim on the play plane (unit length).
var aim_direction: Vector3 = Vector3.RIGHT
var thrust: float = 0.0

var _model: MechModel = MechModel.new()
var _animator: MechAnimator
var _guard: InvulnerabilityWindow = InvulnerabilityWindow.new()
var _cooldown: float = 0.0
var _since_shot: float = INF
var _flash_left: float = 0.0
var _alive: bool = true


func _init() -> void:
	_model.scale = Vector3.ONE * tuning.mech_scale
	add_child(_model)
	_animator = MechAnimator.new(_model)
	velocity = tuning.spawn_velocity


func _ready() -> void:
	# The tuning may have been replaced after _init (an inspector override).
	_model.scale = Vector3.ONE * tuning.mech_scale


func _physics_process(delta: float) -> void:
	if input != null:
		tick(delta, input.read_intent())
	else:
		tick(delta, PilotIntent.new())


## Advance one tick under `intent`.
func tick(delta: float, intent: PilotIntent) -> void:
	if not _alive or delta <= 0.0:
		return
	_guard.tick(delta)
	_model.visible = _guard.blink_visible(tuning.blink_rate, tuning.blink_hidden_share)
	if _flash_left > 0.0:
		_flash_left -= delta
		_model.set_flash(_flash_left > 0.0)

	thrust = minf(intent.move.length(), 1.0)
	velocity = FlightModel.step_velocity(velocity, intent.move, delta, tuning)
	position += velocity * delta
	position.z = 0.0

	_cooldown = maxf(_cooldown - delta, 0.0)
	_since_shot += delta
	if absf(velocity.x) > tuning.facing_speed and _since_shot > tuning.facing_fire_hold:
		facing = signf(velocity.x)
	_update_aim(intent)
	if intent.firing:
		_face_aim()
		if _cooldown <= FIRE_EPSILON:
			_fire()
	elif intent.has_tap and _aim_at_point(intent.tap_point):
		_face_aim()
		_fire()

	_animator.step(_model, delta, velocity, facing, thrust)
	var want: Basis = Basis.looking_at(aim_direction, Vector3.BACK)
	_model.gun_pivot.basis = (
		_model
		. gun_pivot
		. basis
		. slerp(want, 1.0 - exp(-tuning.gun_turn_rate * delta))
		. orthonormalized()
	)
	motion_sampled.emit(_sample(delta))


## Take `damage` from a hit travelling along `direction`. Returns false (and does
## nothing) while invulnerable or destroyed.
func take_hit(damage: int, direction: Vector3) -> bool:
	if not _alive or _guard.is_active():
		return false
	_guard.start(tuning.hit_invulnerability)
	var push: Vector3 = Vector3(direction.x, direction.y, 0.0)
	if push.length_squared() > 0.0:
		velocity += push.normalized() * tuning.knockback
		_animator.impulse(push.normalized(), facing, rng)
	_flash_left = tuning.hit_flash_time
	_model.set_flash(true)
	hit_taken.emit(damage, global_position)
	return true


## Collect a repair kit worth `amount` armor.
func repair(amount: int) -> void:
	if not _alive:
		return
	repaired.emit(amount, global_position)


## Break apart into the death ragdoll. The mech stays hidden until respawn().
func destroy() -> void:
	if not _alive:
		return
	_alive = false
	if debris != null:
		debris.burst(_model.meshes(), _model.global_position, velocity, rng)
	_model.visible = false
	_model.set_flash(false)
	destroyed.emit(global_position)


## Back in play at `at`, at rest, with the respawn invulnerability.
func respawn(at: Vector3) -> void:
	_alive = true
	position = Vector3(at.x, at.y, 0.0)
	velocity = Vector3.ZERO
	facing = 1.0
	aim_direction = Vector3.RIGHT
	_cooldown = 0.0
	_since_shot = INF
	_flash_left = 0.0
	_model.set_flash(false)
	_model.visible = true
	_animator.reset(_model)
	_guard.clear()
	_guard.start(tuning.respawn_invulnerability)
	respawned.emit(global_position)


func is_alive() -> bool:
	return _alive


func is_invulnerable() -> bool:
	return _guard.is_active()


func contact_radius() -> float:
	return tuning.contact_radius()


func model() -> MechModel:
	return _model


func animator() -> MechAnimator:
	return _animator


func _update_aim(intent: PilotIntent) -> void:
	if intent.aim != Vector2.ZERO:
		aim_direction = Vector3(intent.aim.x, intent.aim.y, 0.0).normalized()
	elif intent.has_aim_point:
		var _aimed: bool = _aim_at_point(intent.aim_point)


## Aim at a screen point through the camera. False when there is no camera or
## the point is too close to the mech to give a direction.
func _aim_at_point(screen_point: Vector2) -> bool:
	if view == null:
		return false
	var to_point: Vector3 = view.screen_to_play_plane(screen_point) - global_position
	to_point.z = 0.0
	if to_point.length() < MIN_POINT_AIM:
		return false
	aim_direction = to_point.normalized()
	return true


func _face_aim() -> void:
	if absf(aim_direction.x) > tuning.facing_aim:
		facing = signf(aim_direction.x)


func _fire() -> void:
	_cooldown += tuning.fire_interval
	_since_shot = 0.0
	var spread: float = rng.randf_range(-tuning.shot_spread, tuning.shot_spread)
	var dir: Vector3 = aim_direction.rotated(Vector3.BACK, spread)
	var muzzle: Vector3 = _model.muzzle_position() if _model.is_inside_tree() else global_position
	var launch: Vector3 = Ballistics.launch_velocity(
		dir, velocity, tuning.shot_speed, tuning.shot_inherit
	)
	if shots != null:
		var _shot: PlayerShot = shots.fire(muzzle, launch, tuning.shot_life, tuning.shot_gravity)
	velocity -= dir * tuning.recoil
	_animator.impulse(-dir, facing, rng)
	fired.emit(muzzle, dir)


func _sample(delta: float) -> MechMotionSample:
	var s: MechMotionSample = MechMotionSample.new()
	s.position = global_position if is_inside_tree() else position
	s.velocity = velocity
	s.lateral_g = _animator.lateral_g
	s.thrust = thrust
	s.wing_tips = _model.wing_tip_positions() if _model.is_inside_tree() else PackedVector3Array()
	s.scale = tuning.mech_scale
	s.delta = delta
	return s
