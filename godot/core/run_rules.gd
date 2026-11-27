class_name RunRules
extends RefCounted
## The fixed tuning constants of a Run (#73, "Run structure", "Health and lives"
## and "Scoring"). Per-Level tuning lives in levels/level_N.json instead.

## Armor the mech starts with, respawns with and can be repaired up to.
const MAX_ARMOR: int = 100
## Armor damage per hit by source (BOSS_ATTACK takes the attack's own damage).
const COLLISION_DAMAGE: int = 25
const BULLET_DAMAGE: int = 10
const BOMB_DAMAGE: int = 20
const MISSILE_DAMAGE: int = 20
## The legal range of a boss attack's damage (the Level Schema enforces it too).
const BOSS_ATTACK_DAMAGE_MIN: int = 15
const BOSS_ATTACK_DAMAGE_MAX: int = 35
## Every enemy and boss attack glows or charges at least this many seconds first.
const MIN_TELEGRAPH: float = 0.4
## Seconds of invulnerability after a hit, and after a respawn.
const HIT_INVULNERABILITY: float = 0.6
const RESPAWN_INVULNERABILITY: float = 2.0
## Seconds between losing a life and respawning (the death ragdoll and slow-mo).
const RESPAWN_DELAY: float = 1.6

## Lives at the start of a Run, and the one-time bonus life.
const START_LIVES: int = 3
const BONUS_LIFE_SCORE: int = 100000

## Kills within this many seconds of each other raise the combo multiplier.
const COMBO_WINDOW: float = 1.2
const COMBO_MAX_MULTIPLIER: int = 8

## Base points per shot kill (#73's scoring table), before the combo multiplier.
const KILL_POINTS: Dictionary[EnemyKind.Kind, int] = {
	EnemyKind.Kind.FIGHTER: 100,
	EnemyKind.Kind.HEAVY: 300,
	EnemyKind.Kind.INTERCEPTOR: 200,
	EnemyKind.Kind.DRONE: 150,
	EnemyKind.Kind.BOMBER: 400,
	EnemyKind.Kind.ENEMY_MECH: 500,
}
## The boss scores this times the Level number.
const BOSS_POINTS_PER_LEVEL: int = 5000
## Level Clear bonus: points per remaining Armor point, plus a no-death bonus.
const ARMOR_BONUS_PER_POINT: int = 50
const NO_DEATH_BONUS: int = 10000

## Repair Kits: Armor restored, drop chance per shot kill (a boss always drops one).
const REPAIR_ARMOR: int = 30
const REPAIR_DROP_CHANCE: float = 0.06

## Seconds the Boss Warning lasts before the boss enters.
const BOSS_WARNING_DURATION: float = 3.0
## The number of Levels in a Run; defeating the last Level's boss is Victory.
const LEVEL_COUNT: int = 6


## Base points for a shot kill of `kind`, before the combo multiplier.
static func kill_points(kind: EnemyKind.Kind) -> int:
	return KILL_POINTS[kind]


## Armor damage of a hit. `attack_damage` is used only for BOSS_ATTACK and is
## clamped to the legal boss attack range.
static func damage_for(source: DamageSource.Source, attack_damage: int) -> int:
	match source:
		DamageSource.Source.ENEMY_COLLISION:
			return COLLISION_DAMAGE
		DamageSource.Source.ENEMY_BULLET:
			return BULLET_DAMAGE
		DamageSource.Source.BOMB:
			return BOMB_DAMAGE
		DamageSource.Source.MISSILE:
			return MISSILE_DAMAGE
		DamageSource.Source.BOSS_ATTACK:
			return clampi(attack_damage, BOSS_ATTACK_DAMAGE_MIN, BOSS_ATTACK_DAMAGE_MAX)
	return 0


## Points for defeating the boss of `level_number`.
static func boss_points(level_number: int) -> int:
	return BOSS_POINTS_PER_LEVEL * level_number
