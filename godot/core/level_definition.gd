class_name LevelDefinition
extends RefCounted
## One Level of the Run, parsed from levels/level_N.json (#73). The Schema
## (schemas/level.schema.json) checks the files in CI; parse() checks the same
## rules at runtime, plus the cross-field ones (ranges that must be ordered,
## descending boss phases) and returns errors instead of a half-built Level.
## game/level_library.gd reads the files; core/ only ever sees Dictionaries.

## Sanity bounds for values the Schema leaves open.
const MAX_POINTS: int = 10_000_000
const MAX_SECONDS: float = 600.0
const MAX_LIVE: int = 30
const MAX_DISTANCE: float = 10_000.0
const MAX_SCALE: float = 4.0
const MIN_SCALE: float = 0.25
const MAX_ANGLE: float = PI


## A weighted enemy kind that joins the pick after `min_kills` kills in the Level.
class RosterEntry:
	extends RefCounted

	var kind: EnemyKind.Kind = EnemyKind.Kind.FIGHTER
	var weight: float = 1.0
	var min_kills: int = 0


## The player mech's tuning (the parity spec's §18 values).
class PlayerTuning:
	extends RefCounted

	var speed: float = 0.0
	var coast_factor: float = 0.0
	var initial_move: Vector2 = Vector2.ZERO
	var fire_interval: float = 0.0
	var muzzle_offset: float = 0.0
	var projectile_speed: float = 0.0
	var projectile_lifetime: float = 0.0
	var projectile_damage: int = 0


## The camera rig's tuning (the parity spec's §18 values).
class CameraTuning:
	extends RefCounted

	var fov: float = 0.0
	var offset_landscape: Vector3 = Vector3.ZERO
	var offset_portrait: Vector3 = Vector3.ZERO
	var damping: float = 0.0
	var far: float = 0.0


## The Skirmish spawn ramp (see the Schema's `spawner` description).
class SpawnTuning:
	extends RefCounted

	var spawn_distance: float = 0.0
	var spawn_distance_jitter: float = 0.0
	var pool: int = 0
	var limit_start: float = 0.0
	var limit_per_kill: float = 0.0
	var limit_max: int = 0
	var delay_min: float = 0.0
	var delay_max: float = 0.0
	var buffer_start: float = 0.0
	var buffer_per_kill: float = 0.0
	var buffer_min: float = 0.0
	var aggression_start: float = 0.0
	var aggression_per_kill: float = 0.0
	var aggression_max: float = 0.0
	var wave_interval: float = 0.0
	var wave_size_start: int = 0
	var wave_size_growth: int = 0
	var wave_spread: float = 0.0


var id: StringName = &""
## 1 to 6: the Level's place in the Run.
var number: int = 0
var display_name: String = ""
var objective: String = ""
var sky_top: Color = Color.BLACK
var sky_bottom: Color = Color.BLACK
var sky_effects: Array[StringName] = []
var player: PlayerTuning = PlayerTuning.new()
var camera: CameraTuning = CameraTuning.new()
var play_sphere_radius: float = 0.0
## Seconds the Level Intro card shows.
var intro_duration: float = 0.0
var roster: Array[RosterEntry] = []
var spawn: SpawnTuning = SpawnTuning.new()
## Multipliers on every enemy kind's base speed, fire rate and bullet speed.
var enemy_speed_scale: float = 1.0
var enemy_fire_rate_scale: float = 1.0
var enemy_bullet_speed_scale: float = 1.0
var boss: BossDefinition = BossDefinition.new()
## Seconds between losing the last life and Game Over.
var game_over_delay: float = 0.0


## Parses one Level file's data. Returns null, with every problem in `errors`
## (if given), when the data is not a valid Level.
static func parse(data: Dictionary, errors: Array[String] = []) -> LevelDefinition:
	var reader: DataReader = DataReader.new()
	var level: LevelDefinition = LevelDefinition.new()
	level.id = StringName(reader.text(data, "id", ""))
	level.number = reader.integer(data, "number", "", 1, RunRules.LEVEL_COUNT)
	if String(level.id) != "level_%d" % level.number:
		reader.fail("id", "must be level_<number>")
	level.display_name = reader.text(data, "name", "")
	level.objective = reader.text(data, "objective", "")
	_parse_sky(level, reader.object(data, "sky", ""), reader)
	_parse_player(level.player, reader.object(data, "player", ""), reader)
	_parse_camera(level.camera, reader.object(data, "camera", ""), reader)
	var sphere: Dictionary = reader.object(data, "play_sphere", "")
	level.play_sphere_radius = reader.number(sphere, "radius", "play_sphere", 0.0, MAX_DISTANCE)
	var intro: Dictionary = reader.object(data, "intro", "")
	level.intro_duration = reader.number(intro, "duration", "intro", 0.0, MAX_SECONDS)
	level.roster = parse_roster(data, reader, "")
	_parse_spawn(level.spawn, reader.object(data, "spawner", ""), reader)
	var difficulty: Dictionary = reader.object(data, "difficulty", "")
	level.enemy_speed_scale = reader.number(
		difficulty, "enemy_speed_scale", "difficulty", MIN_SCALE, MAX_SCALE
	)
	level.enemy_fire_rate_scale = reader.number(
		difficulty, "enemy_fire_rate_scale", "difficulty", MIN_SCALE, MAX_SCALE
	)
	level.enemy_bullet_speed_scale = reader.number(
		difficulty, "enemy_bullet_speed_scale", "difficulty", MIN_SCALE, MAX_SCALE
	)
	level.boss = BossDefinition.parse(reader.object(data, "boss", ""), reader, "boss")
	var game_over: Dictionary = reader.object(data, "game_over", "")
	level.game_over_delay = reader.number(
		game_over, "delay_after_player_death", "game_over", 0.0, MAX_SECONDS
	)
	errors.append_array(reader.errors())
	return level if reader.is_ok() else null


## Parses the `roster` array of `data`: at least one entry, unique kinds, and
## at least one kind available from the first kill.
static func parse_roster(data: Dictionary, reader: DataReader, path: String) -> Array[RosterEntry]:
	var roster_path: String = "roster" if path.is_empty() else path + ".roster"
	var entries: Array[RosterEntry] = []
	var raw: Array = reader.list(data, "roster", path)
	var seen: Array[StringName] = []
	var opens: bool = false
	for i: int in raw.size():
		var entry_path: String = "%s[%d]" % [roster_path, i]
		var item: Dictionary = reader.element(raw, i, roster_path)
		var kind_id: StringName = StringName(reader.text(item, "kind", entry_path))
		if not EnemyKind.is_id(kind_id) or seen.has(kind_id):
			reader.fail(entry_path + ".kind", "unknown or repeated kind '%s'" % kind_id)
			continue
		seen.append(kind_id)
		var entry: RosterEntry = RosterEntry.new()
		entry.kind = EnemyKind.from_id(kind_id)
		entry.weight = reader.number(item, "weight", entry_path, 0.0, MAX_POINTS)
		entry.min_kills = reader.integer(item, "min_kills", entry_path, 0, MAX_POINTS)
		if entry.weight <= 0.0:
			reader.fail(entry_path + ".weight", "must be positive")
		opens = opens or entry.min_kills == 0
		entries.append(entry)
	if not opens:
		reader.fail(roster_path, "needs a kind with min_kills 0")
	return entries


static func _parse_sky(level: LevelDefinition, sky: Dictionary, reader: DataReader) -> void:
	level.sky_top = _color(reader.text(sky, "top", "sky"), reader, "sky.top")
	level.sky_bottom = _color(reader.text(sky, "bottom", "sky"), reader, "sky.bottom")
	for effect: Variant in reader.list(sky, "effects", "sky"):
		if effect is String:
			var effect_id: String = effect
			level.sky_effects.append(StringName(effect_id))
		else:
			reader.fail("sky.effects", "every effect must be a string")


static func _parse_player(tuning: PlayerTuning, data: Dictionary, reader: DataReader) -> void:
	tuning.speed = reader.number(data, "speed", "player", 0.0, MAX_DISTANCE)
	tuning.coast_factor = reader.number(data, "coast_factor", "player", 0.0, 1.0)
	tuning.initial_move = _vec2(reader.list(data, "initial_move", "player"), reader, "player")
	tuning.fire_interval = reader.number(data, "fire_interval", "player", 0.0, MAX_SECONDS)
	tuning.muzzle_offset = reader.number(data, "muzzle_offset", "player", 0.0, MAX_DISTANCE)
	tuning.projectile_speed = reader.number(data, "projectile_speed", "player", 0.0, MAX_DISTANCE)
	tuning.projectile_lifetime = reader.number(
		data, "projectile_lifetime", "player", 0.0, MAX_SECONDS
	)
	tuning.projectile_damage = reader.integer(data, "projectile_damage", "player", 1, MAX_POINTS)


static func _parse_camera(tuning: CameraTuning, data: Dictionary, reader: DataReader) -> void:
	tuning.fov = reader.number(data, "fov", "camera", 0.0, 180.0)
	tuning.offset_landscape = _vec3(reader.list(data, "offset_landscape", "camera"), reader)
	tuning.offset_portrait = _vec3(reader.list(data, "offset_portrait", "camera"), reader)
	tuning.damping = reader.number(data, "damping", "camera", 0.0, MAX_DISTANCE)
	tuning.far = reader.number(data, "far", "camera", 0.0, MAX_DISTANCE)


static func _parse_spawn(tuning: SpawnTuning, data: Dictionary, reader: DataReader) -> void:
	var p: String = "spawner"
	tuning.spawn_distance = reader.number(data, "spawn_distance", p, 0.0, MAX_DISTANCE)
	tuning.spawn_distance_jitter = reader.number(
		data, "spawn_distance_jitter", p, 0.0, MAX_DISTANCE
	)
	tuning.pool = reader.integer(data, "pool", p, 1, MAX_POINTS)
	tuning.limit_start = reader.number(data, "limit_start", p, 1.0, MAX_LIVE)
	tuning.limit_per_kill = reader.number(data, "limit_per_kill", p, 0.0, MAX_LIVE)
	tuning.limit_max = reader.integer(data, "limit_max", p, 1, MAX_LIVE)
	tuning.delay_min = reader.number(data, "delay_min", p, 0.0, MAX_SECONDS)
	tuning.delay_max = reader.number(data, "delay_max", p, 0.0, MAX_SECONDS)
	tuning.buffer_start = reader.number(data, "buffer_start", p, 0.0, MAX_SECONDS)
	tuning.buffer_per_kill = reader.number(data, "buffer_per_kill", p, 0.0, MAX_SECONDS)
	tuning.buffer_min = reader.number(data, "buffer_min", p, 0.0, MAX_SECONDS)
	tuning.aggression_start = reader.number(data, "aggression_start", p, 0.0, 1.0)
	tuning.aggression_per_kill = reader.number(data, "aggression_per_kill", p, 0.0, 1.0)
	tuning.aggression_max = reader.number(data, "aggression_max", p, 0.0, 1.0)
	tuning.wave_interval = reader.number(data, "wave_interval", p, 0.0, MAX_SECONDS)
	tuning.wave_size_start = reader.integer(data, "wave_size_start", p, 0, MAX_LIVE)
	tuning.wave_size_growth = reader.integer(data, "wave_size_growth", p, 0, MAX_LIVE)
	tuning.wave_spread = reader.number(data, "wave_spread", p, 0.0, MAX_ANGLE)
	if tuning.limit_start > tuning.limit_max:
		reader.fail(p, "limit_start must not exceed limit_max")
	if tuning.delay_min > tuning.delay_max:
		reader.fail(p, "delay_min must not exceed delay_max")
	if tuning.buffer_min > tuning.buffer_start:
		reader.fail(p, "buffer_min must not exceed buffer_start")
	if tuning.aggression_start > tuning.aggression_max:
		reader.fail(p, "aggression_start must not exceed aggression_max")
	if tuning.wave_interval <= 0.0:
		reader.fail(p + ".wave_interval", "must be positive")


static func _color(hex: String, reader: DataReader, path: String) -> Color:
	if not hex.begins_with("#") or not Color.html_is_valid(hex):
		reader.fail(path, "must be a #rrggbb color")
		return Color.BLACK
	return Color.html(hex)


static func _vec2(items: Array, reader: DataReader, path: String) -> Vector2:
	if items.size() != 2 or not _all_numbers(items):
		reader.fail(path, "must be two numbers")
		return Vector2.ZERO
	var x: float = items[0]
	var y: float = items[1]
	return Vector2(x, y)


static func _vec3(items: Array, reader: DataReader) -> Vector3:
	if items.size() != 3 or not _all_numbers(items):
		reader.fail("camera", "offsets must be three numbers")
		return Vector3.ZERO
	var x: float = items[0]
	var y: float = items[1]
	var z: float = items[2]
	return Vector3(x, y, z)


static func _all_numbers(items: Array) -> bool:
	for item: Variant in items:
		if not (item is float or item is int):
			return false
	return true
