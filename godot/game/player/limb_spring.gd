class_name LimbSpring
extends RefCounted
## A hand-rolled spring-damper on one joint angle (radians). The mech flies, so
## its limbs are secondary motion: each joint chases a target angle and lags
## behind the body's acceleration, and recoil and hits kick it.

## The joint's range either side of straight down (radians).
const MAX_ANGLE: float = 1.8

var angle: float = 0.0
var velocity: float = 0.0
## Phase offset for the idle bob, so limbs don't swing in lockstep.
var phase: float = 0.0
## Per-limb response multiplier (left and right differ slightly).
var gain: float = 1.0


## Advance by `delta` toward `target` with an extra `force`, using
## `spring` = Vector2(stiffness, damping). Semi-implicit Euler, clamped.
func step(target: float, force: float, spring: Vector2, delta: float) -> void:
	velocity += (spring.x * (target - angle) - spring.y * velocity + force) * delta
	angle = clampf(angle + velocity * delta, -MAX_ANGLE, MAX_ANGLE)


## An instant change of angular velocity (recoil, hit, nearby explosion).
func kick(amount: float) -> void:
	velocity += amount


func reset() -> void:
	angle = 0.0
	velocity = 0.0
