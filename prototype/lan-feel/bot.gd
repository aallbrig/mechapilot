extends RefCounted
## PROTOTYPE attract-mode pilot: circle-strafes the nearest enemy and leads its
## shots. Reads the game (main.gd) passed in; returns screen-space stick vectors.


static func nearest_enemy(game: Node) -> Variant:
	var best: Variant = null
	var best_d := INF
	var at: Vector3 = game.player.position
	for e: Variant in game.enemies:
		var d: float = e.node.position.distance_to(at)
		if d < best_d:
			best_d = d
			best = e
	return best


## Circle-strafe the nearest enemy, or wander when the sky is empty.
static func move(game: Node, clock: float) -> Vector2:
	var e: Variant = nearest_enemy(game)
	var at: Vector3 = game.player.position
	var goal := Vector3(sin(clock * 0.35) * 14.0, cos(clock * 0.27) * 9.0, 0)
	if e != null:
		var epos: Vector3 = e.node.position
		var to_e := epos - at
		var side := Vector3(-to_e.y, to_e.x, 0).normalized() * 6.0
		goal = epos - to_e.normalized() * 10.0 + side * signf(sin(clock * 0.2))
	var d := goal - at
	return Vector2(d.x, -d.y).limit_length(1.0) if d.length() > 1.5 else Vector2.ZERO


## Lead the target and aim above it to cancel the shot's gravity drop.
static func fire(game: Node, clock: float, speed: float, gravity: float) -> Vector2:
	var e: Variant = nearest_enemy(game)
	if e == null or sin(clock * 1.3) < -0.4:
		return Vector2.ZERO
	var epos: Vector3 = e.node.position
	var evel: Vector3 = e.vel
	var to_e: Vector3 = epos - game.player.position
	if to_e.length() > 24.0:
		return Vector2.ZERO
	var t := to_e.length() / speed
	var aim := to_e + evel * t + Vector3(0, 0.5 * gravity * t * t, 0)
	return Vector2(aim.x, -aim.y).normalized()
