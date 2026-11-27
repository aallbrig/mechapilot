class_name PlaySphere
extends RefCounted
## The Play Sphere: the circle on the play plane, centred on the player, that
## holds the fight. Anything outside it has flown off for good, and the enemy
## field despawns it. Its radius is the Level's (`play_sphere.radius`).

var radius: float = 0.0
var centre: Vector3 = Vector3.ZERO


func _init(sphere_radius: float) -> void:
	radius = sphere_radius


## Follow the player to `at`.
func follow(at: Vector3) -> void:
	centre = Vector3(at.x, at.y, 0.0)


## True when `point` is outside the sphere (on the play plane).
func is_outside(point: Vector3) -> bool:
	return Vector2(point.x - centre.x, point.y - centre.y).length() > radius
