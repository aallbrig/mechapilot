class_name EnemySteering
extends RefCounted
## Pure flight rules per behaviour (EnemyProfile.Behaviour) on the XY play
## plane: the velocity an enemy wants this tick, and how it eases toward it.
## They turn with a lag (exponential ease at the profile's turn rate), which is
## what makes a Fighter overshoot and swoop back (the LAN prototype's feel).

## STANDOFF: how strongly an Interceptor circles while it holds its distance.
const ORBIT_SHARE: float = 0.6
## STANDOFF and STRAFE: within this many units of its spot it slows to a hover.
const ARRIVE_RADIUS: float = 4.0


## The velocity after easing `current` toward the behaviour's wish over `delta`.
## `speed` is this enemy's cruise speed; `age` its seconds alive (for sweeps);
## `side` is +1 or -1 (which side of the player it works from).
static func steer(
	profile: EnemyProfile,
	current: Vector3,
	at: Vector3,
	target: Vector3,
	speed: float,
	age: float,
	side: float,
	delta: float
) -> Vector3:
	var to_target: Vector3 = Vector3(target.x - at.x, target.y - at.y, 0.0)
	var want: Vector3 = Vector3.ZERO
	match profile.behaviour:
		EnemyProfile.Behaviour.CHASE:
			want = FiringSolution.aimed(at, target) * speed
		EnemyProfile.Behaviour.HOMING:
			var top: float = minf(current.length() + profile.acceleration * delta, speed)
			want = FiringSolution.aimed(at, target) * maxf(top, profile.speed_min)
		EnemyProfile.Behaviour.STANDOFF:
			var away: Vector3 = -FiringSolution.aimed(at, target)
			var spot: Vector3 = target + away * profile.standoff
			var orbit: Vector3 = away.rotated(Vector3.BACK, PI / 2.0 * side) * ORBIT_SHARE
			want = _arrive(at, spot, speed) + orbit * speed
			want = want.limit_length(speed)
		EnemyProfile.Behaviour.STRAFE:
			var spot: Vector3 = Vector3(
				target.x + side * profile.standoff,
				target.y + sin(age * profile.sweep_rate) * profile.sweep,
				0.0
			)
			want = _arrive(at, spot, speed)
		EnemyProfile.Behaviour.CROSS:
			var climb: float = (target.y + profile.altitude - at.y) * profile.turn
			want = Vector3(signf(current.x) * speed, clampf(climb, -speed, speed), 0.0)
			if current.x == 0.0:
				want.x = signf(to_target.x) * speed
	return current.lerp(want, 1.0 - exp(-profile.turn * delta))


## Toward `spot` at `speed`, slowing inside ARRIVE_RADIUS.
static func _arrive(at: Vector3, spot: Vector3, speed: float) -> Vector3:
	var gap: Vector3 = Vector3(spot.x - at.x, spot.y - at.y, 0.0)
	var distance: float = gap.length()
	if distance < FiringSolution.MIN_DISTANCE:
		return Vector3.ZERO
	return gap / distance * speed * minf(distance / ARRIVE_RADIUS, 1.0)
