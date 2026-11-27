extends GdUnitTestSuite
## The six bosses (#74, #73): every Level's boss is valid and has a body and a
## pattern for every attack; it flies in, changes phase exactly at its
## thresholds, telegraphs every attack, fires projectiles that fall, and is
## defeated exactly once, dropping a Repair Kit, then plays its defeat sequence.

const STEP: float = FieldHarness.STEP
## The phase count per boss, from #73's Levels table.
const SPEC_PHASES: Dictionary[StringName, int] = {
	&"albatross": 1,
	&"thunderhead": 2,
	&"hornet": 2,
	&"leviathan": 2,
	&"crimson_lancer": 3,
	&"ascendant": 3,
}
## Seconds the scripted fight may take per boss before the test gives up.
const FIGHT_LIMIT: float = 120.0
## Ticks between scripted player shots (10 a second at 60 Hz).
const SHOT_EVERY: int = 6

var _h: FieldHarness
var _health: BossHealth
var _arena: BossArena
var _director: SpawnDirector
var _phase_changes: Array[int] = []
var _defeats: Array[StringName] = []
var _damaged: Array[int] = []


func before_test() -> void:
	_h = FieldHarness.new()
	add_child(_h.field)
	_health = BossHealth.new(_h.bus)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = FieldHarness.SEED
	_director = SpawnDirector.new(_h.bus, rng, _h.levels)
	_arena = BossArena.new()
	add_child(_arena)
	_arena.setup(_h.bus, _h.levels, _h.field)
	_phase_changes.clear()
	_defeats.clear()
	_damaged.clear()
	var subscribed: Array[int] = [
		_h.bus.boss.boss_phase_changed.connect(_on_phase),
		_h.bus.boss.boss_defeated.connect(_on_defeated),
		_h.bus.boss.boss_damaged.connect(_on_damaged),
	]
	var _ok: GdUnitAssert = assert_int(subscribed.count(OK)).is_equal(subscribed.size())


func after_test() -> void:
	_arena.free()
	_h.dispose()


## Records each boss attack's telegraph start and how long it charged.
class AttackLog:
	extends RefCounted

	var clock: float = 0.0
	## attack id -> its data telegraph (seconds).
	var telegraph_of: Dictionary[StringName, float] = {}
	var fires: int = 0
	## Per shot: charge time minus the attack's own telegraph (never negative).
	var slack: Array[float] = []
	var _started: Dictionary[StringName, float] = {}

	func on_telegraphed(attack_id: StringName) -> void:
		_started[attack_id] = clock

	func on_fired(attack_id: StringName) -> void:
		fires += 1
		var began: float = _started[attack_id] if _started.has(attack_id) else INF
		slack.append(clock - began - telegraph_of[attack_id])
		var _cleared: bool = _started.erase(attack_id)


func _on_phase(phase: int, _phases: int) -> void:
	_phase_changes.append(phase)


func _on_defeated(boss_id: StringName, _position: Vector3) -> void:
	_defeats.append(boss_id)


func _on_damaged(health: int, _max_health: int) -> void:
	_damaged.append(health)


## Opens Level `level_number`'s Boss Fight as LevelProgression would: the
## Level loads, BossHealth is armed and the boss is summoned.
func _summon(level_number: int) -> Boss:
	_h.enter_level(level_number)
	var boss: BossDefinition = _h.levels[level_number - 1].boss
	_h.bus.flow.announce_game_state_changed(
		GameState.Phase.BOSS_WARNING, GameState.Phase.BOSS_FIGHT
	)
	_health.arm(boss)
	_h.bus.boss.announce_boss_summoned(boss.id, boss.display_name, boss.health, boss.phases.size())
	return _arena.boss()


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > 1e-6:
		_arena.step(STEP)
		_h.field.step(STEP)
		left -= STEP


func _enter(boss: Boss) -> void:
	var guard: int = 0
	while boss.state() == Boss.State.ENTERING and guard < 1000:
		_advance(STEP)
		guard += 1


## One player shot straight into the boss's centre.
func _shoot(boss: Boss) -> bool:
	return _arena.resolve_shot(boss.position, 0.3)


func test_every_level_defines_a_valid_boss() -> void:
	var errors: Array[String] = []
	var levels: Array[LevelDefinition] = LevelLibrary.all_levels(errors)
	var _parses: GdUnitAssert = assert_array(errors).is_empty()
	var _six: GdUnitAssert = assert_int(levels.size()).is_equal(6)
	var seen: Array[StringName] = []
	for level: LevelDefinition in levels:
		var boss: BossDefinition = level.boss
		seen.append(boss.id)
		var _has_body: GdUnitAssert = assert_object(BossProfile.of(boss.id)).is_not_null()
		var _spec_phases: GdUnitAssert = assert_int(boss.phases.size()).is_equal(
			SPEC_PHASES[boss.id]
		)
		var _has_health: GdUnitAssert = assert_int(boss.health).is_greater(0)
		var _turrets: GdUnitAssert = assert_int(BossProfile.of(boss.id).turrets.size()).is_greater(
			0
		)
		for phase: BossDefinition.Phase in boss.phases:
			for attack: BossDefinition.Attack in phase.attacks:
				var _has_pattern: GdUnitAssert = (
					assert_object(BossPattern.of(attack.id)).is_not_null()
				)
				var _telegraphed: GdUnitAssert = assert_float(attack.telegraph).is_greater_equal(
					RunRules.MIN_TELEGRAPH
				)
	var _all_six: GdUnitAssert = assert_array(seen).contains_exactly_in_any_order(
		SPEC_PHASES.keys()
	)
	var _bodies_match: GdUnitAssert = assert_array(BossProfile.ids()).contains_exactly_in_any_order(
		seen
	)


func test_boss_flies_in_then_fights() -> void:
	var boss: Boss = _summon(1)
	var start: Vector3 = boss.position
	var glanced: bool = _shoot(boss)
	var damaged_while_entering: int = _damaged.size()
	_enter(boss)
	var landed: bool = _shoot(boss)
	var profile: BossProfile = BossProfile.of(&"albatross")
	var _from_off_screen: GdUnitAssert = assert_float(start.distance_to(_h.target.at)).is_greater(
		profile.station.length() + 20.0
	)
	var _glances_off: GdUnitAssert = assert_bool(glanced).is_true()
	var _no_damage_entering: GdUnitAssert = assert_int(damaged_while_entering).is_equal(0)
	var _fighting: GdUnitAssert = assert_int(boss.state()).is_equal(Boss.State.FIGHTING)
	var _near_station: GdUnitAssert = (
		assert_float(boss.position.distance_to(_h.target.at + profile.station))
		. is_less(profile.weave.length() + 1.0)
	)
	var _landed: GdUnitAssert = assert_bool(landed).is_true()
	var _shot_damage: GdUnitAssert = assert_array(_damaged).is_equal(
		[_h.levels[0].boss.health - _h.levels[0].player.projectile_damage]
	)


func test_boss_changes_phase_at_thresholds() -> void:
	var boss: Boss = _summon(5)
	var definition: BossDefinition = _h.levels[4].boss
	_enter(boss)
	var phases_seen: Array[int] = [boss.phase()]
	var attacks_seen: Array[Array] = [boss.attack_ids()]
	var crossings_ok: bool = true
	var guard: int = 0
	while _defeats.is_empty() and guard < 1000:
		var _hit: bool = _shoot(boss)
		guard += 1
		var health: int = _health.health()
		var want: int = definition.phase_for(health)
		crossings_ok = crossings_ok and boss.phase() == want
		if boss.phase() != phases_seen[-1]:
			phases_seen.append(boss.phase())
			attacks_seen.append(boss.attack_ids())
			# It crossed on this very hit: the phase starts at this fraction.
			var fraction: float = float(health) / definition.health
			var _at_threshold: GdUnitAssert = assert_float(fraction).is_less_equal(
				definition.phases[boss.phase()].starts_at
			)
	var _every_hit_in_phase: GdUnitAssert = assert_bool(crossings_ok).is_true()
	var _three_phases: GdUnitAssert = assert_array(phases_seen).is_equal([0, 1, 2])
	var _announced: GdUnitAssert = assert_array(_phase_changes).is_equal([1, 2])
	for i: int in phases_seen.size():
		var expected: Array[StringName] = []
		for attack: BossDefinition.Attack in definition.phases[i].attacks:
			expected.append(attack.id)
		var _patterns_switch: GdUnitAssert = assert_array(attacks_seen[i]).is_equal(expected)


func test_boss_attacks_are_telegraphed() -> void:
	_h.target.invulnerable = true
	for level_number: int in range(1, 7):
		var boss: Boss = _summon(level_number)
		_enter(boss)
		var definition: BossDefinition = _h.levels[level_number - 1].boss
		var record: AttackLog = AttackLog.new()
		var errs: Array[int] = [
			boss.telegraphed.connect(record.on_telegraphed),
			boss.fired.connect(record.on_fired),
		]
		var _watched: GdUnitAssert = assert_int(errs.count(OK)).is_equal(2)
		var glow: float = 0.0
		for phase_index: int in definition.phases.size():
			_h.bus.boss.announce_boss_phase_changed(phase_index, definition.phases.size())
			for attack: BossDefinition.Attack in definition.phases[phase_index].attacks:
				record.telegraph_of[attack.id] = attack.telegraph
			for _i: int in 600:
				record.clock += STEP
				_advance(STEP)
				if boss.is_telegraphing():
					glow = maxf(glow, boss.look().glow_energy())
		var _fired: GdUnitAssert = assert_int(record.fires).is_greater(definition.phases.size())
		for slack: float in record.slack:
			# Never sooner than its own telegraph after the glow began.
			var _telegraphed: GdUnitAssert = assert_float(slack).is_greater_equal(-1e-6)
		var _glows: GdUnitAssert = assert_float(glow).is_greater(BossLook.GLOW_IDLE * 4.0)


func test_boss_projectiles_obey_gravity() -> void:
	_h.target.invulnerable = true
	var checked: int = 0
	for level_number: int in range(1, 7):
		var boss: Boss = _summon(level_number)
		_enter(boss)
		var definition: BossDefinition = _h.levels[level_number - 1].boss
		var damages: Array[int] = []
		for phase: BossDefinition.Phase in definition.phases:
			for attack: BossDefinition.Attack in phase.attacks:
				damages.append(attack.damage)
		for phase_index: int in definition.phases.size():
			_h.bus.boss.announce_boss_phase_changed(phase_index, definition.phases.size())
			for _i: int in 300:
				_advance(STEP)
				for shot: EnemyShot in _h.field.shots().live_shots():
					if shot.spec.source != DamageSource.Source.BOSS_ATTACK:
						continue
					var fall_before: float = shot.velocity.y
					var gravity: float = shot.spec.gravity
					var _falls: GdUnitAssert = assert_float(gravity).is_greater(0.0)
					var _own_damage: GdUnitAssert = (
						assert_bool(damages.has(shot.spec.attack_damage)).is_true()
					)
					shot.step(STEP, _h.target.at, false)
					if shot.is_live():
						var _pulled_down: GdUnitAssert = (
							assert_float(shot.velocity.y)
							. is_equal_approx(fall_before - gravity * STEP, 1e-4)
						)
						checked += 1
	var _many: GdUnitAssert = assert_int(checked).is_greater(100)


func test_boss_defeat_emits_once_and_drops_repair() -> void:
	var boss: Boss = _summon(2)
	_enter(boss)
	var bursts: Array[int] = []
	var err: int = boss.defeat_burst.connect(
		func(_at: Vector3, index: int) -> void: bursts.append(index)
	)
	var guard: int = 0
	while _defeats.is_empty() and guard < 1000:
		var _hit: bool = _shoot(boss)
		guard += 1
	var drops_at_defeat: int = _h.repair_drops
	# More shots after the defeat: they pass through, nothing more happens.
	var through: bool = _shoot(boss)
	for _i: int in 5:
		var _late: bool = _shoot(boss)
	_advance(BossProfile.DEFEAT_TIME + STEP)
	var _connected: GdUnitAssert = assert_int(err).is_equal(OK)
	var _once: GdUnitAssert = assert_array(_defeats).is_equal([&"thunderhead"])
	var _one_kit: GdUnitAssert = assert_int(drops_at_defeat).is_equal(1)
	var _still_one: GdUnitAssert = assert_int(_h.repair_drops).is_equal(1)
	var _passes_through: GdUnitAssert = assert_bool(through).is_false()
	var _chain: GdUnitAssert = assert_int(bursts.size()).is_greater_equal(
		floori(BossProfile.DEFEAT_TIME / BossProfile.DEFEAT_BURST_GAP)
	)
	var _gone: GdUnitAssert = assert_object(_arena.boss()).is_null()


func test_all_six_bosses_spawn_and_can_be_defeated() -> void:
	_h.target.invulnerable = true
	for level_number: int in range(1, 7):
		var boss: Boss = _summon(level_number)
		var boss_id: StringName = _h.levels[level_number - 1].boss.id
		var _spawned: GdUnitAssert = assert_object(boss).is_not_null()
		var _named: GdUnitAssert = assert_str(String(boss.definition.id)).is_equal(String(boss_id))
		_enter(boss)
		var ticks: int = 0
		while _defeats.size() < level_number and ticks * STEP < FIGHT_LIMIT:
			# A steady stream of shots, ten a second, while the fight goes on.
			if ticks % SHOT_EVERY == 0:
				var _hit: bool = _shoot(boss)
			_advance(STEP)
			ticks += 1
		var _defeated: GdUnitAssert = assert_int(_defeats.size()).is_equal(level_number)
		var _this_one: GdUnitAssert = assert_str(String(_defeats[-1])).is_equal(String(boss_id))
		_advance(BossProfile.DEFEAT_TIME + STEP)
		var _sequence_ends: GdUnitAssert = assert_object(_arena.boss()).is_null()


func test_boss_dash_strikes_with_its_attack_damage() -> void:
	var boss: Boss = _summon(3)
	_enter(boss)
	var dash_damage: int = 0
	for attack: BossDefinition.Attack in _h.levels[2].boss.phases[0].attacks:
		if attack.id == &"dash":
			dash_damage = attack.damage
	var dashed: bool = false
	var guard: int = 0
	var lanced: int = RunRules.damage_for(DamageSource.Source.BOSS_ATTACK, dash_damage)
	while not _h.target.damage_taken.has(lanced) and guard < 1200:
		_advance(STEP)
		dashed = dashed or boss.is_dashing()
		guard += 1
	var _dashed: GdUnitAssert = assert_bool(dashed).is_true()
	var _boss_attack: GdUnitAssert = (
		assert_bool(_h.player_hits.has(DamageSource.Source.BOSS_ATTACK)).is_true()
	)
	var _attack_damage: GdUnitAssert = (
		assert_bool(
			_h.target.damage_taken.has(
				RunRules.damage_for(DamageSource.Source.BOSS_ATTACK, dash_damage)
			)
		)
		. is_true()
	)


func test_leviathan_launches_drone_waves() -> void:
	_h.target.invulnerable = true
	var boss: Boss = _summon(4)
	_enter(boss)
	var spawned_before: int = _h.spawned.size()
	_advance(6.0)
	var drones: int = 0
	for enemy_id: int in _h.spawned:
		if _h.spawned[enemy_id] == EnemyKind.Kind.DRONE:
			drones += 1
	var _launched: GdUnitAssert = assert_int(drones).is_greater_equal(3)
	var _reported_as_enemies: GdUnitAssert = assert_int(_h.spawned.size()).is_greater(
		spawned_before
	)
	# The spawn director counts them as live, like any spawned enemy.
	var _counted: GdUnitAssert = assert_int(_director.live_count()).is_equal(
		_h.field.active_enemies().size()
	)
