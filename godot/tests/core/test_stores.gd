extends GdUnitTestSuite
## The persisted stores (#73): Scoreboard, Settings, Intel and tutorial
## progress, each behind the DocumentStore interface.

var _bus: EventBus
var _saved: Array[int] = []
var _qualified: Array[int] = []
var _settings_seen: Array[GameSettings] = []
var _unlocked: Array[StringName] = []


func before_test() -> void:
	_bus = EventBus.new()
	_saved.clear()
	_qualified.clear()
	_settings_seen.clear()
	_unlocked.clear()
	var subscribed: Array[int] = [
		_bus.profile.scoreboard_saved.connect(_on_saved),
		_bus.profile.scoreboard_qualified.connect(_on_qualified),
		_bus.profile.settings_changed.connect(_on_settings),
		_bus.profile.intel_unlocked.connect(_on_unlocked),
	]
	var _ok: GdUnitAssert = assert_int(subscribed.count(OK)).is_equal(subscribed.size())


func after_test() -> void:
	_bus.free()


func _on_saved(_entry: ScoreEntry, rank: int) -> void:
	_saved.append(rank)


func _on_qualified(rank: int) -> void:
	_qualified.append(rank)


func _on_settings(settings: GameSettings) -> void:
	_settings_seen.append(settings)


func _on_unlocked(entry_id: StringName) -> void:
	_unlocked.append(entry_id)


func _scores(board: Scoreboard) -> Array[int]:
	var scores: Array[int] = []
	for entry: ScoreEntry in board.entries():
		scores.append(entry.score)
	return scores


func test_scoreboard_sorts_descending() -> void:
	var board: Scoreboard = Scoreboard.new(_bus, MemoryDocumentStore.new())
	for score: int in [300, 1200, 50, 1200, 700]:
		var _rank: int = board.submit(ScoreEntry.new("abc", score, 2, 61.0))
	var first_tie: ScoreEntry = board.entries()[0]
	var _sorted: GdUnitAssert = assert_array(_scores(board)).is_equal([1200, 1200, 700, 300, 50])
	var _ranks: GdUnitAssert = assert_array(_saved).is_equal([0, 0, 2, 1, 2])
	var _initials: GdUnitAssert = assert_str(first_tie.initials).is_equal("ABC")


func test_scoreboard_round_trips_store() -> void:
	var store: MemoryDocumentStore = MemoryDocumentStore.new()
	var board: Scoreboard = Scoreboard.new(_bus, store)
	var _a: int = board.submit(ScoreEntry.new("AAA", 4200, 3, 125.5))
	var _b: int = board.submit(ScoreEntry.new("ZED", 9100, 6, 600.0))
	var reloaded: Scoreboard = Scoreboard.new(_bus, store)
	reloaded.restore()
	var same: bool = reloaded.entries().size() == 2
	for i: int in reloaded.entries().size():
		same = same and reloaded.entries()[i].equals(board.entries()[i])
	var _round_trip: GdUnitAssert = assert_bool(same).is_true()
	var _saved_each: GdUnitAssert = assert_int(store.write_count()).is_equal(2)
	var _time: GdUnitAssert = assert_str(reloaded.entries()[1].formatted_time()).is_equal("02:05")


func test_scoreboard_keeps_top_10_only() -> void:
	var board: Scoreboard = Scoreboard.new(_bus, MemoryDocumentStore.new())
	for i: int in 12:
		var _rank: int = board.submit(ScoreEntry.new("AAA", (i + 1) * 100, 1, 10.0))
	var too_low: int = board.submit(ScoreEntry.new("AAA", 150, 1, 10.0))
	var _ten: GdUnitAssert = assert_int(board.entries().size()).is_equal(10)
	var _lowest_kept: GdUnitAssert = assert_int(board.entries()[9].score).is_equal(300)
	var _rejected: GdUnitAssert = assert_int(too_low).is_equal(-1)
	var _zero: GdUnitAssert = assert_int(board.rank_for(0)).is_equal(-1)


func test_scoreboard_saves_run_after_initials() -> void:
	var board: Scoreboard = Scoreboard.new(_bus, MemoryDocumentStore.new())
	_bus.profile.announce_initials_submitted("NOP")
	_bus.run.announce_run_ended(RunSummary.new(0, 1, 30.0, 0, false))
	_bus.run.announce_run_ended(RunSummary.new(25000, 4, 333.0, 80, false))
	_bus.profile.announce_initials_submitted("ace")
	_bus.profile.announce_initials_submitted("TWO")
	var _one_qualified: GdUnitAssert = assert_array(_qualified).is_equal([0])
	var _one_saved: GdUnitAssert = assert_array(_saved).is_equal([0])
	var entry: ScoreEntry = board.entries()[0]
	var _entry: GdUnitAssert = (
		assert_bool(entry.equals(ScoreEntry.new("ACE", 25000, 4, 333.0))).is_true()
	)


func test_scoreboard_drops_invalid_stored_rows() -> void:
	var store: MemoryDocumentStore = (
		MemoryDocumentStore
		. new(
			{
				"version": 1,
				"entries":
				[
					{"initials": "OK1", "score": 10, "level_reached": 1, "time_seconds": 1.0},
					{"initials": "BAD", "score": "lots", "level_reached": 1, "time_seconds": 1.0},
					{"initials": "BAD", "score": 99, "level_reached": 9, "time_seconds": 1.0},
					"not a row",
					{"initials": "GUD", "score": 500, "level_reached": 2, "time_seconds": 9.0},
				]
			}
		)
	)
	var board: Scoreboard = Scoreboard.new(_bus, store)
	board.restore()
	var initials: Array[String] = []
	for entry: ScoreEntry in board.entries():
		initials.append(entry.initials)
	var _valid_only: GdUnitAssert = assert_array(initials).is_equal(["GUD"])


func test_settings_round_trip_and_reset() -> void:
	var store: MemoryDocumentStore = MemoryDocumentStore.new()
	var _settings: Settings = Settings.new(_bus, store)
	var wanted: GameSettings = GameSettings.new()
	wanted.music_volume = 0.25
	wanted.reduced_motion = true
	wanted.rumble = false
	_bus.profile.announce_settings_change_requested(wanted)
	var reloaded: Settings = Settings.new(_bus, store)
	reloaded.restore()
	var restored: bool = reloaded.current().equals(wanted)
	_bus.profile.announce_settings_reset_requested()
	var after_reset: Settings = Settings.new(_bus, store)
	after_reset.restore()
	var _persisted: GdUnitAssert = assert_bool(restored).is_true()
	var _defaults: GdUnitAssert = (
		assert_bool(after_reset.current().equals(GameSettings.new())).is_true()
	)
	var _announced: GdUnitAssert = assert_int(_settings_seen.size()).is_greater_equal(3)


func test_settings_clamp_and_fall_back_per_field() -> void:
	var settings: Settings = Settings.new(
		_bus,
		MemoryDocumentStore.new(
			{"sfx_volume": 7.0, "master_volume": "loud", "rumble": false, "screen_shake": 1}
		)
	)
	settings.restore()
	var current: GameSettings = settings.current()
	var wild: GameSettings = GameSettings.new()
	wild.touch_stick_opacity = 0.0
	settings.apply(wild)
	var _clamped: GdUnitAssert = assert_float(current.sfx_volume).is_equal(1.0)
	var _fallback: GdUnitAssert = assert_float(current.master_volume).is_equal(
		GameSettings.DEFAULT_VOLUME
	)
	var _kept: GdUnitAssert = assert_bool(current.rumble).is_false()
	var _typed: GdUnitAssert = assert_bool(current.screen_shake).is_true()
	var _min_opacity: GdUnitAssert = assert_float(settings.current().touch_stick_opacity).is_equal(
		GameSettings.MIN_TOUCH_STICK_OPACITY
	)


func test_intel_codex_unlocks_once_and_persists() -> void:
	var store: MemoryDocumentStore = MemoryDocumentStore.new()
	var codex: IntelCodex = IntelCodex.new(
		_bus, store, IntelCodex.catalog(LevelLibrary.all_levels())
	)
	_bus.flow.announce_game_state_changed(GameState.Phase.SKIRMISH, GameState.Phase.SKIRMISH)
	_bus.enemy.announce_enemy_spawned(1, EnemyKind.Kind.HEAVY, Vector3.ZERO)
	_bus.enemy.announce_enemy_spawned(2, EnemyKind.Kind.HEAVY, Vector3.ZERO)
	_bus.boss.announce_boss_summoned(&"albatross", "Albatross", 150, 1)
	var reloaded: IntelCodex = IntelCodex.new(_bus, store, IntelCodex.catalog([]))
	reloaded.restore()
	var _once_each: GdUnitAssert = assert_array(_unlocked).is_equal([&"heavy", &"albatross"])
	var _codex: GdUnitAssert = assert_bool(codex.is_unlocked(&"heavy")).is_true()
	var _persisted_enemy: GdUnitAssert = assert_bool(reloaded.is_unlocked(&"heavy")).is_true()
	var _unknown_boss_dropped: GdUnitAssert = (
		assert_bool(reloaded.is_unlocked(&"albatross")).is_false()
	)


func test_intel_codex_ignores_attract_mode_and_unknown_ids() -> void:
	var codex: IntelCodex = IntelCodex.new(_bus, MemoryDocumentStore.new(), IntelCodex.catalog([]))
	_bus.flow.announce_game_state_changed(GameState.Phase.TITLE, GameState.Phase.TITLE)
	_bus.enemy.announce_enemy_spawned(1, EnemyKind.Kind.DRONE, Vector3.ZERO)
	var unknown: bool = codex.unlock(&"zeppelin")
	var _locked: GdUnitAssert = assert_bool(codex.is_unlocked(&"drone")).is_false()
	var _unknown: GdUnitAssert = assert_bool(unknown).is_false()
	var _silent: GdUnitAssert = assert_array(_unlocked).is_empty()


func test_tutorial_progress_persists_done_prompts() -> void:
	var store: MemoryDocumentStore = MemoryDocumentStore.new()
	var progress: TutorialProgress = TutorialProgress.new(store)
	var first: bool = progress.mark_done(TutorialPrompt.Id.MOVE)
	var again: bool = progress.mark_done(TutorialPrompt.Id.MOVE)
	progress.mark_first_run_done()
	var reloaded: TutorialProgress = TutorialProgress.new(store)
	reloaded.restore()
	var done_move: bool = reloaded.is_done(TutorialPrompt.Id.MOVE)
	var done_fire: bool = reloaded.is_done(TutorialPrompt.Id.AIM_AND_FIRE)
	for prompt: TutorialPrompt.Id in TutorialPrompt.Id.values():
		var _marked: bool = reloaded.mark_done(prompt)
	var complete: bool = reloaded.is_complete()
	var first_run: bool = reloaded.is_first_run_done()
	reloaded.reset()
	var _newly: GdUnitAssert = assert_array([first, again]).is_equal([true, false])
	var _persisted: GdUnitAssert = assert_array([done_move, done_fire]).is_equal([true, false])
	var _first_run: GdUnitAssert = assert_bool(first_run).is_true()
	var _complete: GdUnitAssert = assert_bool(complete).is_true()
	var _reset: GdUnitAssert = assert_bool(reloaded.is_done(TutorialPrompt.Id.MOVE)).is_false()
