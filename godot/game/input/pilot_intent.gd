class_name PilotIntent
extends RefCounted
## What the pilot wants this frame, independent of the device. Directions are in
## world terms on the play plane: x right, y up.

## Stick or keys, length at most 1. Zero means coast.
var move: Vector2 = Vector2.ZERO
## An aim direction from a stick or the arrow keys, or zero for "keep the last aim".
var aim: Vector2 = Vector2.ZERO
## Fire is held (along `aim`, or the last aim when `aim` is zero).
var firing: bool = false
## Keyboard + mouse: the cursor in screen pixels, which the mech aims at.
var aim_point: Vector2 = Vector2.ZERO
var has_aim_point: bool = false
## Touch: a quick tap fires one shot at this screen point.
var tap_point: Vector2 = Vector2.ZERO
var has_tap: bool = false
