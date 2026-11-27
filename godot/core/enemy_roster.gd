class_name EnemyRoster
extends RefCounted
## What the Intel codex says about each enemy kind (#73 "Enemy behaviours"):
## its name, its one-line description and its hit points. #73 fixes the Heavy
## (4) and the Drone (1); the rest are tuned here, and the enemy nodes (#23)
## take their hit points from hit_points() so the codex never disagrees.

const NAMES: Dictionary[EnemyKind.Kind, String] = {
	EnemyKind.Kind.FIGHTER: "Fighter",
	EnemyKind.Kind.HEAVY: "Heavy",
	EnemyKind.Kind.INTERCEPTOR: "Interceptor",
	EnemyKind.Kind.DRONE: "Drone",
	EnemyKind.Kind.BOMBER: "Bomber",
	EnemyKind.Kind.ENEMY_MECH: "Enemy Mech",
}
const DESCRIPTIONS: Dictionary[EnemyKind.Kind, String] = {
	EnemyKind.Kind.FIGHTER: "Chases you down and swoops past. Fragile, but never alone.",
	EnemyKind.Kind.HEAVY: "Slow and armoured: it takes four hits to bring one down.",
	EnemyKind.Kind.INTERCEPTOR: "Keeps its distance and lobs aimed, arcing shots.",
	EnemyKind.Kind.DRONE: "A homing missile with wings. One hit kills it; contact explodes.",
	EnemyKind.Kind.BOMBER: "Crosses the sky dropping bombs. Stay out from under it.",
	EnemyKind.Kind.ENEMY_MECH: "A rival mech that strafes and fires three-way spreads.",
}
const HIT_POINTS: Dictionary[EnemyKind.Kind, int] = {
	EnemyKind.Kind.FIGHTER: 1,
	EnemyKind.Kind.HEAVY: 4,
	EnemyKind.Kind.INTERCEPTOR: 2,
	EnemyKind.Kind.DRONE: 1,
	EnemyKind.Kind.BOMBER: 6,
	EnemyKind.Kind.ENEMY_MECH: 8,
}


## The hit points of `kind`.
static func hit_points(kind: EnemyKind.Kind) -> int:
	return HIT_POINTS[kind]


## The Intel entry of `kind`.
static func intel_entry(kind: EnemyKind.Kind) -> IntelEntry:
	return IntelEntry.new(
		EnemyKind.id_of(kind),
		NAMES[kind],
		DESCRIPTIONS[kind],
		HIT_POINTS[kind],
		RunRules.kill_points(kind),
		false
	)
