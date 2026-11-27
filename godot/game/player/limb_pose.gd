class_name LimbPose
extends RefCounted
## The two tuning groups for the mech's spring limbs, from the LAN prototype.
## THRUST_* (move input held): a streamlined flying pose with stiff, damped springs.
## COAST_* (input released): loose springs, so limbs dangle and flail with momentum.
## blend(fly) interpolates every value; `fly` moves between 0 (coast) and 1 (thrust)
## over POSE_BLEND_TIME. Joint angles are rotation.x in the body frame: positive
## swings a hanging limb forward, negative trails it back. Springs are
## Vector2(stiffness 1/s^2, damping 1/s).

const POSE_BLEND_TIME: float = 0.15

const THRUST_THIGH_REST: float = -0.6
const THRUST_SHIN_REST: float = -0.08
const THRUST_ARM_REST: float = -0.75
const THRUST_WING_REST: float = 0.35
const THRUST_LEG_SPRING: Vector2 = Vector2(95.0, 17.0)
const THRUST_SHIN_SPRING: Vector2 = Vector2(120.0, 18.0)
const THRUST_ARM_SPRING: Vector2 = Vector2(100.0, 17.0)
const THRUST_WING_SPRING: Vector2 = Vector2(80.0, 13.0)
## How far limbs trail per unit of forward speed, and per unit of acceleration.
const THRUST_VEL_LAG: float = 0.012
const THRUST_ACC_LAG: float = 0.1
## How fast the body pitches into the lean (1/s).
const THRUST_TILT_RATE: float = 9.0

const COAST_THIGH_REST: float = 0.15
const COAST_SHIN_REST: float = -0.45
const COAST_ARM_REST: float = 0.15
const COAST_WING_REST: float = -0.3
const COAST_LEG_SPRING: Vector2 = Vector2(14.0, 1.0)
const COAST_SHIN_SPRING: Vector2 = Vector2(18.0, 1.2)
const COAST_ARM_SPRING: Vector2 = Vector2(12.0, 0.8)
const COAST_WING_SPRING: Vector2 = Vector2(16.0, 1.5)
const COAST_VEL_LAG: float = 0.05
const COAST_ACC_LAG: float = 0.5
## How strongly dangling limbs keep pointing at world-down as the body tilts.
const COAST_GRAVITY: float = 0.85
## Amplitude of the idle bob while coasting (radians).
const COAST_BOB: float = 0.06
## Lazy body tilt follow rate while coasting (1/s).
const COAST_TILT_RATE: float = 1.5

var thigh_rest: float = COAST_THIGH_REST
var shin_rest: float = COAST_SHIN_REST
var arm_rest: float = COAST_ARM_REST
var wing_rest: float = COAST_WING_REST
var leg_spring: Vector2 = COAST_LEG_SPRING
var shin_spring: Vector2 = COAST_SHIN_SPRING
var arm_spring: Vector2 = COAST_ARM_SPRING
var wing_spring: Vector2 = COAST_WING_SPRING
var vel_lag: float = COAST_VEL_LAG
var acc_lag: float = COAST_ACC_LAG
var tilt_rate: float = COAST_TILT_RATE
## Share of the body tilt that dangling limbs cancel (0 when thrusting).
var hang: float = COAST_GRAVITY
## Idle bob amplitude (0 when thrusting).
var bob: float = COAST_BOB


## The pose at `fly` (clamped to 0..1): 0 is the coast group, 1 the thrust group.
static func blend(fly: float) -> LimbPose:
	var t: float = clampf(fly, 0.0, 1.0)
	var p: LimbPose = LimbPose.new()
	p.thigh_rest = lerpf(COAST_THIGH_REST, THRUST_THIGH_REST, t)
	p.shin_rest = lerpf(COAST_SHIN_REST, THRUST_SHIN_REST, t)
	p.arm_rest = lerpf(COAST_ARM_REST, THRUST_ARM_REST, t)
	p.wing_rest = lerpf(COAST_WING_REST, THRUST_WING_REST, t)
	p.leg_spring = COAST_LEG_SPRING.lerp(THRUST_LEG_SPRING, t)
	p.shin_spring = COAST_SHIN_SPRING.lerp(THRUST_SHIN_SPRING, t)
	p.arm_spring = COAST_ARM_SPRING.lerp(THRUST_ARM_SPRING, t)
	p.wing_spring = COAST_WING_SPRING.lerp(THRUST_WING_SPRING, t)
	p.vel_lag = lerpf(COAST_VEL_LAG, THRUST_VEL_LAG, t)
	p.acc_lag = lerpf(COAST_ACC_LAG, THRUST_ACC_LAG, t)
	p.tilt_rate = lerpf(COAST_TILT_RATE, THRUST_TILT_RATE, t)
	p.hang = COAST_GRAVITY * (1.0 - t)
	p.bob = COAST_BOB * (1.0 - t)
	return p


## Move `fly` toward 1 while thrusting and toward 0 while coasting, at a rate
## that crosses the whole range in POSE_BLEND_TIME.
static func advance_fly(fly: float, thrusting: bool, delta: float) -> float:
	return move_toward(fly, 1.0 if thrusting else 0.0, delta / POSE_BLEND_TIME)
