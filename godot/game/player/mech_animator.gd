class_name MechAnimator
extends RefCounted
## Secondary motion for the flying mech (it has no walk cycle). Every limb joint
## is a LimbSpring that chases the pose for the current `fly` blend (LimbPose)
## and lags behind the body's velocity and acceleration: legs trail when it
## speeds up, swing past rest when it brakes and hang loosely when it coasts.
## Recoil and hits kick the springs. The body yaws to face its travel and
## pitches into a lean while thrusting, or tilts lazily while coasting.

## Thrust above which the pose blends toward the thrust group.
const THRUST_POSE_THRESHOLD: float = 0.15
## Body lean toward the direction of travel while thrusting (radians, max fwd / back).
const LEAN_FORWARD_MAX: float = 1.15
const LEAN_BACK_MAX: float = 0.9
const LEAN_GAIN: float = 0.75
## No lean below this speed (units/s).
const LEAN_MIN_SPEED: float = 2.0
## Coasting tilt per unit of climb speed and forward speed, and its limit.
const COAST_TILT_CLIMB: float = 0.025
const COAST_TILT_FORWARD: float = 0.02
const COAST_TILT_MAX: float = 0.5
## How fast the body turns to face its travel (1/s).
const YAW_RATE: float = 12.0
## How far limbs trail per unit of climb speed while coasting.
const CLIMB_LAG: float = 0.03
## Share of the vertical acceleration that pushes the limbs.
const VERTICAL_PUSH: float = 0.4
## How much of the thigh's swing the shin follows (knee coupling).
const SHIN_COUPLING: float = 0.7
const SHIN_COUPLING_SCALE: float = 0.1
const SHIN_COUPLING_THRUST_CUT: float = 0.7
const SHIN_DRIVE: float = 0.4
const ARM_DRIVE: float = 0.7
const ARM_PUSH: float = 0.8
const WING_PUSH: float = 0.2
const WING_SWAY: float = 0.03
const WING_SWAY_RATE: float = 1.7
const WING_ROLL: float = 0.5
const LEG_BOB_RATE: float = 2.4
const ARM_BOB_RATE: float = 2.0
## Lateral acceleration smoothing (1/s), and acceleration estimate blend per frame.
const LATERAL_SMOOTHING: float = 6.0
const ACCEL_BLEND: float = 0.5
## Below this speed the velocity has no direction for lateral g (units/s).
const DIRECTION_MIN_SPEED: float = 0.5
## Angular velocity a unit shove adds to a limb (rad/s), plus random jitter.
const KICK: float = 3.0
const KICK_JITTER: float = 0.6

## 0 = coasting pose, 1 = thrusting pose.
var fly: float = 0.0
## Smoothed acceleration across the direction of travel (units/s^2), for vapor.
var lateral_g: float = 0.0

var _thighs: Array[LimbSpring] = []
var _shins: Array[LimbSpring] = []
var _arms: Array[LimbSpring] = []
var _wings: Array[LimbSpring] = []
var _last_velocity: Vector3 = Vector3.ZERO
var _accel: Vector3 = Vector3.ZERO
var _clock: float = 0.0


func _init(model: MechModel) -> void:
	for i: int in model.thighs.size():
		_thighs.append(_spring(model.thigh_phases[i], model.thigh_gains[i]))
		_shins.append(_spring(0.0, MechModel.SHIN_GAIN))
	for i: int in model.arms.size():
		_arms.append(_spring(model.arm_phases[i], 1.0))
	for i: int in model.wings.size():
		_wings.append(_spring(model.wing_sides[i], 1.0))


## Advance the pose. `velocity` is world space, `facing` is +1 or -1 and
## `thrust` is the move-input magnitude 0..1.
func step(model: MechModel, delta: float, velocity: Vector3, facing: float, thrust: float) -> void:
	if delta <= 0.0:
		return
	_clock += delta
	var raw_accel: Vector3 = (velocity - _last_velocity) / delta
	_last_velocity = velocity
	_accel = _accel.lerp(raw_accel, ACCEL_BLEND)
	var dir: Vector3 = (
		velocity.normalized() if velocity.length() > DIRECTION_MIN_SPEED else Vector3.ZERO
	)
	var lateral: float = (raw_accel - dir * raw_accel.dot(dir)).length()
	lateral_g = lerpf(lateral_g, lateral, 1.0 - exp(-LATERAL_SMOOTHING * delta))
	fly = LimbPose.advance_fly(fly, thrust > THRUST_POSE_THRESHOLD, delta)
	var pose: LimbPose = LimbPose.blend(fly)

	var body: Node3D = model.body
	body.rotation.y = lerp_angle(
		body.rotation.y, MechModel.yaw_for(facing), 1.0 - exp(-YAW_RATE * delta)
	)
	var forward: float = velocity.x * facing
	var lean: float = -clampf(
		atan2(forward, velocity.y) * LEAN_GAIN, -LEAN_BACK_MAX, LEAN_FORWARD_MAX
	)
	if velocity.length() < LEAN_MIN_SPEED:
		lean = 0.0
	var coast_tilt: float = clampf(
		velocity.y * COAST_TILT_CLIMB * facing - forward * COAST_TILT_FORWARD,
		-COAST_TILT_MAX,
		COAST_TILT_MAX
	)
	var pitch: float = lerpf(coast_tilt, lean, fly)
	body.rotation.x = lerpf(body.rotation.x, pitch, 1.0 - exp(-pose.tilt_rate * delta))

	var drive: float = -forward * pose.vel_lag - velocity.y * CLIMB_LAG * (1.0 - fly)
	var push: float = -_accel.x * facing * pose.acc_lag - _accel.y * pose.acc_lag * VERTICAL_PUSH
	var hang: float = -body.rotation.x * pose.hang
	for i: int in _thighs.size():
		var thigh: LimbSpring = _thighs[i]
		var bob: float = sin(_clock * LEG_BOB_RATE + thigh.phase) * pose.bob
		thigh.step(
			pose.thigh_rest + drive * thigh.gain + hang + bob,
			push * thigh.gain,
			pose.leg_spring,
			delta
		)
		var shin: LimbSpring = _shins[i]
		var couple: float = (
			-thigh.velocity
			* SHIN_COUPLING
			* pose.shin_spring.x
			* SHIN_COUPLING_SCALE
			* (1.0 - fly * SHIN_COUPLING_THRUST_CUT)
		)
		shin.step(
			pose.shin_rest + drive * SHIN_DRIVE, push * shin.gain + couple, pose.shin_spring, delta
		)
		model.thighs[i].rotation.x = thigh.angle
		model.shins[i].rotation.x = shin.angle
	for i: int in _arms.size():
		var arm: LimbSpring = _arms[i]
		var bob: float = sin(_clock * ARM_BOB_RATE + arm.phase) * pose.bob
		arm.step(
			pose.arm_rest + drive * ARM_DRIVE + hang + bob, push * ARM_PUSH, pose.arm_spring, delta
		)
		model.arms[i].rotation.x = arm.angle
	for i: int in _wings.size():
		var wing: LimbSpring = _wings[i]
		var sway: float = sin(_clock * WING_SWAY_RATE + wing.phase) * WING_SWAY
		wing.step(pose.wing_rest + sway, push * WING_PUSH, pose.wing_spring, delta)
		model.wings[i].rotation.x = wing.angle
		model.wings[i].rotation.z = wing.phase * wing.angle * WING_ROLL


## Kick every limb as if the body were shoved along world direction `push`.
func impulse(push: Vector3, facing: float, rng: RandomNumberGenerator) -> void:
	var forward: float = push.x * facing
	var limbs: Array[LimbSpring] = []
	limbs.append_array(_thighs)
	limbs.append_array(_shins)
	limbs.append_array(_arms)
	for limb: LimbSpring in limbs:
		var jitter: float = rng.randf_range(-KICK_JITTER, KICK_JITTER)
		limb.kick((-forward - push.y * VERTICAL_PUSH) * KICK * limb.gain + jitter)


## Straighten every limb and forget all motion (respawn).
func reset(model: MechModel) -> void:
	fly = 0.0
	lateral_g = 0.0
	_last_velocity = Vector3.ZERO
	_accel = Vector3.ZERO
	var all: Array[LimbSpring] = []
	all.append_array(_thighs)
	all.append_array(_shins)
	all.append_array(_arms)
	all.append_array(_wings)
	for limb: LimbSpring in all:
		limb.reset()
	var joints: Array[Node3D] = []
	joints.append_array(model.thighs)
	joints.append_array(model.shins)
	joints.append_array(model.arms)
	joints.append_array(model.wings)
	for joint: Node3D in joints:
		joint.rotation = Vector3.ZERO
	model.body.rotation.x = 0.0


## The current angle of thigh `index`, for tests and debugging.
func thigh_angle(index: int) -> float:
	return _thighs[index].angle


func _spring(phase: float, gain: float) -> LimbSpring:
	var s: LimbSpring = LimbSpring.new()
	s.phase = phase
	s.gain = gain
	return s
