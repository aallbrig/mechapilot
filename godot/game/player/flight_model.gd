class_name FlightModel
extends RefCounted
## Pure flight rules for the player mech on the XY play plane (z = 0), seen side-on.
## Thrust pulls the velocity toward the stick and overrides gravity entirely.
## With no input the mech coasts: horizontal momentum decays with light drag and
## it falls under gentle gravity toward a terminal speed. It never climbs on its own.
## `move` is the stick in world terms: x right, y up, length at most 1.


static func is_thrusting(move: Vector2, tuning: MechTuning) -> bool:
	return move.length() > tuning.thrust_deadzone


## The velocity after `delta` seconds of flight under `move`.
static func step_velocity(
	velocity: Vector3, move: Vector2, delta: float, tuning: MechTuning
) -> Vector3:
	var v: Vector3 = Vector3(velocity.x, velocity.y, 0.0)
	if is_thrusting(move, tuning):
		var stick: Vector2 = move.limit_length(1.0)
		var target: Vector3 = Vector3(stick.x, stick.y, 0.0) * tuning.speed
		return v.lerp(target, 1.0 - exp(-tuning.thrust_response * delta))
	v.x *= exp(-tuning.coast_drag * delta)
	if v.y < -tuning.coast_terminal_fall:
		# Knocked down faster than terminal: air resistance eases it back, no snap.
		v.y = move_toward(v.y, -tuning.coast_terminal_fall, tuning.coast_gravity * delta)
	else:
		v.y = maxf(v.y - tuning.coast_gravity * delta, -tuning.coast_terminal_fall)
	return v
