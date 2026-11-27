extends GdUnitTestSuite
## Enemy edge rules (#23, #73): a Bomber releases only when its bombs would land
## on the player, and a crash after the player died in the same tick spares the
## enemy.

const STEP: float = FieldHarness.STEP

var _h: FieldHarness


func before_test() -> void:
	_h = FieldHarness.new()
	add_child(_h.field)
	_h.enter_level(1)


func after_test() -> void:
	_h.dispose()


func _watch(enemy: Enemy, record: FireLog) -> void:
	var errs: Array[int] = [
		enemy.telegraphed.connect(record.on_telegraphed),
		enemy.fired.connect(record.on_fired),
	]
	var _ok: GdUnitAssert = assert_int(errs.count(OK)).is_equal(errs.size())


func _advance_logged(seconds: float, record: FireLog) -> void:
	var left: float = seconds
	while left > 1e-6:
		record.clock += STEP
		_h.field.step(STEP)
		left -= STEP


func test_bomber_releases_only_when_bombs_land_on_the_player() -> void:
	var enemy: Enemy = _h.order(EnemyKind.Kind.BOMBER, PI, 20.0, 1.0)
	var profile: EnemyProfile = EnemyProfile.of(EnemyKind.Kind.BOMBER)
	var record: FireLog = FireLog.new()
	_watch(enemy, record)
	# Each bomb in flight, and whether it reached the player's height or hit.
	var settled: Dictionary[EnemyShot, bool] = {}
	var landings: Array[float] = []
	var guard: int = 0
	while enemy.position.x < 20.0 and guard < 1500:
		_advance_logged(STEP, record)
		guard += 1
		for bomb: EnemyShot in _h.field.shots().live_shots():
			if bomb.life_left >= bomb.spec.life - STEP * 1.5:
				settled[bomb] = false
			if not settled.get_or_add(bomb, false) and bomb.position.y <= _h.target.at.y:
				settled[bomb] = true
				landings.append(bomb.position.x)
	var reach: float = profile.bomb_window + profile.shot.radius + _h.target.radius()
	var _bombed: GdUnitAssert = assert_int(record.shots.size()).is_greater(0)
	# Every bomb either struck the player or landed within the release window.
	var _all_accounted: GdUnitAssert = assert_int(landings.size() + _h.player_hits.size()).is_equal(
		record.shots.size()
	)
	for x: float in landings:
		var _on_target: GdUnitAssert = assert_float(absf(x - _h.target.at.x)).is_less_equal(reach)


func test_crash_after_player_destroyed_in_same_tick_spares_enemy() -> void:
	_h.target.fatal = true
	var first: Enemy = _h.order(EnemyKind.Kind.FIGHTER, 0.0, 1.0)
	var second: Enemy = _h.order(EnemyKind.Kind.FIGHTER, PI, 1.0)
	_h.field.step(STEP)
	var crashed: int = 0
	for enemy: Enemy in [first, second]:
		if not enemy.is_active():
			crashed += 1
	var _one_crash: GdUnitAssert = assert_int(crashed).is_equal(1)
	var _one_hit: GdUnitAssert = assert_array(_h.player_hits).is_equal(
		[DamageSource.Source.ENEMY_COLLISION]
	)
	var _player_down: GdUnitAssert = assert_bool(_h.target.is_alive()).is_false()
	var _one_destroyed: GdUnitAssert = assert_int(_h.destroyed.size()).is_equal(1)
