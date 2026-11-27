class_name ScreenProjector
extends RefCounted
## Maps play-plane points to screen points, so the off-screen indicators never
## reach into the camera rig. The base class is an orthographic projector
## (`pixels_per_unit` around `centre`, +Y up on the plane is up on screen);
## CameraProjector projects through the game's Camera3D.

var centre: Vector3 = Vector3.ZERO
var pixels_per_unit: float = 1.0


## The screen point (pixels, origin top-left) of play-plane point `at`.
func to_screen(at: Vector3, size: Vector2) -> Vector2:
	var offset: Vector3 = at - centre
	return size * 0.5 + Vector2(offset.x, -offset.y) * pixels_per_unit


## True when `at` is behind the camera (its projection is mirrored).
func is_behind(_at: Vector3) -> bool:
	return false
