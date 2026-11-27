class_name ShotSpec
extends RefCounted
## What one enemy or boss projectile is: how it looks, how it flies and what it
## does when it reaches the player. Specs are shared, never mutated in flight.

## The look: a bullet, an arcing shell, a falling bomb, a homing missile, or a
## heavy boss bolt.
enum Style { BULLET, SHELL, BOMB, MISSILE, BOLT }

var style: Style = Style.BULLET
## What the hit counts as (RunRules.damage_for maps it to Armor damage).
var source: DamageSource.Source = DamageSource.Source.ENEMY_BULLET
## A boss attack's own damage (only for BOSS_ATTACK).
var attack_damage: int = 0
## Muzzle speed (units/s) before the Level's bullet speed scale.
var speed: float = 0.0
## Downward pull (units/s^2). Every enemy projectile falls (#73).
var gravity: float = 0.0
## Seconds it flies before it fizzles.
var life: float = 0.0
## Contact radius (units).
var radius: float = 0.0
## How fast it turns toward the player (1/s); 0 flies ballistic.
var homing: float = 0.0


func _init(
	shot_style: Style,
	shot_source: DamageSource.Source,
	shot_speed: float,
	shot_gravity: float,
	shot_life: float,
	shot_radius: float
) -> void:
	style = shot_style
	source = shot_source
	speed = shot_speed
	gravity = shot_gravity
	life = shot_life
	radius = shot_radius


## A copy that counts as a boss attack dealing `damage`.
func as_boss_attack(damage: int) -> ShotSpec:
	var copy: ShotSpec = ShotSpec.new(
		style, DamageSource.Source.BOSS_ATTACK, speed, gravity, life, radius
	)
	copy.attack_damage = damage
	copy.homing = homing
	return copy


## A copy that turns toward the player at `rate` (1/s).
func homing_at(rate: float) -> ShotSpec:
	var copy: ShotSpec = ShotSpec.new(style, source, speed, gravity, life, radius)
	copy.attack_damage = attack_damage
	copy.homing = rate
	return copy
