extends GdUnitTestSuite
## Level progression (#73): Level Intro, Skirmish, the Boss Gauge, Boss Warning,
## Boss Fight, Level Clear, the next Level, Victory and Game Over.

var _h: RunHarness


func before_test() -> void:
	_h = RunHarness.new()


func after_test() -> void:
	_h.dispose()


func test_progression_runs_level_intro_then_skirmish() -> void:
	_h.start_run()
	var intro: GameState.Phase = _h.machine.state()
	_h.advance(_h.levels[0].intro_duration - 0.1)
	var still_intro: GameState.Phase = _h.machine.state()
	_h.advance(0.1 + RunHarness.STEP)
	var _intro: GdUnitAssert = assert_int(intro).is_equal(GameState.Phase.LEVEL_INTRO)
	var _duration: GdUnitAssert = assert_float(_h.levels[0].intro_duration).is_equal(2.5)
	var _holds: GdUnitAssert = assert_int(still_intro).is_equal(GameState.Phase.LEVEL_INTRO)
	var _skirmish: GdUnitAssert = assert_int(_h.machine.state()).is_equal(GameState.Phase.SKIRMISH)


func test_boss_gauge_fills_from_level_points_and_summons_boss() -> void:
	_h.reach_skirmish()
	var threshold: int = _h.levels[0].boss.threshold
	var kills_needed: int = ceili(float(threshold) / RunRules.KILL_POINTS[EnemyKind.Kind.FIGHTER])
	for i: int in kills_needed - 1:
		var _points: int = _h.kill(EnemyKind.Kind.FIGHTER)
		_h.advance(RunRules.COMBO_WINDOW + RunHarness.STEP)
	var before_threshold: GameState.Phase = _h.machine.state()
	var gauge: int = _h.progression.gauge()
	var _last: int = _h.kill(EnemyKind.Kind.FIGHTER)
	var warning: GameState.Phase = _h.machine.state()
	_h.advance(RunRules.BOSS_WARNING_DURATION - 0.1)
	var still_warning: GameState.Phase = _h.machine.state()
	_h.advance(0.1 + RunHarness.STEP)
	var _skirmish: GdUnitAssert = assert_int(before_threshold).is_equal(GameState.Phase.SKIRMISH)
	var _gauge: GdUnitAssert = assert_int(gauge).is_equal(threshold - 100)
	var _warning: GdUnitAssert = assert_int(warning).is_equal(GameState.Phase.BOSS_WARNING)
	var _three_seconds: GdUnitAssert = assert_int(still_warning).is_equal(
		GameState.Phase.BOSS_WARNING
	)
	var _fight: GdUnitAssert = assert_int(_h.machine.state()).is_equal(GameState.Phase.BOSS_FIGHT)
	var _summoned: GdUnitAssert = assert_array(_h.summoned).is_equal([&"albatross"])
	var _armed: GdUnitAssert = assert_int(_h.boss_health.health()).is_equal(
		_h.levels[0].boss.health
	)


func test_boss_gauge_counts_only_this_levels_skirmish_points() -> void:
	_h.reach_skirmish()
	_h.ledger.award_boss()
	var after_bonus: int = _h.progression.gauge()
	var _points: int = _h.kill(EnemyKind.Kind.HEAVY)
	var _no_bonus_points: GdUnitAssert = assert_int(after_bonus).is_equal(0)
	var _kill_points: GdUnitAssert = assert_int(_h.progression.gauge()).is_equal(300)


func test_life_lost_respawns_after_delay() -> void:
	_h.reach_skirmish()
	_h.lose_life()
	var down: bool = _h.ledger.is_down()
	_h.advance(RunRules.RESPAWN_DELAY + RunHarness.STEP)
	var _down: GdUnitAssert = assert_bool(down).is_true()
	var _respawned: GdUnitAssert = assert_int(_h.respawns).is_equal(1)
	var _up: GdUnitAssert = assert_bool(_h.ledger.is_down()).is_false()
	var _armor: GdUnitAssert = assert_int(_h.ledger.armor()).is_equal(RunRules.MAX_ARMOR)
	var _lives: GdUnitAssert = assert_int(_h.ledger.lives()).is_equal(RunRules.START_LIVES - 1)


func test_life_lost_keeps_gauge_and_boss_health() -> void:
	_h.reach_skirmish()
	for i: int in 5:
		var _points: int = _h.kill(EnemyKind.Kind.FIGHTER)
		_h.advance(RunRules.COMBO_WINDOW + RunHarness.STEP)
	var gauge: int = _h.progression.gauge()
	_h.lose_life()
	_h.advance(RunRules.RESPAWN_DELAY + RunHarness.STEP)
	var gauge_after_death: int = _h.progression.gauge()
	_h.reach_boss_fight()
	_h.bus.boss.announce_boss_hit(40, Vector3.ZERO)
	var boss_health: int = _h.boss_health.health()
	_h.lose_life()
	_h.advance(RunRules.RESPAWN_DELAY + RunHarness.STEP)
	var _gauge_kept: GdUnitAssert = assert_int(gauge_after_death).is_equal(gauge)
	var _boss_kept: GdUnitAssert = assert_int(_h.boss_health.health()).is_equal(boss_health)
	var _still_fighting: GdUnitAssert = assert_int(_h.machine.state()).is_equal(
		GameState.Phase.BOSS_FIGHT
	)
	var _summoned_once: GdUnitAssert = assert_array(_h.summoned).has_size(1)
	var _respawned_twice: GdUnitAssert = assert_int(_h.respawns).is_equal(2)


func test_last_life_lost_ends_in_game_over_after_delay() -> void:
	_h.reach_skirmish()
	var _points: int = _h.kill(EnemyKind.Kind.FIGHTER)
	for i: int in RunRules.START_LIVES - 1:
		_h.lose_life()
		_h.advance(RunRules.RESPAWN_DELAY + RunHarness.STEP)
	_h.lose_life()
	var pending: GameState.Phase = _h.machine.state()
	_h.advance(_h.levels[0].game_over_delay)
	var _waits: GdUnitAssert = assert_int(pending).is_equal(GameState.Phase.SKIRMISH)
	var _over: GdUnitAssert = assert_int(_h.machine.state()).is_equal(GameState.Phase.GAME_OVER)
	var _one_summary: GdUnitAssert = assert_array(_h.run_summaries).has_size(1)
	var summary: RunSummary = _h.run_summaries[0]
	var _score: GdUnitAssert = assert_int(summary.score).is_equal(100)
	var _not_won: GdUnitAssert = assert_bool(summary.victory).is_false()
	var _level: GdUnitAssert = assert_int(summary.level_reached).is_equal(1)


func test_boss_defeat_clears_level_and_continue_starts_next() -> void:
	_h.reach_skirmish()
	_h.reach_boss_fight()
	var prior: int = _h.ledger.score()
	_h.defeat_boss()
	var cleared: GameState.Phase = _h.machine.state()
	var gained: int = _h.ledger.score() - prior
	_h.bus.flow.announce_continue_requested()
	var _clear: GdUnitAssert = assert_int(cleared).is_equal(GameState.Phase.LEVEL_CLEAR)
	var _tally: GdUnitAssert = assert_array(_h.tallies).has_size(1)
	var _boss_and_bonus: GdUnitAssert = assert_int(gained).is_equal(
		5000 + RunRules.MAX_ARMOR * 50 + 10000
	)
	var _next_intro: GdUnitAssert = assert_int(_h.machine.state()).is_equal(
		GameState.Phase.LEVEL_INTRO
	)
	var _level_two: GdUnitAssert = assert_int(_h.progression.level_number()).is_equal(2)
	var _gauge_reset: GdUnitAssert = assert_int(_h.progression.gauge()).is_equal(0)


func test_level_6_boss_defeat_is_victory() -> void:
	_h.start_run()
	var cleared_levels: int = 0
	for level: int in RunRules.LEVEL_COUNT:
		_h.advance(_h.levels[level].intro_duration + RunHarness.STEP)
		_h.reach_boss_fight()
		_h.defeat_boss()
		if _h.machine.state() == GameState.Phase.LEVEL_CLEAR:
			cleared_levels += 1
			_h.bus.flow.announce_continue_requested()
	var _five_clears: GdUnitAssert = assert_int(cleared_levels).is_equal(RunRules.LEVEL_COUNT - 1)
	var _victory: GdUnitAssert = assert_int(_h.machine.state()).is_equal(GameState.Phase.VICTORY)
	var _six_tallies: GdUnitAssert = assert_array(_h.tallies).has_size(RunRules.LEVEL_COUNT)
	var _one_summary: GdUnitAssert = assert_array(_h.run_summaries).has_size(1)
	var summary: RunSummary = _h.run_summaries[0]
	var _won: GdUnitAssert = assert_bool(summary.victory).is_true()
	var _reached: GdUnitAssert = assert_int(summary.level_reached).is_equal(RunRules.LEVEL_COUNT)
	var _bosses: GdUnitAssert = assert_array(_h.summoned).is_equal(
		[&"albatross", &"thunderhead", &"hornet", &"leviathan", &"crimson_lancer", &"ascendant"]
	)


func test_quit_to_title_abandons_run() -> void:
	_h.reach_skirmish()
	_h.bus.flow.announce_pause_requested()
	_h.advance(10.0)
	var paused: GameState.Phase = _h.machine.state()
	_h.bus.flow.announce_quit_to_title_requested()
	_h.advance(10.0)
	var _paused: GdUnitAssert = assert_int(paused).is_equal(GameState.Phase.PAUSED)
	var _title: GdUnitAssert = assert_int(_h.machine.state()).is_equal(GameState.Phase.TITLE)
	var _abandoned: GdUnitAssert = assert_bool(_h.progression.is_run_active()).is_false()
	var _no_summary: GdUnitAssert = assert_array(_h.run_summaries).is_empty()


func test_pause_freezes_level_timers() -> void:
	_h.start_run()
	_h.bus.flow.announce_pause_requested()
	_h.advance(_h.levels[0].intro_duration * 4)
	_h.bus.flow.announce_resume_requested()
	var resumed: GameState.Phase = _h.machine.state()
	_h.advance(_h.levels[0].intro_duration + RunHarness.STEP)
	var _still_intro: GdUnitAssert = assert_int(resumed).is_equal(GameState.Phase.LEVEL_INTRO)
	var _then_skirmish: GdUnitAssert = assert_int(_h.machine.state()).is_equal(
		GameState.Phase.SKIRMISH
	)
