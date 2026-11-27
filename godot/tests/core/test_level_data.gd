extends GdUnitTestSuite
## The six Level files (#73 "Levels"), read through game/level_library.gd and
## checked by core/level_definition.gd.

const NAMES: Array[String] = [
	"Dawn Patrol", "Storm Front", "Sunset Strike", "Night Raid", "Stratosphere", "Edge of Orbit"
]
const THRESHOLDS: Array[int] = [4000, 6000, 8000, 10000, 12000, 15000]
const BOSSES: Array[StringName] = [
	&"albatross", &"thunderhead", &"hornet", &"leviathan", &"crimson_lancer", &"ascendant"
]
const PHASE_COUNTS: Array[int] = [1, 2, 2, 2, 3, 3]


func _levels() -> Array[LevelDefinition]:
	var errors: Array[String] = []
	var levels: Array[LevelDefinition] = LevelLibrary.all_levels(errors)
	var _clean: GdUnitAssert = assert_array(errors).is_empty()
	return levels


func _roster_ids(roster: Array[LevelDefinition.RosterEntry]) -> Array[String]:
	var ids: Array[String] = []
	for entry: LevelDefinition.RosterEntry in roster:
		ids.append(String(EnemyKind.id_of(entry.kind)))
	return ids


func _level_1_document() -> Dictionary:
	var data: Variant = LevelLibrary.FILES[0].data
	var document: Dictionary = data
	return document.duplicate(true)


func test_level_1_loads_parity_values() -> void:
	var level: LevelDefinition = _levels()[0]
	var _id: GdUnitAssert = assert_str(String(level.id)).is_equal("level_1")
	var _name: GdUnitAssert = assert_str(level.display_name).is_equal("Dawn Patrol")
	var _speed: GdUnitAssert = assert_float(level.player.speed).is_equal(10.0)
	var _coast: GdUnitAssert = assert_float(level.player.coast_factor).is_equal(0.3)
	var _move: GdUnitAssert = assert_vector(level.player.initial_move).is_equal(Vector2(0, 0.5))
	var _fire: GdUnitAssert = assert_float(level.player.fire_interval).is_equal(0.25)
	var _muzzle: GdUnitAssert = assert_float(level.player.muzzle_offset).is_equal(3.0)
	var _shot_speed: GdUnitAssert = assert_float(level.player.projectile_speed).is_equal(24.0)
	var _shot_life: GdUnitAssert = assert_float(level.player.projectile_lifetime).is_equal(10.0)
	var _shot_damage: GdUnitAssert = assert_int(level.player.projectile_damage).is_equal(3)
	var _fov: GdUnitAssert = assert_float(level.camera.fov).is_equal(60.0)
	var _land: GdUnitAssert = assert_vector(level.camera.offset_landscape).is_equal(
		Vector3(0, 0, 22)
	)
	var _port: GdUnitAssert = assert_vector(level.camera.offset_portrait).is_equal(
		Vector3(0, -2, 32)
	)
	var _damping: GdUnitAssert = assert_float(level.camera.damping).is_equal(1.0)
	var _far: GdUnitAssert = assert_float(level.camera.far).is_equal(100.0)
	var _sphere: GdUnitAssert = assert_float(level.play_sphere_radius).is_equal(40.0)
	var _distance: GdUnitAssert = assert_float(level.spawn.spawn_distance).is_equal(25.0)
	var _delay: GdUnitAssert = (
		assert_array([level.spawn.delay_min, level.spawn.delay_max]).is_equal([0.1, 0.8])
	)
	var _death: GdUnitAssert = assert_float(level.game_over_delay).is_equal(2.0)
	var _intro: GdUnitAssert = assert_float(level.intro_duration).is_equal(2.5)
	var _threshold: GdUnitAssert = assert_int(level.boss.threshold).is_equal(4000)
	var _fighters: GdUnitAssert = assert_array(_roster_ids(level.roster)).is_equal(["fighter"])


func test_all_six_levels_load_in_order() -> void:
	var levels: Array[LevelDefinition] = _levels()
	var numbers: Array[int] = []
	var names: Array[String] = []
	for level: LevelDefinition in levels:
		numbers.append(level.number)
		names.append(level.display_name)
	var _numbers: GdUnitAssert = assert_array(numbers).is_equal([1, 2, 3, 4, 5, 6])
	var _names: GdUnitAssert = assert_array(names).is_equal(NAMES)


func test_levels_match_spec_rosters_thresholds_and_bosses() -> void:
	var levels: Array[LevelDefinition] = _levels()
	var rosters: Array = []
	var thresholds: Array[int] = []
	var bosses: Array[StringName] = []
	var phases: Array[int] = []
	for level: LevelDefinition in levels:
		var ids: Array[String] = _roster_ids(level.roster)
		ids.sort()
		rosters.append(ids)
		thresholds.append(level.boss.threshold)
		bosses.append(level.boss.id)
		phases.append(level.boss.phases.size())
	var everything: Array[String] = []
	for id: StringName in EnemyKind.IDS:
		everything.append(String(id))
	everything.sort()
	var expected: Array = [
		["fighter"],
		["fighter", "heavy"],
		["fighter", "interceptor"],
		["drone", "interceptor"],
		["bomber", "drone", "enemy_mech"],
		everything,
	]
	var _rosters: GdUnitAssert = assert_array(rosters).is_equal(expected)
	var _thresholds: GdUnitAssert = assert_array(thresholds).is_equal(THRESHOLDS)
	var _bosses: GdUnitAssert = assert_array(bosses).is_equal(BOSSES)
	var _phases: GdUnitAssert = assert_array(phases).is_equal(PHASE_COUNTS)


func test_levels_ramp_difficulty_across_levels() -> void:
	var levels: Array[LevelDefinition] = _levels()
	var falls: Array[String] = []
	for i: int in range(1, levels.size()):
		var a: LevelDefinition = levels[i - 1]
		var b: LevelDefinition = levels[i]
		if b.enemy_speed_scale <= a.enemy_speed_scale:
			falls.append("speed %d" % b.number)
		if b.enemy_fire_rate_scale <= a.enemy_fire_rate_scale:
			falls.append("fire rate %d" % b.number)
		if b.enemy_bullet_speed_scale <= a.enemy_bullet_speed_scale:
			falls.append("bullet speed %d" % b.number)
		if b.spawn.delay_max >= a.spawn.delay_max or b.spawn.buffer_start >= a.spawn.buffer_start:
			falls.append("spawn delay %d" % b.number)
		if b.boss.health <= a.boss.health or b.boss.threshold <= a.boss.threshold:
			falls.append("boss %d" % b.number)
	var _ramps: GdUnitAssert = assert_array(falls).is_empty()


func test_boss_attacks_are_telegraphed_with_damage_in_range() -> void:
	var problems: Array[String] = []
	for level: LevelDefinition in _levels():
		for phase: BossDefinition.Phase in level.boss.phases:
			for attack: BossDefinition.Attack in phase.attacks:
				if attack.telegraph < RunRules.MIN_TELEGRAPH:
					problems.append("%s telegraph" % attack.id)
				if attack.damage < 15 or attack.damage > 35:
					problems.append("%s damage" % attack.id)
		var first: float = level.boss.phases[0].starts_at
		if first != 1.0:
			problems.append("%s first phase" % level.boss.id)
	var _ok: GdUnitAssert = assert_array(problems).is_empty()


func test_level_parser_rejects_invalid_data() -> void:
	var cases: Array[Dictionary] = []
	var missing: Dictionary = _level_1_document()
	var _erased: bool = missing.erase("boss")
	cases.append(missing)
	var bad_kind: Dictionary = _level_1_document()
	var roster: Array = bad_kind["roster"]
	var first: Dictionary = roster[0]
	first["kind"] = "zeppelin"
	cases.append(bad_kind)
	var rising: Dictionary = _level_1_document()
	var boss: Dictionary = rising["boss"]
	var phases: Array = boss["phases"]
	phases.append({"starts_at": 1.0, "attacks": phases[0]["attacks"]})
	cases.append(rising)
	var weak: Dictionary = _level_1_document()
	var weak_boss: Dictionary = weak["boss"]
	var weak_phase: Dictionary = weak_boss["phases"][0]
	var weak_attack: Dictionary = weak_phase["attacks"][0]
	weak_attack["telegraph"] = 0.1
	cases.append(weak)
	var renumbered: Dictionary = _level_1_document()
	renumbered["number"] = 2
	cases.append(renumbered)
	var rejected: int = 0
	for data: Dictionary in cases:
		var errors: Array[String] = []
		if LevelDefinition.parse(data, errors) == null and not errors.is_empty():
			rejected += 1
	var valid: LevelDefinition = LevelDefinition.parse(_level_1_document())
	var _all_rejected: GdUnitAssert = assert_int(rejected).is_equal(cases.size())
	var _valid_accepted: GdUnitAssert = assert_object(valid).is_not_null()
