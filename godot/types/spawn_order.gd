class_name SpawnOrder
extends RefCounted
## A spawn decision from core/spawn_director.gd, announced as
## `Events.enemy.spawn_requested`. game/ places the enemy and then reports
## `enemy_spawned` with the id it gave it.

## Which enemy to spawn.
var kind: EnemyKind.Kind = EnemyKind.Kind.FIGHTER
## Direction from the player in the play plane, in radians (0 = +X, PI/2 = +Y).
var angle: float = 0.0
## Distance from the player, in world units.
var distance: float = 0.0
## How aggressive the enemy flies and fires, 0 (calm) to 1 (relentless).
var aggression: float = 0.0
## Multiplier on the kind's base speed (the Level's difficulty).
var speed_scale: float = 1.0
## Multiplier on the kind's base fire rate (the Level's difficulty).
var fire_rate_scale: float = 1.0
## True for a boss escort (spawned during the Boss Fight).
var escort: bool = false


func _init(
	order_kind: EnemyKind.Kind,
	order_angle: float,
	order_distance: float,
	order_aggression: float,
	order_speed_scale: float,
	order_fire_rate_scale: float,
	order_escort: bool
) -> void:
	kind = order_kind
	angle = order_angle
	distance = order_distance
	aggression = order_aggression
	speed_scale = order_speed_scale
	fire_rate_scale = order_fire_rate_scale
	escort = order_escort


## True when both orders describe the same spawn (used by determinism tests).
func equals(other: SpawnOrder) -> bool:
	return (
		kind == other.kind
		and is_equal_approx(angle, other.angle)
		and is_equal_approx(distance, other.distance)
		and is_equal_approx(aggression, other.aggression)
		and is_equal_approx(speed_scale, other.speed_scale)
		and is_equal_approx(fire_rate_scale, other.fire_rate_scale)
		and escort == other.escort
	)
