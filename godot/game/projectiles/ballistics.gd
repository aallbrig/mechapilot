class_name Ballistics
extends RefCounted
## Pure rules for gravity shots on the XY play plane. A shot leaves the muzzle at
## its own speed along the aim plus a share of the carrier's velocity, then falls
## under constant gravity, so shots arc and drop over distance.


## Launch velocity for a shot aimed along `aim` from a carrier moving at `carrier`.
static func launch_velocity(
	aim: Vector3, carrier: Vector3, speed: float, inherit: float
) -> Vector3:
	var dir: Vector3 = Vector3(aim.x, aim.y, 0.0).normalized()
	var base: Vector3 = Vector3(carrier.x, carrier.y, 0.0)
	return dir * speed + base * inherit


## The velocity after `delta` seconds of falling under `gravity` (units/s^2).
static func fall(velocity: Vector3, gravity: float, delta: float) -> Vector3:
	return velocity + Vector3.DOWN * gravity * delta
