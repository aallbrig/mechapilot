class_name LevelTally
extends RefCounted
## The Level Clear tally, announced with `Events.run.level_cleared`. The bonus
## points are already added to the score when it is announced.

## The Level that was cleared (1 to 6).
var level_number: int = 1
## Enemies destroyed by the player's shots in this Level.
var kills: int = 0
## Shots the player fired in this Level.
var shots_fired: int = 0
## Shots that hit an enemy or the boss in this Level.
var shots_hit: int = 0
## The remaining Armor times the Armor bonus rate.
var armor_bonus: int = 0
## The no-death bonus, or 0 if a life was lost in this Level.
var no_death_bonus: int = 0


func _init(
	cleared_level: int,
	level_kills: int,
	fired: int,
	hit: int,
	armor_points: int,
	no_death_points: int
) -> void:
	level_number = cleared_level
	kills = level_kills
	shots_fired = fired
	shots_hit = hit
	armor_bonus = armor_points
	no_death_bonus = no_death_points


## Hits per shot, 0.0 to 1.0 (0.0 when no shot was fired).
func accuracy() -> float:
	if shots_fired <= 0:
		return 0.0
	return clampf(float(shots_hit) / shots_fired, 0.0, 1.0)


## The bonus points this tally added to the score.
func bonus_total() -> int:
	return armor_bonus + no_death_bonus
