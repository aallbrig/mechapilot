class_name FiringSolution
extends RefCounted
## Pure aiming rules for enemy and boss guns on the XY play plane. Every enemy
## projectile falls under gravity (#73), so "aimed arcing" shots solve the
## ballistic arc instead of pointing straight at the target.

## Below this distance (units) a direction is meaningless; aim along +X.
const MIN_DISTANCE: float = 1e-3


## The unit direction from `from` to `to` on the play plane.
static func aimed(from: Vector3, to: Vector3) -> Vector3:
	var gap: Vector3 = Vector3(to.x - from.x, to.y - from.y, 0.0)
	if gap.length() < MIN_DISTANCE:
		return Vector3.RIGHT
	return gap.normalized()


## The launch direction that lands a shot of `speed` (units/s), falling under
## `gravity` (units/s^2), on `to`: the flatter of the two ballistic arcs. Out
## of range, the 45-degree lob toward the target, which falls short the least.
static func arc(from: Vector3, to: Vector3, speed: float, gravity: float) -> Vector3:
	var dx: float = to.x - from.x
	var dy: float = to.y - from.y
	if gravity <= 0.0 or absf(dx) < MIN_DISTANCE:
		return aimed(from, to)
	var v2: float = speed * speed
	var reach: float = v2 * v2 - gravity * (gravity * dx * dx + 2.0 * dy * v2)
	var side: float = signf(dx)
	if reach < 0.0:
		return Vector3(side, 1.0, 0.0).normalized()
	var angle: float = atan((v2 - sqrt(reach)) / (gravity * absf(dx)))
	return Vector3(side * cos(angle), sin(angle), 0.0)


## `count` directions fanned evenly over `spread` radians around `centre`.
static func fan(centre: Vector3, count: int, spread: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if count <= 1:
		out.append(centre)
		return out
	for i: int in count:
		var t: float = float(i) / float(count - 1) - 0.5
		out.append(centre.rotated(Vector3.BACK, t * spread))
	return out


## `count` directions spaced evenly around the full circle, starting at `start`.
static func ring(count: int, start: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i: int in count:
		var angle: float = start + TAU * float(i) / float(maxi(count, 1))
		out.append(Vector3(cos(angle), sin(angle), 0.0))
	return out
