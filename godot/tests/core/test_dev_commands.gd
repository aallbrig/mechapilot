extends GdUnitTestSuite
## Developer commands (#116): each one acts through the same rule APIs as
## gameplay (RunLedger, LevelProgression, the enemy field's own destroy path),
## only while Developer mode is on, and marks the Run dev-assisted, which keeps
## it off the Scoreboard.

var _run: RunHarness
var _dev: DevCommands
var _statuses: Array[Array] = []
var _scores: Array[int] = []
var _qualified: Array[int] = []


func before_test() -> void:
	_run = RunHarness.new()
	_dev = DevCommands.new(_run.bus, _run.machine, _run.ledger, _run.progression)
	_statuses.clear()
	_scores.clear()
	_qualified.clear()
	var subscribed: Array[int] = [
		_run.bus.dev.dev_status_changed.connect(_on_status),
		_run.bus.run.score_changed.connect(_on_score),
	]
	var _ok: GdUnitAssert = assert_int(subscribed.count(OK)).is_equal(subscribed.size())


func after_test() -> void:
	_run.dispose()


func _on_status(invulnerable: bool, dev_assisted: bool) -> void:
	_statuses.append([invulnerable, dev_assisted])


func _on_qualified(rank: int) -> void:
	_qualified.append(rank)


func _on_score(total: int, _delta: int) -> void:
	_scores.append(total)


func _developer_mode(on: bool) -> void:
	var settings: GameSettings = GameSettings.new()
	settings.developer_mode = on
	_run.bus.profile.announce_settings_changed(settings)


func _command(command: DevCommand.Command) -> void:
	_run.bus.dev.announce_dev_command_requested(command)


func test_dev_commands_act_through_rules_and_mark_run() -> void:
	var target: StandInTarget = StandInTarget.new(_run.bus)
	var field: EnemyField = EnemyField.new()
	add_child(field)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	field.setup(_run.bus, rng, _run.levels, target)
	_run.reach_skirmish()
	# Off: every command is ignored, and the Run stays clean.
	_command(DevCommand.Command.ADD_SCORE)
	_command(DevCommand.Command.ADD_LIFE)
	var off_score: int = _run.ledger.score()
	var off_lives: int = _run.ledger.lives()
	var off_assisted: bool = _run.ledger.summary(false).dev_assisted
	_developer_mode(true)
	_command(DevCommand.Command.ADD_SCORE)
	var score_after: int = _run.ledger.score()
	var assisted: bool = _run.ledger.summary(false).dev_assisted
	_command(DevCommand.Command.ADD_LIFE)
	var lives_after: int = _run.ledger.lives()
	_run.bus.player.announce_player_hit(DamageSource.Source.ENEMY_COLLISION, Vector3.ZERO, 0)
	var hurt: int = _run.ledger.armor()
	_run.advance(RunRules.HIT_INVULNERABILITY + RunHarness.STEP)
	_command(DevCommand.Command.RESTORE_ARMOR)
	var restored: int = _run.ledger.armor()
	_command(DevCommand.Command.TOGGLE_INVULNERABILITY)
	_run.bus.player.announce_player_hit(DamageSource.Source.ENEMY_COLLISION, Vector3.ZERO, 0)
	var shielded: int = _run.ledger.armor()
	_command(DevCommand.Command.TOGGLE_INVULNERABILITY)
	_run.bus.player.announce_player_hit(DamageSource.Source.ENEMY_COLLISION, Vector3.ZERO, 0)
	var unshielded: int = _run.ledger.armor()
	# Kill all enemies: the field destroys them as shot kills, and the ledger scores them.
	var placed: Array[Enemy] = [
		field.launch(EnemyKind.Kind.FIGHTER, Vector3(30.0, 0.0, 0.0), Vector3.LEFT, 0.0),
		field.launch(EnemyKind.Kind.HEAVY, Vector3(-30.0, 0.0, 0.0), Vector3.RIGHT, 0.0),
	]
	var before_purge: int = _run.ledger.score()
	_command(DevCommand.Command.KILL_ALL_ENEMIES)
	var left_in_play: int = field.active_enemies().size()
	var purge_points: int = _run.ledger.score() - before_purge
	field.free()
	# Fill the boss gauge: the Boss Warning starts, then the boss is summoned.
	_command(DevCommand.Command.FILL_BOSS_GAUGE)
	var warned: GameState.Phase = _run.machine.state()
	_run.advance(RunRules.BOSS_WARNING_DURATION + RunHarness.STEP)
	var summoned: Array[StringName] = _run.summoned.duplicate()
	# Skip to the next Level: the Level closes, then Continue enters Level 2.
	_command(DevCommand.Command.SKIP_LEVEL)
	var cleared: GameState.Phase = _run.machine.state()
	_run.bus.flow.announce_continue_requested()
	var next_level: int = _run.progression.level_number()
	var _off: GdUnitAssert = assert_array([off_score, off_lives, off_assisted]).is_equal(
		[0, RunRules.START_LIVES, false]
	)
	var _score: GdUnitAssert = assert_int(score_after).is_equal(DevCommands.SCORE_BONUS)
	var _marked: GdUnitAssert = assert_bool(assisted).is_true()
	var _life: GdUnitAssert = assert_int(lives_after).is_equal(RunRules.START_LIVES + 1)
	var _hurt: GdUnitAssert = assert_int(hurt).is_equal(
		RunRules.MAX_ARMOR - RunRules.COLLISION_DAMAGE
	)
	var _repaired: GdUnitAssert = assert_int(restored).is_equal(RunRules.MAX_ARMOR)
	var _shield: GdUnitAssert = assert_int(shielded).is_equal(RunRules.MAX_ARMOR)
	var _unshield: GdUnitAssert = assert_int(unshielded).is_equal(
		RunRules.MAX_ARMOR - RunRules.COLLISION_DAMAGE
	)
	var _purged: GdUnitAssert = assert_int(left_in_play).is_equal(0)
	var _purge_scored: GdUnitAssert = assert_int(purge_points).is_greater_equal(
		RunRules.kill_points(EnemyKind.Kind.FIGHTER) + RunRules.kill_points(EnemyKind.Kind.HEAVY)
	)
	var _placed: GdUnitAssert = assert_int(placed.size()).is_equal(2)
	var _warning: GdUnitAssert = assert_int(warned).is_equal(GameState.Phase.BOSS_WARNING)
	var _boss: GdUnitAssert = assert_array(summoned).is_equal([_run.levels[0].boss.id])
	var _clear: GdUnitAssert = assert_int(cleared).is_equal(GameState.Phase.LEVEL_CLEAR)
	var _level_two: GdUnitAssert = assert_int(next_level).is_equal(2)
	var _status: GdUnitAssert = assert_array(_statuses.back()).is_equal([false, true])
	var _announced_score: GdUnitAssert = assert_bool(_scores.has(DevCommands.SCORE_BONUS)).is_true()


func test_dev_commands_skip_from_level_intro_to_victory_on_the_last_level() -> void:
	_developer_mode(true)
	_run.start_run()
	var skipped: Array[GameState.Phase] = []
	for level: int in _run.levels.size():
		_command(DevCommand.Command.SKIP_LEVEL)
		skipped.append(_run.machine.state())
		_run.bus.flow.announce_continue_requested()
	var expected: Array[GameState.Phase] = []
	for level: int in _run.levels.size() - 1:
		expected.append(GameState.Phase.LEVEL_CLEAR)
	expected.append(GameState.Phase.VICTORY)
	var _walked: GdUnitAssert = assert_array(skipped).is_equal(expected)
	var _assisted: GdUnitAssert = assert_bool(_run.run_summaries.back().dev_assisted).is_true()


func test_dev_commands_change_nothing_outside_a_run() -> void:
	_developer_mode(true)
	_run.machine.boot()
	_run.bus.flow.announce_start_requested()
	# Invulnerability is the one command allowed outside a Run (it marks the next Run).
	for command: DevCommand.Command in DevCommand.Command.values():
		if command != DevCommand.Command.TOGGLE_INVULNERABILITY:
			_command(command)
	var _title: GdUnitAssert = assert_int(_run.machine.state()).is_equal(GameState.Phase.TITLE)
	var _no_score: GdUnitAssert = assert_array(_scores).is_empty()
	var _clean: GdUnitAssert = assert_bool(_run.ledger.is_dev_assisted()).is_false()
	var _silent: GdUnitAssert = assert_array(_statuses).is_empty()


func test_invulnerability_left_on_marks_the_next_run() -> void:
	_developer_mode(true)
	_run.machine.boot()
	_run.bus.flow.announce_start_requested()
	_command(DevCommand.Command.TOGGLE_INVULNERABILITY)
	_run.bus.flow.announce_play_requested()
	var _marked: GdUnitAssert = assert_bool(_run.ledger.is_dev_assisted()).is_true()
	var _status: GdUnitAssert = assert_array(_statuses.back()).is_equal([true, true])


func test_dev_assisted_run_not_saved_to_scoreboard() -> void:
	var store: MemoryDocumentStore = MemoryDocumentStore.new()
	var board: Scoreboard = Scoreboard.new(_run.bus, store)
	var ok: bool = _run.bus.profile.scoreboard_qualified.connect(_on_qualified) == OK
	_developer_mode(true)
	_run.reach_skirmish()
	var _points: int = _run.kill(EnemyKind.Kind.FIGHTER)
	_command(DevCommand.Command.ADD_SCORE)
	while _run.ledger.lives() > 0:
		_run.lose_life()
	_run.advance(_run.levels[0].game_over_delay + RunHarness.STEP)
	_run.bus.profile.announce_initials_submitted("DEV")
	var ended: RunSummary = _run.run_summaries.back()
	var _wired: GdUnitAssert = assert_bool(ok).is_true()
	var _over: GdUnitAssert = assert_int(_run.machine.state()).is_equal(GameState.Phase.GAME_OVER)
	var _scored: GdUnitAssert = assert_int(ended.score).is_greater(0)
	var _assisted: GdUnitAssert = assert_bool(ended.dev_assisted).is_true()
	var _not_asked: GdUnitAssert = assert_array(_qualified).is_empty()
	var _not_saved: GdUnitAssert = assert_array(board.entries()).is_empty()
	var _not_stored: GdUnitAssert = assert_bool(store.read_document().is_empty()).is_true()


func test_ledger_developer_rules_keep_the_run_rules() -> void:
	_run.reach_skirmish()
	var full_refused: bool = _run.ledger.restore_armor()
	_run.ledger.award_points(RunRules.BONUS_LIFE_SCORE)
	var lives_with_bonus: int = _run.ledger.lives()
	_run.lose_life()
	var down_refused: bool = _run.ledger.restore_armor()
	var down_armor: int = _run.ledger.armor()
	_run.ledger.award_points(0)
	var _full: GdUnitAssert = assert_bool(full_refused).is_false()
	var _bonus: GdUnitAssert = assert_int(lives_with_bonus).is_equal(RunRules.START_LIVES + 1)
	var _down: GdUnitAssert = assert_bool(down_refused).is_false()
	var _still_down: GdUnitAssert = assert_int(down_armor).is_equal(0)
	var _combo: GdUnitAssert = assert_int(_run.ledger.multiplier()).is_equal(1)
	var _gauge: GdUnitAssert = assert_int(_run.progression.gauge()).is_equal(0)
	var _marked: GdUnitAssert = assert_bool(_run.ledger.is_dev_assisted()).is_true()


## The same guarantees test_events.gd gives the other channels, for Events.dev.
func test_dev_channel_is_typed_announced_and_unique() -> void:
	var problems: Array[String] = []
	var dev: Script = EventBus.DevChannel
	var methods: Dictionary[String, int] = {}
	for method: Dictionary in dev.get_script_method_list():
		var method_args: Array = method["args"]
		var method_name: String = method["name"]
		methods[method_name] = method_args.size()
	var others: Array[String] = []
	var channels: Array[Script] = [
		EventBus.FlowChannel,
		EventBus.RunChannel,
		EventBus.PlayerChannel,
		EventBus.EnemyChannel,
		EventBus.BossChannel,
		EventBus.ProfileChannel,
	]
	for channel: Script in channels:
		for sig: Dictionary in channel.get_script_signal_list():
			var other_name: String = sig["name"]
			others.append(other_name)
	var signals: Array[Dictionary] = dev.get_script_signal_list()
	for sig: Dictionary in signals:
		var sig_name: String = sig["name"]
		var sig_args: Array = sig["args"]
		for arg: Dictionary in sig_args:
			var arg_type: int = arg["type"]
			if arg_type == TYPE_NIL:
				problems.append("untyped %s" % sig_name)
		var announcer: String = "announce_%s" % sig_name
		if not methods.has(announcer) or methods[announcer] != sig_args.size():
			problems.append("no %s" % announcer)
		if others.has(sig_name):
			problems.append("duplicate %s" % sig_name)
	var _three: GdUnitAssert = assert_int(signals.size()).is_equal(3)
	var _clean: GdUnitAssert = assert_array(problems).is_empty()


func test_developer_mode_off_clears_invulnerability() -> void:
	_developer_mode(true)
	_run.machine.boot()
	_run.bus.flow.announce_start_requested()
	_command(DevCommand.Command.TOGGLE_INVULNERABILITY)
	_developer_mode(false)
	var status_after_off: Array = _statuses.back()
	_command(DevCommand.Command.TOGGLE_INVULNERABILITY)
	_run.bus.flow.announce_play_requested()
	_run.advance(_run.levels[0].intro_duration + RunHarness.STEP)
	_run.bus.player.announce_player_hit(DamageSource.Source.ENEMY_COLLISION, Vector3.ZERO, 0)
	var _off: GdUnitAssert = assert_array(status_after_off).is_equal([false, false])
	var _hit: GdUnitAssert = assert_int(_run.ledger.armor()).is_equal(
		RunRules.MAX_ARMOR - RunRules.COLLISION_DAMAGE
	)
	var _clean: GdUnitAssert = assert_bool(_run.ledger.is_dev_assisted()).is_false()


func test_skip_level_withholds_the_boss_score() -> void:
	_developer_mode(true)
	_run.reach_skirmish()
	_run.fill_gauge()
	_run.advance(RunRules.BOSS_WARNING_DURATION + RunHarness.STEP)
	var fighting: GameState.Phase = _run.machine.state()
	var score_before: int = _run.ledger.score()
	_command(DevCommand.Command.SKIP_LEVEL)
	var tally: LevelTally = _run.tallies.back()
	var _fight: GdUnitAssert = assert_int(fighting).is_equal(GameState.Phase.BOSS_FIGHT)
	var _clear: GdUnitAssert = assert_int(_run.machine.state()).is_equal(
		GameState.Phase.LEVEL_CLEAR
	)
	var _no_boss: GdUnitAssert = assert_int(_run.ledger.score()).is_equal(
		score_before + tally.bonus_total()
	)


func test_skip_on_the_last_level_marks_the_run_before_victory() -> void:
	_run.reach_skirmish()
	for level: int in _run.levels.size() - 1:
		_run.reach_boss_fight()
		_run.defeat_boss()
		_run.bus.flow.announce_continue_requested()
		_run.advance(_run.levels[level + 1].intro_duration + RunHarness.STEP)
	var last_level: int = _run.progression.level_number()
	var clean_so_far: bool = not _run.ledger.is_dev_assisted()
	_developer_mode(true)
	_command(DevCommand.Command.SKIP_LEVEL)
	var _last: GdUnitAssert = assert_int(last_level).is_equal(_run.levels.size())
	var _clean: GdUnitAssert = assert_bool(clean_so_far).is_true()
	var _victory: GdUnitAssert = assert_int(_run.machine.state()).is_equal(GameState.Phase.VICTORY)
	var _marked: GdUnitAssert = assert_bool(_run.run_summaries.back().dev_assisted).is_true()


func test_kill_all_with_no_enemies_leaves_the_run_clean() -> void:
	var field: EnemyField = EnemyField.new()
	add_child(field)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	field.setup(_run.bus, rng, _run.levels, StandInTarget.new(_run.bus))
	_developer_mode(true)
	_run.reach_skirmish()
	_command(DevCommand.Command.KILL_ALL_ENEMIES)
	var clean_when_empty: bool = not _run.ledger.is_dev_assisted()
	var _enemy: Enemy = field.launch(
		EnemyKind.Kind.FIGHTER, Vector3(30.0, 0.0, 0.0), Vector3.LEFT, 0.0
	)
	_command(DevCommand.Command.KILL_ALL_ENEMIES)
	var marked_when_killed: bool = _run.ledger.is_dev_assisted()
	field.free()
	var _clean: GdUnitAssert = assert_bool(clean_when_empty).is_true()
	var _marked: GdUnitAssert = assert_bool(marked_when_killed).is_true()
