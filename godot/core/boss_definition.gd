class_name BossDefinition
extends RefCounted
## A Level's boss, parsed from the Level data's `boss` object (#73, #74):
## identity, Boss Gauge threshold, health, phases with their attacks, and the
## escorts that spawn during the Boss Fight.


## One boss attack: telegraphed `telegraph` seconds before it fires.
class Attack:
	extends RefCounted

	var id: StringName = &""
	var damage: int = 0
	var telegraph: float = 0.0
	var interval: float = 0.0


## One phase: it starts when health falls to `starts_at` times the maximum.
class Phase:
	extends RefCounted

	var starts_at: float = 1.0
	var attacks: Array[Attack] = []


## Stable id, shown name and the one-line Intel description.
var id: StringName = &""
var display_name: String = ""
var description: String = ""
## Boss Gauge points that summon the boss.
var threshold: int = 0
## Health pool.
var health: int = 0
## Phases in order; the first starts at full health.
var phases: Array[Phase] = []
## Escorts during the Boss Fight: weighted roster, live limit and spawn delay range.
var escort_roster: Array[LevelDefinition.RosterEntry] = []
var escort_limit: int = 0
var escort_delay_min: float = 0.0
var escort_delay_max: float = 0.0


## Parses `data` (the `boss` object). Failures are recorded in `reader`.
static func parse(data: Dictionary, reader: DataReader, path: String) -> BossDefinition:
	var boss: BossDefinition = BossDefinition.new()
	boss.id = StringName(reader.text(data, "id", path))
	boss.display_name = reader.text(data, "name", path)
	boss.description = reader.text(data, "description", path)
	boss.threshold = reader.integer(data, "threshold", path, 1, LevelDefinition.MAX_POINTS)
	boss.health = reader.integer(data, "health", path, 1, LevelDefinition.MAX_POINTS)
	var phase_list: Array = reader.list(data, "phases", path)
	var previous: float = INF
	for i: int in phase_list.size():
		var phase_path: String = "%s.phases[%d]" % [path, i]
		var phase: Phase = _parse_phase(
			reader.element(phase_list, i, path + ".phases"), reader, phase_path
		)
		if (i == 0 and phase.starts_at != 1.0) or phase.starts_at >= previous:
			reader.fail(
				phase_path, "starts_at must be 1 for the first phase, then strictly descend"
			)
		previous = phase.starts_at
		boss.phases.append(phase)
	if boss.phases.is_empty():
		reader.fail(path + ".phases", "needs at least one phase")
	var escorts: Dictionary = reader.object(data, "escorts", path)
	var escorts_path: String = path + ".escorts"
	boss.escort_roster = LevelDefinition.parse_roster(escorts, reader, escorts_path)
	boss.escort_limit = reader.integer(escorts, "limit", escorts_path, 0, LevelDefinition.MAX_LIVE)
	boss.escort_delay_min = reader.number(
		escorts, "delay_min", escorts_path, 0.0, LevelDefinition.MAX_SECONDS
	)
	boss.escort_delay_max = reader.number(
		escorts, "delay_max", escorts_path, 0.0, LevelDefinition.MAX_SECONDS
	)
	if boss.escort_delay_min > boss.escort_delay_max:
		reader.fail(escorts_path, "delay_min must not exceed delay_max")
	return boss


## The phase index for `health` out of the maximum: the last phase whose
## starts_at fraction has been reached.
func phase_for(current_health: int) -> int:
	var fraction: float = float(current_health) / maxi(health, 1)
	var index: int = 0
	for i: int in phases.size():
		if fraction <= phases[i].starts_at:
			index = i
	return index


static func _parse_phase(data: Dictionary, reader: DataReader, path: String) -> Phase:
	var phase: Phase = Phase.new()
	phase.starts_at = reader.number(data, "starts_at", path, 0.0, 1.0)
	var attacks: Array = reader.list(data, "attacks", path)
	for i: int in attacks.size():
		var attack_path: String = "%s.attacks[%d]" % [path, i]
		var raw: Dictionary = reader.element(attacks, i, path + ".attacks")
		var attack: Attack = Attack.new()
		attack.id = StringName(reader.text(raw, "id", attack_path))
		attack.damage = reader.integer(
			raw,
			"damage",
			attack_path,
			RunRules.BOSS_ATTACK_DAMAGE_MIN,
			RunRules.BOSS_ATTACK_DAMAGE_MAX
		)
		attack.telegraph = reader.number(
			raw, "telegraph", attack_path, RunRules.MIN_TELEGRAPH, LevelDefinition.MAX_SECONDS
		)
		attack.interval = reader.number(
			raw, "interval", attack_path, 0.0, LevelDefinition.MAX_SECONDS
		)
		phase.attacks.append(attack)
	if phase.attacks.is_empty():
		reader.fail(path + ".attacks", "needs at least one attack")
	return phase
