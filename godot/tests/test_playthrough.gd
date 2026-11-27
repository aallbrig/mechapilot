extends GdUnitTestSuite
## Headless playthroughs of the assembled game (main.tscn, #84), played only
## through real input (tests/support/autopilot.gd): the loop from Boot and the
## Title through a Level and its boss to the next Level, and a Run that loses
## every life through Game Over and the initials to the Scoreboard.
##
## The engine runs faster than real time (the scene runner's time factor), at
## the project's fixed 60 Hz step, so a Level takes seconds, not minutes.

## Engine time runs this many times faster than the wall clock.
const TIME_FACTOR: float = 8.0
## Game seconds a playthrough may take before it gives up.
const CLEAR_LIMIT: float = 600.0
const GAME_OVER_LIMIT: float = 300.0
## The Run scores at least one kill before the autopilot starts ramming, so
## the Game Over has a score to enter initials for.
const KILLS_BEFORE_RAMMING: int = 3

var _states: Array[GameState.Phase] = []
var _intros: Array[int] = []
var _tallies: Array[LevelTally] = []
var _defeated: Array[StringName] = []
var _shot_kills: int = 0
var _qualified: int = 0
var _saved: int = 0
var _ended: Array[RunSummary] = []
## The Scoreboard on disk before the test: each playthrough starts from an
## empty board (so a scoring Run always places) and puts the old one back.
var _board: LocalDocumentStore = LocalDocumentStore.new(LocalDocumentStore.Slot.SCOREBOARD)
var _saved_board: Dictionary = {}


func before_test() -> void:
	_states.clear()
	_intros.clear()
	_tallies.clear()
	_defeated.clear()
	_ended.clear()
	_shot_kills = 0
	_qualified = 0
	_saved = 0
	_saved_board = _board.read_document()
	var _emptied: bool = _board.write_document({})
	var subscribed: Array[int] = [
		Events.flow.game_state_changed.connect(_on_state),
		Events.run.level_intro_started.connect(_on_intro),
		Events.run.level_cleared.connect(_on_cleared),
		Events.run.run_ended.connect(_on_ended),
		Events.boss.boss_defeated.connect(_on_boss_defeated),
		Events.enemy.enemy_destroyed.connect(_on_enemy_destroyed),
		Events.profile.scoreboard_qualified.connect(_on_qualified),
		Events.profile.scoreboard_saved.connect(_on_saved),
	]
	var _ok: GdUnitAssert = assert_int(subscribed.count(OK)).is_equal(subscribed.size())


func after_test() -> void:
	var _restored: bool = _board.write_document(_saved_board)
	Events.flow.game_state_changed.disconnect(_on_state)
	Events.run.level_intro_started.disconnect(_on_intro)
	Events.run.level_cleared.disconnect(_on_cleared)
	Events.run.run_ended.disconnect(_on_ended)
	Events.boss.boss_defeated.disconnect(_on_boss_defeated)
	Events.enemy.enemy_destroyed.disconnect(_on_enemy_destroyed)
	Events.profile.scoreboard_qualified.disconnect(_on_qualified)
	Events.profile.scoreboard_saved.disconnect(_on_saved)


func test_playthrough_clears_level_one() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://main.tscn")
	var _fast: GdUnitSceneRunner = runner.set_time_factor(TIME_FACTOR)
	var pilot: Autopilot = Autopilot.new(runner.scene())
	add_child(pilot)
	while not _intros.has(2) and not _states.has(GameState.Phase.GAME_OVER):
		if pilot.flown > CLEAR_LIMIT:
			break
		await pilot.ticked
	pilot.queue_free()
	var _level_two: GdUnitAssert = assert_array(_intros).is_equal([1, 2])
	var _loop: GdUnitAssert = (
		assert_array(_states)
		. contains_exactly(
			[
				GameState.Phase.BOOT,
				GameState.Phase.TITLE,
				GameState.Phase.LEVEL_INTRO,
				GameState.Phase.SKIRMISH,
				GameState.Phase.BOSS_WARNING,
				GameState.Phase.BOSS_FIGHT,
				GameState.Phase.LEVEL_CLEAR,
				GameState.Phase.LEVEL_INTRO,
			]
		)
	)
	var _boss: GdUnitAssert = assert_array(_defeated).is_equal([&"albatross"])
	var _tally: GdUnitAssert = assert_int(_tallies.size()).is_equal(1)
	if _tallies.size() == 1:
		var _bonus: GdUnitAssert = assert_int(_tallies[0].bonus_total()).is_greater(0)
		var _kills: GdUnitAssert = assert_int(_tallies[0].kills).is_greater(0)
	var _shots_scored: GdUnitAssert = assert_int(_shot_kills).is_greater(0)


func test_playthrough_game_over_reaches_scoreboard() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://main.tscn")
	var _fast: GdUnitSceneRunner = runner.set_time_factor(TIME_FACTOR)
	var pilot: Autopilot = Autopilot.new(runner.scene())
	add_child(pilot)
	while not _states.has(GameState.Phase.SCOREBOARD):
		if pilot.flown > GAME_OVER_LIMIT:
			break
		if _shot_kills >= KILLS_BEFORE_RAMMING:
			pilot.mode = Autopilot.Mode.RAM
		await pilot.ticked
	pilot.queue_free()
	var _over: GdUnitAssert = assert_array(_states).contains(
		[GameState.Phase.GAME_OVER, GameState.Phase.SCOREBOARD]
	)
	var _no_clear: GdUnitAssert = assert_array(_states).not_contains([GameState.Phase.LEVEL_CLEAR])
	var _one_run: GdUnitAssert = assert_int(_ended.size()).is_equal(1)
	if _ended.size() == 1:
		var _lost: GdUnitAssert = assert_bool(_ended[0].victory).is_false()
		var _scored: GdUnitAssert = assert_int(_ended[0].score).is_greater(0)
	# From an empty board the score places: initials are asked for and saved.
	var _asked: GdUnitAssert = assert_int(_qualified).is_equal(1)
	var _initials: GdUnitAssert = assert_int(_saved).is_equal(1)


func _on_state(_from: GameState.Phase, to: GameState.Phase) -> void:
	_states.append(to)


func _on_intro(level_number: int, _name: String, _objective: String, _duration: float) -> void:
	_intros.append(level_number)


func _on_cleared(tally: LevelTally) -> void:
	_tallies.append(tally)


func _on_ended(summary: RunSummary) -> void:
	_ended.append(summary)


func _on_boss_defeated(boss_id: StringName, _position: Vector3) -> void:
	_defeated.append(boss_id)


func _on_enemy_destroyed(
	_enemy_id: int, _kind: EnemyKind.Kind, _position: Vector3, cause: DestroyCause.Cause
) -> void:
	if cause == DestroyCause.Cause.SHOT:
		_shot_kills += 1


func _on_qualified(_rank: int) -> void:
	_qualified += 1


func _on_saved(_entry: ScoreEntry, _rank: int) -> void:
	_saved += 1
