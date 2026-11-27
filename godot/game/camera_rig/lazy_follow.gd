class_name LazyFollow
extends RefCounted
## The lazy camera's follow rule, ported from the LAN prototype and made to
## recentre at speed. The goal point only moves when the mech (plus a short
## lookahead) leaves a central dead zone, and the focus chases the goal with a
## critically damped spring, so the camera lags behind sudden moves. Once the
## mech's velocity is steady (or slow), the goal eases back onto it, and the
## spring is fed the steady velocity so the mech settles on centre instead of
## trailing behind it.

## Critically damped follow rate (1/s). Lower is lazier.
const FOLLOW: float = 2.3
## Seconds of velocity the camera leads by.
const LOOKAHEAD: float = 0.25
## Seconds for the goal to settle back on the mech once its velocity is steady.
const RECENTER: float = 1.2
## Smoothed acceleration at which the mech no longer counts as steady (units/s^2).
const CALM_ACCEL: float = 20.0 * Pace.GAME_SPEED
## Speed below which the mech counts as steady whatever it does (units/s).
const CALM_SPEED: float = 3.0
## How fast the velocity estimate and the steadiness follow the mech (1/s).
const VELOCITY_SMOOTHING: float = 5.0
const STEADY_RATE: float = 4.0
## Rate factor: RECENTER seconds covers about 95% of the way (e^-3).
const RECENTER_SETTLE: float = 3.0

var _goal: Vector3 = Vector3.ZERO
var _focus: Vector3 = Vector3.ZERO
var _focus_velocity: Vector3 = Vector3.ZERO
var _smooth_velocity: Vector3 = Vector3.ZERO
var _steady: float = 0.0


## Jump straight to `point` with no motion (spawn, respawn).
func snap(point: Vector3) -> void:
	_goal = point
	_focus = point
	_focus_velocity = Vector3.ZERO
	_smooth_velocity = Vector3.ZERO
	_steady = 0.0


func focus() -> Vector3:
	return _focus


## Advance by `delta` toward a mech at `target` moving at `velocity`, with a dead
## zone of `dead_zone` half extents (world units). Returns the new focus point.
func step(target: Vector3, velocity: Vector3, dead_zone: Vector2, delta: float) -> Vector3:
	if delta <= 0.0:
		return _focus
	# How steady the mech is: 1 at a constant (or slow) velocity, 0 while it
	# accelerates hard.
	var smoothed: Vector3 = _smooth_velocity.lerp(velocity, 1.0 - exp(-VELOCITY_SMOOTHING * delta))
	var accel: float = (smoothed - _smooth_velocity).length() / delta
	_smooth_velocity = smoothed
	var calm: float = 1.0 - clampf(accel / CALM_ACCEL, 0.0, 1.0)
	calm = maxf(calm, 1.0 - clampf(velocity.length() / CALM_SPEED, 0.0, 1.0))
	_steady = lerpf(_steady, calm, 1.0 - exp(-STEADY_RATE * delta))
	# The steady share of the velocity moves the goal and feeds the spring, so
	# neither trails a mech cruising at constant speed. It never exceeds the
	# mech's own velocity, so the feed dies the moment the mech brakes.
	var feed: Vector3 = _within(_smooth_velocity * _steady, velocity)
	_goal += feed * delta

	var desired: Vector3 = target + velocity * LOOKAHEAD
	_goal.x += _excess(desired.x - _goal.x, dead_zone.x)
	_goal.y += _excess(desired.y - _goal.y, dead_zone.y)
	var settle: float = (1.0 - exp(-RECENTER_SETTLE / RECENTER * delta)) * _steady
	_goal = _goal.lerp(desired, settle)

	var w: float = FOLLOW
	_focus_velocity += ((w * w * (_goal - _focus) + 2.0 * w * (feed - _focus_velocity)) * delta)
	# The focus may not outrun the mech when it is past its goal, or ahead of a
	# braking mech: a braking mech is never overtaken, and the camera eases back
	# instead of swinging past it.
	_focus_velocity.x = _held_back(
		_focus_velocity.x, _focus.x, _goal.x, target.x, velocity.x, _smooth_velocity.x
	)
	_focus_velocity.y = _held_back(
		_focus_velocity.y, _focus.y, _goal.y, target.y, velocity.y, _smooth_velocity.y
	)
	_focus += _focus_velocity * delta
	_focus.z = 0.0
	return _focus


## One axis of the focus velocity `fv`, limited to the mech's velocity `v` while
## the focus is past its goal, or ahead of a mech that is braking (its velocity
## has dropped below its smoothed velocity `smooth`).
func _held_back(
	fv: float, focus_at: float, goal_at: float, target_at: float, v: float, smooth: float
) -> float:
	var past_goal: bool = (goal_at - focus_at) * fv < 0.0
	var braking: bool = absf(v) < absf(smooth) or v * smooth < 0.0
	var ahead: bool = (focus_at - target_at) * fv > 0.0
	if past_goal or (braking and ahead):
		return _within_axis(fv, v)
	return fv


## `v` limited, per axis, to the direction and size of `limit`.
func _within(v: Vector3, limit: Vector3) -> Vector3:
	return Vector3(_within_axis(v.x, limit.x), _within_axis(v.y, limit.y), 0.0)


func _within_axis(value: float, limit: float) -> float:
	if value * limit <= 0.0:
		return 0.0
	return signf(value) * minf(absf(value), absf(limit))


func _excess(d: float, half: float) -> float:
	if absf(d) <= half:
		return 0.0
	return d - signf(d) * half
