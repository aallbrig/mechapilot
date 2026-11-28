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
## Where a hull probe sits, as a share of the hull's top edge (clear of the bays).
const HULL_PROBE: float = 0.75
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


## Records each player hit with whether the boss was charging and touching.
class HitLog:
	extends RefCounted

	var boss: Boss
	var reach: float = 0.0
	## Per hit: source, attack damage, and whether it was a charge on the body.
	var sources: Array[DamageSource.Source] = []
	var damages: Array[int] = []
	var charging: Array[bool] = []

	func on_player_hit(source: DamageSource.Source, at: Vector3, attack_damage: int) -> void:
		sources.append(source)
		damages.append(attack_damage)
		var touching: bool = boss.touches(at, reach)
		charging.append(boss.is_dashing() and touching)

	## Hits with `damage` as BOSS_ATTACK that landed mid-charge on the body.
	func lance_hits(damage: int) -> int:
		var count: int = 0
		for i: int in sources.size():
			if (
				sources[i] == DamageSource.Source.BOSS_ATTACK
				and damages[i] == damage
				and charging[i]
			):
				count += 1
		return count

	## Hits with `damage` that were not a charge on the body.
	func stray_hits(damage: int) -> int:
		var count: int = 0
		for i: int in sources.size():
			if damages[i] == damage and not charging[i]:
				count += 1
		return count


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
	return _arena.resolve_shot(boss.weak_point(), 0.3)


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
		var look: BossLook = auto_free(BossLook.new(BossProfile.of(boss.id)))
		var _turrets: GdUnitAssert = assert_int(look.turret_points().size()).is_greater(0)
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
	# Crimson Lancer: 540 health, phases from 0.66 and 0.33, shots of 3. Phase 1
	# starts once health <= 356.4: the 62nd shot takes it from 357 to 354.
	# Phase 2 starts once health <= 178.2: the 121st shot, from 180 to 177.
	var expected_crossings: Array[int] = [354, 177]
	var boss: Boss = _summon(5)
	var definition: BossDefinition = _h.levels[4].boss
	_enter(boss)
	var _lancer_health: GdUnitAssert = assert_int(definition.health).is_equal(540)
	var _shot_of_3: GdUnitAssert = assert_int(_h.levels[4].player.projectile_damage).is_equal(3)
	var phases_seen: Array[int] = [boss.phase()]
	var attacks_seen: Array[Array] = [boss.attack_ids()]
	var colors_seen: Array[Color] = [boss.look().core_color()]
	var crossings: Array[int] = []
	var guard: int = 0
	while _defeats.is_empty() and guard < 1000:
		var _hit: bool = _shoot(boss)
		guard += 1
		if boss.phase() != phases_seen[-1]:
			phases_seen.append(boss.phase())
			attacks_seen.append(boss.attack_ids())
			colors_seen.append(boss.look().core_color())
			crossings.append(_health.health())
	var _exactly_there: GdUnitAssert = assert_array(crossings).is_equal(expected_crossings)
	var _three_phases: GdUnitAssert = assert_array(phases_seen).is_equal([0, 1, 2])
	var _announced: GdUnitAssert = assert_array(_phase_changes).is_equal([1, 2])
	for i: int in phases_seen.size():
		var expected: Array[StringName] = []
		for attack: BossDefinition.Attack in definition.phases[i].attacks:
			expected.append(attack.id)
		var _patterns_switch: GdUnitAssert = assert_array(attacks_seen[i]).is_equal(expected)
		# The core shows the phase.
		var _core_shows_phase: GdUnitAssert = assert_str(colors_seen[i].to_html()).is_equal(
			BossLook.PHASE_CORE_COLORS[i].to_html()
		)


func test_leviathan_core_is_shielded_until_its_bays_are_destroyed() -> void:
	var boss: Boss = _summon(4)
	_enter(boss)
	var definition: BossDefinition = _h.levels[3].boss
	var full: int = _health.health()
	# The hull deflects a shot on it away from the bays: spent, but deals nothing.
	var hull: Rect2 = boss.look().hull_rect()
	var on_hull: Vector3 = boss.position + Vector3(0.0, hull.end.y * HULL_PROBE, 0.0)
	var deflected: bool = _arena.resolve_shot(on_hull, 0.3)
	var after_core_shot: int = _health.health()
	var shielded: bool = boss.is_shielded()
	var bays_up: bool = not boss.look().bays_destroyed()
	# Shots at a launch bay wear it down until the bays are wrecked (phase 1).
	var guard: int = 0
	while boss.phase() == 0 and guard < 1000:
		var _bay_hit: bool = _arena.resolve_shot(boss.weak_point(), 0.3)
		guard += 1
	var at_exposure: int = _health.health()
	var core_hit: bool = _arena.resolve_shot(boss.position, 0.3)
	var _deflected: GdUnitAssert = assert_bool(deflected).is_true()
	var _no_core_damage: GdUnitAssert = assert_int(after_core_shot).is_equal(full)
	var _shielded: GdUnitAssert = assert_bool(shielded).is_true()
	var _bays_shown: GdUnitAssert = assert_bool(bays_up).is_true()
	var _bays_take_hits: GdUnitAssert = assert_int(boss.phase()).is_equal(1)
	var _exposed: GdUnitAssert = assert_bool(boss.is_shielded()).is_false()
	var _bays_wrecked: GdUnitAssert = assert_bool(boss.look().bays_destroyed()).is_true()
	var _at_threshold: GdUnitAssert = (
		assert_float(float(at_exposure) / definition.health)
		. is_less_equal(definition.phases[1].starts_at)
	)
	var _core_takes_hits: GdUnitAssert = assert_bool(core_hit).is_true()
	var _core_damaged: GdUnitAssert = assert_int(_health.health()).is_equal(
		at_exposure - _h.levels[3].player.projectile_damage
	)


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
	# Crimson Lancer's last phase: a 35-damage lance charge (not the 25 of a
	# ram) and a 22-damage spread, so the damage tells the two hits apart.
	var boss: Boss = _summon(5)
	_enter(boss)
	_h.bus.boss.announce_boss_phase_changed(2, 3)
	var lance: BossDefinition.Attack = null
	for attack: BossDefinition.Attack in _h.levels[4].boss.phases[2].attacks:
		if attack.id == &"charge_lance":
			lance = attack
	var record: HitLog = HitLog.new()
	record.boss = boss
	record.reach = _h.target.radius()
	var err: int = _h.bus.player.player_hit.connect(record.on_player_hit)
	for _i: int in roundi(15.0 / STEP):
		_advance(STEP)
	_h.bus.player.player_hit.disconnect(record.on_player_hit)
	var _connected: GdUnitAssert = assert_int(err).is_equal(OK)
	var _lance_35: GdUnitAssert = assert_int(lance.damage).is_equal(35)
	var _not_a_ram: GdUnitAssert = assert_int(lance.damage).is_not_equal(RunRules.COLLISION_DAMAGE)
	# A BOSS_ATTACK hit with the lance's own damage, on the boss body, mid-charge.
	var _lanced: GdUnitAssert = assert_int(record.lance_hits(lance.damage)).is_greater(0)
	# Every hit with the lance's damage came from the charge, never a projectile.
	var _only_while_dashing: GdUnitAssert = assert_int(record.stray_hits(lance.damage)).is_equal(0)


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
