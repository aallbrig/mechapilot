class_name BossPattern
extends RefCounted
## What each boss attack id (the Level data's `attacks[].id`) does when its
## telegraph ends. Every projectile pattern fires from each of the boss's
## turrets and falls under gravity; damage is the attack's own (BOSS_ATTACK).
##
##   VOLLEY   a fan of `count` shots over `spread`, aimed (or lobbed on an arc)
##   CARPET   a row of `count` bombs released along the hull, `spread` wide
##   RING     `count` shots all around
##   CURTAIN  `count` shots dropped in a row `spread` wide above the player
##   DASH     the boss charges at the player for `duration` at `speed`
##   LAUNCH   `count` drones launched from the bays (they are enemies)

enum Kind { VOLLEY, CARPET, RING, CURTAIN, DASH, LAUNCH }

## Boss projectiles before the attack's damage: muzzle speed, life, radius.
const BOLT_SPEED: float = 20.0 * Pace.GAME_SPEED
const SHOT_LIFE: float = 4.5
## Height above the player a curtain drops from (units).
const CURTAIN_HEIGHT: float = 14.0

static var _table: Dictionary[StringName, BossPattern] = {}

var kind: Kind = Kind.VOLLEY
var count: int = 1
var spread: float = 0.0
## VOLLEY: lob on a ballistic arc instead of aiming straight.
var lobbed: bool = false
## The projectile (before the attack's damage), or the dash speed and time.
var shot: ShotSpec = null
var speed: float = 0.0
var duration: float = 0.0


## The pattern of `attack_id`, or null when no pattern has that id.
static func of(attack_id: StringName) -> BossPattern:
	if _table.is_empty():
		_build()
	if not _table.has(attack_id):
		return null
	return _table[attack_id]


static func _build() -> void:
	var gs: float = Pace.GAME_SPEED
	var gravity: float = EnemyProfile.SHOT_GRAVITY
	var shell: ShotSpec = _spec(ShotSpec.Style.SHELL, BOLT_SPEED, gravity, 0.5)
	var bullet: ShotSpec = _spec(ShotSpec.Style.BULLET, BOLT_SPEED * 1.1, gravity, 0.35)
	var bolt: ShotSpec = _spec(ShotSpec.Style.BOLT, BOLT_SPEED * 1.6, gravity * 0.5, 0.6)
	var bomb: ShotSpec = _spec(ShotSpec.Style.BOMB, 1.0 * gs, EnemyProfile.BOMB_GRAVITY, 0.7)
	var drop: ShotSpec = _spec(ShotSpec.Style.BULLET, 2.0 * gs, gravity * 0.6, 0.4)

	_table[&"turret_arcing_shell"] = _volley(shell, 1, 0.0, true)
	_table[&"tail_gun"] = _volley(bullet, 2, 0.12, false)
	_table[&"spread_three"] = _volley(bullet, 3, 0.5, false)
	_table[&"spread_five"] = _volley(bullet, 5, 0.9, false)
	_table[&"flak"] = _volley(shell, 3, 0.35, true)
	_table[&"core_beam"] = _volley(bolt, 1, 0.0, false)
	_table[&"core_lance"] = _volley(bolt, 3, 0.15, false)
	_table[&"bomb_carpet"] = _make(Kind.CARPET, bomb, 6, 8.0)
	_table[&"shield_node_pulse"] = _make(Kind.RING, bullet, 10, TAU)
	_table[&"bullet_curtain"] = _make(Kind.CURTAIN, drop, 9, 18.0)
	_table[&"drone_launch"] = _make(Kind.LAUNCH, null, 3, 0.0)
	_table[&"dash"] = _dash(30.0 * gs, 0.6)
	_table[&"charge_lance"] = _dash(40.0 * gs, 0.7)


static func _spec(style: ShotSpec.Style, muzzle: float, fall: float, radius: float) -> ShotSpec:
	return ShotSpec.new(style, DamageSource.Source.BOSS_ATTACK, muzzle, fall, SHOT_LIFE, radius)


static func _make(pattern_kind: Kind, spec: ShotSpec, shots: int, width: float) -> BossPattern:
	var pattern: BossPattern = BossPattern.new()
	pattern.kind = pattern_kind
	pattern.shot = spec
	pattern.count = shots
	pattern.spread = width
	return pattern


static func _volley(spec: ShotSpec, shots: int, width: float, arc: bool) -> BossPattern:
	var pattern: BossPattern = _make(Kind.VOLLEY, spec, shots, width)
	pattern.lobbed = arc
	return pattern


static func _dash(dash_speed: float, dash_time: float) -> BossPattern:
	var pattern: BossPattern = _make(Kind.DASH, null, 1, 0.0)
	pattern.speed = dash_speed
	pattern.duration = dash_time
	return pattern
