class_name EnemyShotPool
extends Node3D
## Owns every enemy and boss projectile and recycles them, so firing never
## allocates nodes in play. step() flies the live shots and checks each against
## the player by distance: a shot that reaches a live player strikes it with
## its spec's damage source and is spent, whether or not the hit lands (the
## mech may be invulnerable).

## A shot reached the player, or fizzled at the end of its life (for juice).
signal shot_burst(position: Vector3, style: ShotSpec.Style, struck: bool)

var _shots: Array[EnemyShot] = []


## Launch a shot of `spec` from `origin` along `direction` at the spec's speed
## times `speed_scale` (the Level's bullet speed), plus `inherit` (the
## shooter's velocity share). Reuses a parked shot when there is one.
func fire(
	spec: ShotSpec, origin: Vector3, direction: Vector3, speed_scale: float, inherit: Vector3
) -> EnemyShot:
	var shot: EnemyShot = _parked_shot()
	if shot == null:
		shot = EnemyShot.new()
		add_child(shot)
		_shots.append(shot)
	var dir: Vector3 = Vector3(direction.x, direction.y, 0.0).normalized()
	shot.launch(spec, origin, dir * spec.speed * speed_scale + inherit)
	return shot


## Fly every live shot `delta` seconds and resolve hits on `target`.
func step(delta: float, target: CombatTarget) -> void:
	var alive: bool = target != null and target.is_alive()
	var aim: Vector3 = target.position() if target != null else Vector3.ZERO
	for shot: EnemyShot in _shots:
		if not shot.is_live():
			continue
		shot.step(delta, aim, alive)
		if not shot.is_live():
			shot_burst.emit(shot.position, shot.spec.style, false)
			continue
		if alive and _touches(shot, target):
			var _landed: bool = target.strike(
				shot.spec.source, shot.spec.attack_damage, shot.velocity.normalized()
			)
			shot.park()
			shot_burst.emit(shot.position, shot.spec.style, true)


## Park every shot outside `radius` of `centre` (the Play Sphere).
func cull_outside(centre: Vector3, radius: float) -> void:
	for shot: EnemyShot in _shots:
		if shot.is_live() and _plane_distance(shot.position, centre) > radius:
			shot.park()


func live_shots() -> Array[EnemyShot]:
	var live: Array[EnemyShot] = []
	for shot: EnemyShot in _shots:
		if shot.is_live():
			live.append(shot)
	return live


func pooled_count() -> int:
	return _shots.size()


## Park every shot (Level Clear, a new Run).
func clear() -> void:
	for shot: EnemyShot in _shots:
		shot.park()


func _touches(shot: EnemyShot, target: CombatTarget) -> bool:
	return _plane_distance(shot.position, target.position()) <= shot.spec.radius + target.radius()


func _parked_shot() -> EnemyShot:
	for shot: EnemyShot in _shots:
		if not shot.is_live():
			return shot
	return null


static func _plane_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.y - b.y).length()
