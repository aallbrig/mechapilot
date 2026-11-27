class_name EnemyProfile
extends RefCounted
## The base tuning of each enemy kind (#73, "Enemy behaviours"), at
## Pace.GAME_SPEED: speeds scale by the pace and accelerations by its square.
## A spawn order then scales speed and fire rate by the Level's difficulty and
## the director's aggression.
##
##   Fighter      chases and swoops (it overshoots on its slow turn); no gun.
##   Heavy        4 HP, slow; a slow aimed shot.
##   Interceptor  holds its distance, circling, and lobs aimed arcing shells.
##   Drone        a 1 HP homing missile that explodes on contact.
##   Bomber       crosses the screen above the player, dropping bombs.
##   Enemy Mech   strafes beside the player and fires 3-way spreads.

## How a kind flies.
enum Behaviour { CHASE, STANDOFF, HOMING, CROSS, STRAFE }
## How a kind attacks (besides contact).
enum Attack { NONE, AIMED, ARC, BOMB, SPREAD }

## Shots and bombs fall like the player's shots (#22: 20 units/s^2 at full pace).
const SHOT_GRAVITY: float = 20.0 * Pace.GAME_SPEED * Pace.GAME_SPEED
const BOMB_GRAVITY: float = 26.0 * Pace.GAME_SPEED * Pace.GAME_SPEED
## Seconds an enemy projectile flies before it fizzles.
const SHOT_LIFE: float = 4.0
## Aggression 1 fires this much faster and flies this much faster than 0.
const AGGRESSION_FIRE_GAIN: float = 0.8
const AGGRESSION_SPEED_GAIN: float = 0.25
## Seconds an enemy takes to grow in after it spawns; it cannot attack meanwhile.
const SPAWN_GROW_TIME: float = 0.35
## Guns only fire at a player closer than this (units): on screen, roughly.
const ATTACK_RANGE: float = 26.0

static var _table: Dictionary[EnemyKind.Kind, EnemyProfile] = {}

var kind: EnemyKind.Kind = EnemyKind.Kind.FIGHTER
var behaviour: Behaviour = Behaviour.CHASE
var attack: Attack = Attack.NONE
## Hits (player shots) it takes to destroy.
var hit_points: int = 1
## Contact radius (units).
var radius: float = 1.0
## Cruise speed range (units/s) and turn rate (1/s) before scaling.
var speed_min: float = 0.0
var speed_max: float = 0.0
var turn: float = 0.0
## What touching the player counts as. The enemy is destroyed either way.
var contact: DamageSource.Source = DamageSource.Source.ENEMY_COLLISION
## Seconds between shots at aggression 0 and difficulty 1.
var fire_interval: float = 0.0
## The projectile, and how many leave per shot and over what fan (radians).
var shot: ShotSpec = null
var volley: int = 1
var volley_spread: float = 0.0
## STANDOFF and STRAFE: the distance kept from the player (units).
var standoff: float = 0.0
## STRAFE: the vertical sweep (units) and its rate (rad/s). CROSS: altitude
## above the player (units).
var sweep: float = 0.0
var sweep_rate: float = 0.0
var altitude: float = 0.0
## BOMB: how close (units) a bomb's landing must be to the player to release.
var bomb_window: float = 0.0
## HOMING: acceleration toward its top speed (units/s^2).
var acceleration: float = 0.0
## Scale of its placeholder look.
var look_scale: float = 1.0


## The profile of `which` kind.
static func of(which: EnemyKind.Kind) -> EnemyProfile:
	if _table.is_empty():
		_build()
	return _table[which]


static func _build() -> void:
	var gs: float = Pace.GAME_SPEED
	var bullet: ShotSpec = ShotSpec.new(
		ShotSpec.Style.BULLET,
		DamageSource.Source.ENEMY_BULLET,
		22.0 * gs,
		SHOT_GRAVITY,
		SHOT_LIFE,
		0.3
	)
	var shell: ShotSpec = ShotSpec.new(
		ShotSpec.Style.SHELL,
		DamageSource.Source.ENEMY_BULLET,
		24.0 * gs,
		SHOT_GRAVITY,
		SHOT_LIFE,
		0.4
	)
	var bomb: ShotSpec = ShotSpec.new(
		ShotSpec.Style.BOMB, DamageSource.Source.BOMB, 1.0 * gs, BOMB_GRAVITY, SHOT_LIFE, 0.6
	)

	var fighter: EnemyProfile = _profile(EnemyKind.Kind.FIGHTER, Behaviour.CHASE, 1, 1.1)
	fighter.speed_min = 6.0 * gs
	fighter.speed_max = 12.0 * gs
	fighter.turn = 3.0 * gs

	var heavy: EnemyProfile = _profile(EnemyKind.Kind.HEAVY, Behaviour.CHASE, 4, 1.6)
	heavy.speed_min = 5.0 * gs
	heavy.speed_max = 7.0 * gs
	heavy.turn = 1.5 * gs
	heavy.attack = Attack.AIMED
	heavy.fire_interval = 3.2
	heavy.shot = bullet
	heavy.look_scale = 1.6

	var interceptor: EnemyProfile = _profile(EnemyKind.Kind.INTERCEPTOR, Behaviour.STANDOFF, 2, 1.0)
	interceptor.speed_min = 10.0 * gs
	interceptor.speed_max = 13.0 * gs
	interceptor.turn = 3.0 * gs
	interceptor.standoff = 14.0
	interceptor.attack = Attack.ARC
	interceptor.fire_interval = 2.4
	interceptor.shot = shell
	interceptor.look_scale = 0.9

	var drone: EnemyProfile = _profile(EnemyKind.Kind.DRONE, Behaviour.HOMING, 1, 0.8)
	drone.speed_min = 4.0 * gs
	drone.speed_max = 14.0 * gs
	drone.turn = 4.5 * gs
	drone.acceleration = 8.0 * gs * gs
	drone.contact = DamageSource.Source.MISSILE
	drone.look_scale = 0.6

	var bomber: EnemyProfile = _profile(EnemyKind.Kind.BOMBER, Behaviour.CROSS, 3, 1.8)
	bomber.speed_min = 6.0 * gs
	bomber.speed_max = 7.0 * gs
	bomber.turn = 1.2 * gs
	bomber.altitude = 9.0
	bomber.attack = Attack.BOMB
	bomber.bomb_window = 3.0
	bomber.fire_interval = 1.0
	bomber.shot = bomb
	bomber.look_scale = 1.8

	var mech: EnemyProfile = _profile(EnemyKind.Kind.ENEMY_MECH, Behaviour.STRAFE, 6, 1.3)
	mech.speed_min = 8.0 * gs
	mech.speed_max = 10.0 * gs
	mech.turn = 2.5 * gs
	mech.standoff = 12.0
	mech.sweep = 5.0
	mech.sweep_rate = 1.4
	mech.attack = Attack.SPREAD
	mech.fire_interval = 2.0
	mech.shot = bullet
	mech.volley = 3
	mech.volley_spread = 0.5
	mech.look_scale = 1.3

	for profile: EnemyProfile in [fighter, heavy, interceptor, drone, bomber, mech]:
		_table[profile.kind] = profile


static func _profile(
	profile_kind: EnemyKind.Kind, flies: Behaviour, hits: int, contact_radius: float
) -> EnemyProfile:
	var profile: EnemyProfile = EnemyProfile.new()
	profile.kind = profile_kind
	profile.behaviour = flies
	profile.hit_points = hits
	profile.radius = contact_radius
	return profile
