class_name BossProfile
extends RefCounted
## How each of the six bosses (#73, #74) flies and where its guns sit, by boss
## id. Health, phases, attacks and escorts are the Level data's
## (BossDefinition); this is the per-boss motion and body tuning, at
## Pace.GAME_SPEED.
##
##   Albatross       a slow gunship holding station ahead and above, two turrets.
##   Thunderhead     a heavy bomber cruising high above, a tail gun behind.
##   Hornet          a fast twin-rotor gunship weaving close.
##   Leviathan       a huge carrier far above; only its launch bays take hits
##                   until they are destroyed, which exposes its core.
##   Crimson Lancer  a rival ace mech duelling at mech range, weaving hard.
##   Ascendant       a mothership looming overhead.

## Seconds the entry takes, and where it starts relative to its station
## (off screen), so it flies in before the fight starts.
const ENTRY_TIME: float = 2.5
const ENTRY_OFFSET: Vector3 = Vector3(30.0, 18.0, 0.0)
## Seconds the defeat sequence lasts, and the gap between its explosions.
const DEFEAT_TIME: float = 2.4
const DEFEAT_BURST_GAP: float = 0.3
## The defeated hulk falls under this gravity (units/s^2).
const DEFEAT_FALL: float = 6.0 * Pace.GAME_SPEED * Pace.GAME_SPEED

static var _table: Dictionary[StringName, BossProfile] = {}

var id: StringName = &""
## Where it holds station relative to the player (units).
var station: Vector3 = Vector3.ZERO
## How fast it closes on its station (1/s).
var follow: float = 0.0
## A weave around the station: amplitude (units) and rate (rad/s) per axis.
var weave: Vector2 = Vector2.ZERO
var weave_rate: float = 0.0
## The hull the rules are tuned on (units): its model is scaled so its
## silhouette spans this width (BossLook). Its guns and launch bays are the
## model's markers (BossLook.turret_points(), bay_points()).
var size: Vector3 = Vector3.ONE
## Bosses whose core is shielded at first (the Leviathan): until this phase
## (0-based) only its launch bays (the model's LaunchBay markers) take hits, each within
## `bay_radius`; the body deflects shots. Once its health crosses into this
## phase the bays are destroyed and the core is exposed. 0 = no shielding.
var shielded_until_phase: int = 0
var bay_radius: float = 0.0


## The profile of `boss_id`, or null when no boss has that id.
static func of(boss_id: StringName) -> BossProfile:
	if _table.is_empty():
		_build()
	if not _table.has(boss_id):
		return null
	return _table[boss_id]


## Every boss id with a profile.
static func ids() -> Array[StringName]:
	if _table.is_empty():
		_build()
	var out: Array[StringName] = []
	for boss_id: StringName in _table:
		out.append(boss_id)
	return out


static func _build() -> void:
	var albatross: BossProfile = _profile(&"albatross", Vector3(14.0, 7.0, 0.0), 0.8)
	albatross.weave = Vector2(1.0, 1.5)
	albatross.weave_rate = 0.6
	albatross.size = Vector3(7.0, 2.0, 2.0)

	var thunderhead: BossProfile = _profile(&"thunderhead", Vector3(6.0, 11.0, 0.0), 0.7)
	thunderhead.weave = Vector2(4.0, 1.0)
	thunderhead.weave_rate = 0.4
	thunderhead.size = Vector3(9.0, 2.2, 3.0)

	var hornet: BossProfile = _profile(&"hornet", Vector3(11.0, 4.0, 0.0), 1.6)
	hornet.weave = Vector2(3.0, 3.0)
	hornet.weave_rate = 1.3
	hornet.size = Vector3(5.0, 1.6, 1.6)

	var leviathan: BossProfile = _profile(&"leviathan", Vector3(4.0, 13.0, 0.0), 0.5)
	leviathan.weave = Vector2(5.0, 0.8)
	leviathan.weave_rate = 0.3
	leviathan.size = Vector3(13.0, 3.2, 4.0)
	leviathan.shielded_until_phase = 1
	leviathan.bay_radius = 1.6

	var lancer: BossProfile = _profile(&"crimson_lancer", Vector3(10.0, 2.0, 0.0), 1.8)
	lancer.weave = Vector2(2.0, 4.0)
	lancer.weave_rate = 1.5
	lancer.size = Vector3(2.4, 3.2, 1.6)

	var ascendant: BossProfile = _profile(&"ascendant", Vector3(0.0, 12.0, 0.0), 0.6)
	ascendant.weave = Vector2(6.0, 1.0)
	ascendant.weave_rate = 0.35
	ascendant.size = Vector3(15.0, 3.5, 6.0)

	for profile: BossProfile in [albatross, thunderhead, hornet, leviathan, lancer, ascendant]:
		_table[profile.id] = profile


static func _profile(boss_id: StringName, at: Vector3, follow_rate: float) -> BossProfile:
	var profile: BossProfile = BossProfile.new()
	profile.id = boss_id
	profile.station = at
	profile.follow = follow_rate
	return profile
