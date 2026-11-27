extends GdUnitTestSuite
## The Run ledger (#73): scoring table, combo, Armor and damage, invulnerability,
## lives, the one-time bonus life, boss score, Level Clear bonus and Run time.

const STEP: float = 1.0 / 60.0

var _bus: EventBus
var _ledger: RunLedger
var _lives_lost: Array[int] = []
var _destroyed: Array[DestroyCause.Cause] = []
var _bonus_lives: Array[int] = []
var _armor_deltas: Array[int] = []
var _next_id: int = 1


func before_test() -> void:
	_bus = EventBus.new()
	_ledger = RunLedger.new(_bus)
	_lives_lost.clear()
	_destroyed.clear()
	_bonus_lives.clear()
	_armor_deltas.clear()
	var subscribed: Array[int] = [
		_bus.player.life_lost.connect(_on_life_lost),
		_bus.player.player_destroyed.connect(_on_destroyed),
		_bus.player.bonus_life_awarded.connect(_on_bonus),
		_bus.player.armor_changed.connect(_on_armor),
	]
	var _ok: GdUnitAssert = assert_int(subscribed.count(OK)).is_equal(subscribed.size())
	_ledger.start_run()
	_armor_deltas.clear()
	_enter(GameState.Phase.SKIRMISH)


func after_test() -> void:
	_bus.free()


func _on_life_lost(lives_left: int) -> void:
	_lives_lost.append(lives_left)


func _on_destroyed(_position: Vector3, cause: DestroyCause.Cause) -> void:
	_destroyed.append(cause)


func _on_bonus(lives: int) -> void:
	_bonus_lives.append(lives)


func _on_armor(_armor: int, _max_armor: int, delta: int) -> void:
	_armor_deltas.append(delta)


func _enter(phase: GameState.Phase) -> void:
	_bus.flow.announce_game_state_changed(phase, phase)


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > 1e-6:
		_ledger.tick(minf(STEP, left))
		left -= STEP


## Reports a kill and returns the points it scored.
func _kill(kind: EnemyKind.Kind, cause: DestroyCause.Cause = DestroyCause.Cause.SHOT) -> int:
	var prior: int = _ledger.score()
	_bus.enemy.announce_enemy_destroyed(_next_id, kind, Vector3.ZERO, cause)
	_next_id += 1
	return _ledger.score() - prior


func _hit(source: DamageSource.Source, attack_damage: int = 0) -> int:
	var prior: int = _ledger.armor()
	_bus.player.announce_player_hit(source, Vector3.ZERO, attack_damage)
	return prior - _ledger.armor()


func test_ledger_shot_kill_scores_100() -> void:
	var points: int = _kill(EnemyKind.Kind.FIGHTER)
	var _scored: GdUnitAssert = assert_int(points).is_equal(100)
	var _total: GdUnitAssert = assert_int(_ledger.score()).is_equal(100)


func test_ledger_collision_kill_scores_zero() -> void:
	var points: int = _kill(EnemyKind.Kind.ENEMY_MECH, DestroyCause.Cause.COLLISION)
	var _nothing: GdUnitAssert = assert_int(points).is_equal(0)
	var _no_combo: GdUnitAssert = assert_int(_ledger.multiplier()).is_equal(1)


func test_ledger_scores_every_enemy_kind_per_table() -> void:
	var expected: Dictionary[EnemyKind.Kind, int] = {
		EnemyKind.Kind.FIGHTER: 100,
		EnemyKind.Kind.HEAVY: 300,
		EnemyKind.Kind.INTERCEPTOR: 200,
		EnemyKind.Kind.DRONE: 150,
		EnemyKind.Kind.BOMBER: 400,
		EnemyKind.Kind.ENEMY_MECH: 500,
	}
	var scored: Dictionary[EnemyKind.Kind, int] = {}
	for kind: EnemyKind.Kind in EnemyKind.Kind.values():
		scored[kind] = _kill(kind)
		_advance(RunRules.COMBO_WINDOW + STEP)
	var _table: GdUnitAssert = assert_dict(scored).is_equal(expected)


func test_ledger_scores_nothing_outside_timed_play() -> void:
	_enter(GameState.Phase.LEVEL_INTRO)
	var in_intro: int = _kill(EnemyKind.Kind.FIGHTER)
	_enter(GameState.Phase.TITLE)
	var in_title: int = _kill(EnemyKind.Kind.FIGHTER)
	var _intro: GdUnitAssert = assert_int(in_intro).is_equal(0)
	var _attract: GdUnitAssert = assert_int(in_title).is_equal(0)


func test_ledger_combo_multiplies_kills_within_window() -> void:
	var points: Array[int] = []
	for i: int in 3:
		points.append(_kill(EnemyKind.Kind.FIGHTER))
		_advance(RunRules.COMBO_WINDOW - 0.2)
	var _rising: GdUnitAssert = assert_array(points).is_equal([100, 200, 300])
	var _multiplier: GdUnitAssert = assert_int(_ledger.multiplier()).is_equal(3)


func test_ledger_combo_caps_at_8() -> void:
	var last: int = 0
	for i: int in 12:
		last = _kill(EnemyKind.Kind.FIGHTER)
	var _capped: GdUnitAssert = assert_int(_ledger.multiplier()).is_equal(8)
	var _points: GdUnitAssert = assert_int(last).is_equal(800)


func test_ledger_combo_resets_after_window() -> void:
	var _first: int = _kill(EnemyKind.Kind.FIGHTER)
	var _second: int = _kill(EnemyKind.Kind.FIGHTER)
	_advance(RunRules.COMBO_WINDOW + STEP)
	var reset_to: int = _ledger.multiplier()
	var later: int = _kill(EnemyKind.Kind.FIGHTER)
	var _reset: GdUnitAssert = assert_int(reset_to).is_equal(1)
	var _base_again: GdUnitAssert = assert_int(later).is_equal(100)


func test_ledger_combo_resets_on_damage() -> void:
	var _first: int = _kill(EnemyKind.Kind.FIGHTER)
	var _second: int = _kill(EnemyKind.Kind.FIGHTER)
	var _damage: int = _hit(DamageSource.Source.ENEMY_BULLET)
	var later: int = _kill(EnemyKind.Kind.FIGHTER)
	var _base_again: GdUnitAssert = assert_int(later).is_equal(100)


func test_ledger_damage_by_source() -> void:
	var damage: Array[int] = []
	var hits: Array[Array] = [
		[DamageSource.Source.ENEMY_COLLISION, 0],
		[DamageSource.Source.ENEMY_BULLET, 0],
		[DamageSource.Source.BOMB, 0],
		[DamageSource.Source.MISSILE, 0],
		[DamageSource.Source.BOSS_ATTACK, 30],
		[DamageSource.Source.BOSS_ATTACK, 90],
		[DamageSource.Source.BOSS_ATTACK, 1],
	]
	for hit: Array in hits:
		_ledger.start_run()
		_advance(RunRules.HIT_INVULNERABILITY + STEP)
		var source: DamageSource.Source = hit[0]
		var attack: int = hit[1]
		damage.append(_hit(source, attack))
	var _table: GdUnitAssert = assert_array(damage).is_equal([25, 10, 20, 20, 30, 35, 15])


func test_ledger_hit_grants_invulnerability_window() -> void:
	var first: int = _hit(DamageSource.Source.ENEMY_BULLET)
	_advance(RunRules.HIT_INVULNERABILITY - 0.1)
	var during: int = _hit(DamageSource.Source.ENEMY_BULLET)
	_advance(0.1 + STEP)
	var later: int = _hit(DamageSource.Source.ENEMY_BULLET)
	var _hurt: GdUnitAssert = assert_array([first, during, later]).is_equal([10, 0, 10])


func test_ledger_armor_zero_loses_a_life() -> void:
	for i: int in 4:
		var _damage: int = _hit(DamageSource.Source.ENEMY_COLLISION)
		_advance(RunRules.HIT_INVULNERABILITY + STEP)
	var after_death: int = _hit(DamageSource.Source.ENEMY_BULLET)
	var _armor: GdUnitAssert = assert_int(_ledger.armor()).is_equal(0)
	var _down: GdUnitAssert = assert_bool(_ledger.is_down()).is_true()
	var _lost: GdUnitAssert = assert_array(_lives_lost).is_equal([RunRules.START_LIVES - 1])
	var _cause: GdUnitAssert = assert_array(_destroyed).is_equal([DestroyCause.Cause.COLLISION])
	var _no_hits_while_down: GdUnitAssert = assert_int(after_death).is_equal(0)


func test_ledger_respawn_restores_armor_with_two_second_invulnerability() -> void:
	for i: int in 10:
		var _damage: int = _hit(DamageSource.Source.ENEMY_BULLET)
		_advance(RunRules.HIT_INVULNERABILITY + STEP)
	_ledger.respawn()
	var armor: int = _ledger.armor()
	_advance(RunRules.RESPAWN_INVULNERABILITY - 0.1)
	var during: int = _hit(DamageSource.Source.ENEMY_BULLET)
	_advance(0.1 + STEP)
	var later: int = _hit(DamageSource.Source.ENEMY_BULLET)
	var _full: GdUnitAssert = assert_int(armor).is_equal(RunRules.MAX_ARMOR)
	var _shielded: GdUnitAssert = assert_int(during).is_equal(0)
	var _hurt_again: GdUnitAssert = assert_int(later).is_equal(10)
	var _cause: GdUnitAssert = assert_array(_destroyed).is_equal([DestroyCause.Cause.SHOT])


func test_ledger_awards_one_bonus_life_at_100000() -> void:
	var lives_before: int = _ledger.lives()
	var below: int = 0
	while _ledger.score() + RunRules.BOSS_POINTS_PER_LEVEL < RunRules.BONUS_LIFE_SCORE:
		_ledger.award_boss()
	below = _bonus_lives.size()
	for i: int in 30:
		_ledger.award_boss()
	var _not_early: GdUnitAssert = assert_int(below).is_equal(0)
	var _once: GdUnitAssert = assert_array(_bonus_lives).is_equal([lives_before + 1])
	var _past_200k: GdUnitAssert = assert_int(_ledger.score()).is_greater(
		2 * RunRules.BONUS_LIFE_SCORE
	)
	var _lives: GdUnitAssert = assert_int(_ledger.lives()).is_equal(lives_before + 1)


func test_ledger_repair_kit_restores_30_armor_capped() -> void:
	for i: int in 5:
		var _damage: int = _hit(DamageSource.Source.ENEMY_BULLET)
		_advance(RunRules.HIT_INVULNERABILITY + STEP)
	_bus.player.announce_repair_collected(Vector3.ZERO)
	var repaired: int = _ledger.armor()
	_bus.player.announce_repair_collected(Vector3.ZERO)
	var _plus_30: GdUnitAssert = assert_int(repaired).is_equal(80)
	var _capped: GdUnitAssert = assert_int(_ledger.armor()).is_equal(RunRules.MAX_ARMOR)


func test_ledger_boss_score_is_5000_times_level() -> void:
	var scores: Array[int] = []
	for level: int in range(1, RunRules.LEVEL_COUNT + 1):
		_ledger.start_run()
		_ledger.start_level(level)
		_ledger.award_boss()
		scores.append(_ledger.score())
	var _table: GdUnitAssert = assert_array(scores).is_equal(
		[5000, 10000, 15000, 20000, 25000, 30000]
	)


func test_ledger_level_clear_bonus_armor_and_no_death() -> void:
	_ledger.start_level(3)
	var _damage: int = _hit(DamageSource.Source.ENEMY_COLLISION)
	_bus.player.announce_player_fired(Vector3.ZERO, Vector3.RIGHT)
	_bus.player.announce_player_fired(Vector3.ZERO, Vector3.RIGHT)
	_bus.enemy.announce_enemy_hit(1, Vector3.ZERO)
	var _points: int = _kill(EnemyKind.Kind.FIGHTER)
	var prior: int = _ledger.score()
	var tally: LevelTally = _ledger.close_level()
	var _armor: GdUnitAssert = assert_int(tally.armor_bonus).is_equal(75 * 50)
	var _no_death: GdUnitAssert = assert_int(tally.no_death_bonus).is_equal(10000)
	var _added: GdUnitAssert = assert_int(_ledger.score() - prior).is_equal(75 * 50 + 10000)
	var _accuracy: GdUnitAssert = assert_float(tally.accuracy()).is_equal_approx(0.5, 1e-6)
	var _kills: GdUnitAssert = assert_int(tally.kills).is_equal(1)
	var _level: GdUnitAssert = assert_int(tally.level_number).is_equal(3)


func test_ledger_level_clear_bonus_without_no_death_after_life_lost() -> void:
	for i: int in 4:
		var _damage: int = _hit(DamageSource.Source.ENEMY_COLLISION)
		_advance(RunRules.HIT_INVULNERABILITY + STEP)
	_ledger.respawn()
	var tally: LevelTally = _ledger.close_level()
	var _armor: GdUnitAssert = assert_int(tally.armor_bonus).is_equal(RunRules.MAX_ARMOR * 50)
	var _no_bonus: GdUnitAssert = assert_int(tally.no_death_bonus).is_equal(0)


func test_ledger_time_excludes_intro() -> void:
	_enter(GameState.Phase.LEVEL_INTRO)
	_advance(2.5)
	_enter(GameState.Phase.SKIRMISH)
	_advance(60.0)
	_enter(GameState.Phase.PAUSED)
	_advance(30.0)
	_enter(GameState.Phase.BOSS_FIGHT)
	_advance(5.5)
	var summary: RunSummary = _ledger.summary(false)
	var _seconds: GdUnitAssert = assert_float(summary.time_seconds).is_equal_approx(65.5, 0.05)
	var _format: GdUnitAssert = assert_str(summary.formatted_time()).is_equal("01:05")
	var _long: GdUnitAssert = assert_str(RunSummary.format_mm_ss(3599.9)).is_equal("59:59")
