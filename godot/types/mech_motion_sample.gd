class_name MechMotionSample
extends RefCounted
## One frame of the player mech's motion, reported by game/ so feedback/ (flames,
## vapor, eye trails) can react without reaching into the scene tree.

## World position of the mech's centre.
var position: Vector3 = Vector3.ZERO
## World velocity (units/s).
var velocity: Vector3 = Vector3.ZERO
## Smoothed acceleration across the direction of travel (units/s^2).
var lateral_g: float = 0.0
## Move-input magnitude, 0 (coasting) to 1 (full thrust).
var thrust: float = 0.0
## World positions of the binder wing tips, for vapor ribbons.
var wing_tips: PackedVector3Array = PackedVector3Array()
## The mech's visual scale; effects scale their sizes with it.
var scale: float = 1.0
## Seconds this sample covers.
var delta: float = 0.0
