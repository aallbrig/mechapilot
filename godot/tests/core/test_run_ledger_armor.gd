extends GdUnitTestSuite
## The Run ledger (#73), part 2: Armor and damage by source, invulnerability,
## lives and respawns, the one-time bonus life, Repair Kits and the no-death bonus.

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
	_advance(0.55)
	var during: int = _hit(DamageSource.Source.ENEMY_BULLET)
	_advance(0.1)
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
	_advance(1.95)
	var during: int = _hit(DamageSource.Source.ENEMY_BULLET)
	_advance(0.1)
	var later: int = _hit(DamageSource.Source.ENEMY_BULLET)
	var _full: GdUnitAssert = assert_int(armor).is_equal(100)
	var _shielded: GdUnitAssert = assert_int(during).is_equal(0)
	var _hurt_again: GdUnitAssert = assert_int(later).is_equal(10)
	var _cause: GdUnitAssert = assert_array(_destroyed).is_equal([DestroyCause.Cause.SHOT])


func test_ledger_awards_one_bonus_life_at_100000() -> void:
	var lives_before: int = _ledger.lives()
	for i: int in 19:
		_ledger.award_boss()
	for i: int in 49:
		var _points: int = _kill(EnemyKind.Kind.FIGHTER)
		_advance(1.25)
	var at_99900: int = _ledger.score()
	var none_below: int = _bonus_lives.size()
	var _last: int = _kill(EnemyKind.Kind.FIGHTER)
	var at_threshold: int = _ledger.score()
	var at_100000: Array[int] = _bonus_lives.duplicate()
	for i: int in 30:
		_ledger.award_boss()
	var _below: GdUnitAssert = assert_int(at_99900).is_equal(99900)
	var _none_below: GdUnitAssert = assert_int(none_below).is_equal(0)
	var _exact: GdUnitAssert = assert_int(at_threshold).is_equal(100000)
	var _awarded_at_exactly: GdUnitAssert = assert_array(at_100000).is_equal([lives_before + 1])
	var _once: GdUnitAssert = assert_array(_bonus_lives).is_equal([lives_before + 1])
	var _past_200k: GdUnitAssert = assert_int(_ledger.score()).is_greater(200000)
	var _threshold: GdUnitAssert = assert_int(RunRules.BONUS_LIFE_SCORE).is_equal(100000)


func test_ledger_repair_kit_restores_30_armor_capped() -> void:
	for i: int in 5:
		var _damage: int = _hit(DamageSource.Source.ENEMY_BULLET)
		_advance(RunRules.HIT_INVULNERABILITY + STEP)
	_bus.player.announce_repair_collected(Vector3.ZERO)
	var repaired: int = _ledger.armor()
	_bus.player.announce_repair_collected(Vector3.ZERO)
	var _plus_30: GdUnitAssert = assert_int(repaired).is_equal(80)
	var _capped: GdUnitAssert = assert_int(_ledger.armor()).is_equal(RunRules.MAX_ARMOR)


func test_ledger_level_clear_bonus_without_no_death_after_life_lost() -> void:
	for i: int in 4:
		var _damage: int = _hit(DamageSource.Source.ENEMY_COLLISION)
		_advance(RunRules.HIT_INVULNERABILITY + STEP)
	_ledger.respawn()
	var tally: LevelTally = _ledger.close_level()
	var _armor: GdUnitAssert = assert_int(tally.armor_bonus).is_equal(RunRules.MAX_ARMOR * 50)
	var _no_bonus: GdUnitAssert = assert_int(tally.no_death_bonus).is_equal(0)


func test_ledger_no_death_flag_resets_each_level() -> void:
	_ledger.start_level(1)
	for i: int in 4:
		var _damage: int = _hit(DamageSource.Source.ENEMY_COLLISION)
		_advance(0.65)
	_ledger.respawn()
	var level_1: LevelTally = _ledger.close_level()
	_ledger.start_level(2)
	var level_2: LevelTally = _ledger.close_level()
	var _lost_in_1: GdUnitAssert = assert_int(level_1.no_death_bonus).is_equal(0)
	var _clean_2: GdUnitAssert = assert_int(level_2.no_death_bonus).is_equal(10000)
