class_name ShotReferee
extends RefCounted
## Runs every live player shot past the boss and the enemies once per tick.
## The boss is asked first: its hull sits in front of its escorts and drones,
## and a shot that glances off it (shielded, or still flying in) is spent
## there too. The first enemy a shot touches takes it. A shot that struck
## something is spent, so it is never counted twice.


## Resolve every live shot in `shots` against `arena`, then `field`. Returns
## how many shots struck something this tick.
static func resolve(shots: ShotPool, arena: BossArena, field: EnemyField) -> int:
	var struck: int = 0
	for shot: PlayerShot in shots.live_shots():
		var at: Vector3 = shot.global_position if shot.is_inside_tree() else shot.position
		var along: Vector3 = shot.velocity.normalized()
		if (
			arena.resolve_shot(at, PlayerShot.RADIUS)
			or field.resolve_shot(at, PlayerShot.RADIUS, along)
		):
			shot.spend()
			struck += 1
	return struck
