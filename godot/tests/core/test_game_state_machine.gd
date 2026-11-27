extends GdUnitTestSuite
## The Game State machine (#73): legal transitions only, Pause only during play.

## How to reach each phase from BOOT (independent of the machine's own table).
const PATHS: Dictionary[GameState.Phase, Array] = {
	GameState.Phase.BOOT: [],
	GameState.Phase.TITLE: [GameState.Phase.TITLE],
	GameState.Phase.LEVEL_INTRO: [GameState.Phase.TITLE, GameState.Phase.LEVEL_INTRO],
	GameState.Phase.SKIRMISH:
	[GameState.Phase.TITLE, GameState.Phase.LEVEL_INTRO, GameState.Phase.SKIRMISH],
	GameState.Phase.BOSS_WARNING:
	[
		GameState.Phase.TITLE,
		GameState.Phase.LEVEL_INTRO,
		GameState.Phase.SKIRMISH,
		GameState.Phase.BOSS_WARNING,
	],
	GameState.Phase.BOSS_FIGHT:
	[
		GameState.Phase.TITLE,
		GameState.Phase.LEVEL_INTRO,
		GameState.Phase.SKIRMISH,
		GameState.Phase.BOSS_WARNING,
		GameState.Phase.BOSS_FIGHT,
	],
	GameState.Phase.LEVEL_CLEAR:
	[
		GameState.Phase.TITLE,
		GameState.Phase.LEVEL_INTRO,
		GameState.Phase.SKIRMISH,
		GameState.Phase.BOSS_WARNING,
		GameState.Phase.BOSS_FIGHT,
		GameState.Phase.LEVEL_CLEAR,
	],
	GameState.Phase.PAUSED:
	[
		GameState.Phase.TITLE,
		GameState.Phase.LEVEL_INTRO,
		GameState.Phase.SKIRMISH,
		GameState.Phase.PAUSED,
	],
	GameState.Phase.GAME_OVER:
	[
		GameState.Phase.TITLE,
		GameState.Phase.LEVEL_INTRO,
		GameState.Phase.SKIRMISH,
		GameState.Phase.GAME_OVER,
	],
	GameState.Phase.VICTORY:
	[
		GameState.Phase.TITLE,
		GameState.Phase.LEVEL_INTRO,
		GameState.Phase.SKIRMISH,
		GameState.Phase.BOSS_WARNING,
		GameState.Phase.BOSS_FIGHT,
		GameState.Phase.VICTORY,
	],
	GameState.Phase.SCOREBOARD: [GameState.Phase.TITLE, GameState.Phase.SCOREBOARD],
}

## #73's legal transitions, written out independently of the machine's table.
## PAUSED is reached from SKIRMISH (see PATHS), so it may resume only to SKIRMISH.
const LEGAL: Dictionary[GameState.Phase, Array] = {
	GameState.Phase.BOOT: [GameState.Phase.TITLE],
	GameState.Phase.TITLE: [GameState.Phase.LEVEL_INTRO, GameState.Phase.SCOREBOARD],
	GameState.Phase.LEVEL_INTRO: [GameState.Phase.SKIRMISH, GameState.Phase.PAUSED],
	GameState.Phase.SKIRMISH:
	[GameState.Phase.BOSS_WARNING, GameState.Phase.PAUSED, GameState.Phase.GAME_OVER],
	GameState.Phase.BOSS_WARNING:
	[GameState.Phase.BOSS_FIGHT, GameState.Phase.PAUSED, GameState.Phase.GAME_OVER],
	GameState.Phase.BOSS_FIGHT:
	[
		GameState.Phase.LEVEL_CLEAR,
		GameState.Phase.VICTORY,
		GameState.Phase.PAUSED,
		GameState.Phase.GAME_OVER,
	],
	GameState.Phase.LEVEL_CLEAR: [GameState.Phase.LEVEL_INTRO],
	GameState.Phase.PAUSED: [GameState.Phase.SKIRMISH, GameState.Phase.TITLE],
	GameState.Phase.GAME_OVER:
	[GameState.Phase.LEVEL_INTRO, GameState.Phase.SCOREBOARD, GameState.Phase.TITLE],
	GameState.Phase.VICTORY:
	[GameState.Phase.LEVEL_INTRO, GameState.Phase.SCOREBOARD, GameState.Phase.TITLE],
	GameState.Phase.SCOREBOARD: [GameState.Phase.LEVEL_INTRO, GameState.Phase.TITLE],
}

const PLAY_PHASES: Array[GameState.Phase] = [
	GameState.Phase.LEVEL_INTRO,
	GameState.Phase.SKIRMISH,
	GameState.Phase.BOSS_WARNING,
	GameState.Phase.BOSS_FIGHT,
]

var _bus: EventBus
var _changes: Array[Array] = []


func before_test() -> void:
	_bus = EventBus.new()
	_changes.clear()
	var _ok: GdUnitAssert = assert_int(_bus.flow.game_state_changed.connect(_record)).is_equal(OK)


func after_test() -> void:
	_bus.free()


func _record(from: GameState.Phase, to: GameState.Phase) -> void:
	_changes.append([from, to])


func _machine_at(phase: GameState.Phase) -> GameStateMachine:
	var machine: GameStateMachine = GameStateMachine.new(_bus)
	machine.boot()
	for step: GameState.Phase in PATHS[phase]:
		var _moved: bool = machine.request(step)
	return machine


func test_state_machine_boots_into_menu() -> void:
	var machine: GameStateMachine = GameStateMachine.new(_bus)
	var before_boot: bool = machine.can_transition(GameState.Phase.TITLE)
	machine.boot()
	machine.boot()
	_bus.flow.announce_start_requested()
	var _no_early_moves: GdUnitAssert = assert_bool(before_boot).is_false()
	var _booted: GdUnitAssert = (
		assert_array(_changes)
		. is_equal(
			[
				[GameState.Phase.BOOT, GameState.Phase.BOOT],
				[GameState.Phase.BOOT, GameState.Phase.TITLE],
			]
		)
	)
	var _title: GdUnitAssert = assert_int(machine.state()).is_equal(GameState.Phase.TITLE)


func test_state_machine_rejects_illegal_transition() -> void:
	var machine: GameStateMachine = _machine_at(GameState.Phase.TITLE)
	_changes.clear()
	var moved: bool = machine.request(GameState.Phase.BOSS_FIGHT)
	_bus.flow.announce_start_requested()
	_bus.flow.announce_resume_requested()
	var _rejected: GdUnitAssert = assert_bool(moved).is_false()
	var _silent: GdUnitAssert = assert_array(_changes).is_empty()
	var _stayed: GdUnitAssert = assert_int(machine.state()).is_equal(GameState.Phase.TITLE)


func test_state_machine_allows_exactly_the_legal_transitions() -> void:
	var wrong: Array[String] = []
	for from: GameState.Phase in PATHS:
		var reached: GameStateMachine = _machine_at(from)
		if reached.state() != from:
			wrong.append("could not reach %s" % GameState.Phase.keys()[from])
			continue
		for to: GameState.Phase in GameState.Phase.values():
			var machine: GameStateMachine = _machine_at(from)
			var expected: bool = LEGAL[from].has(to)
			if machine.request(to) != expected or (expected and machine.state() != to):
				wrong.append(
					"%s -> %s" % [GameState.Phase.keys()[from], GameState.Phase.keys()[to]]
				)
	var _exact: GdUnitAssert = assert_array(wrong).is_empty()


func test_state_machine_pauses_only_during_play() -> void:
	var paused_from: Array[GameState.Phase] = []
	for phase: GameState.Phase in PATHS:
		var machine: GameStateMachine = _machine_at(phase)
		_bus.flow.announce_pause_requested()
		if machine.state() == GameState.Phase.PAUSED and phase != GameState.Phase.PAUSED:
			paused_from.append(phase)
	var _only_play: GdUnitAssert = assert_array(paused_from).contains_exactly_in_any_order(
		PLAY_PHASES
	)


func test_state_machine_resumes_only_to_the_paused_phase() -> void:
	var machine: GameStateMachine = _machine_at(GameState.Phase.BOSS_WARNING)
	_bus.flow.announce_pause_requested()
	var paused: GameState.Phase = machine.state()
	var to_other: bool = machine.request(GameState.Phase.SKIRMISH)
	_bus.flow.announce_resume_requested()
	var _paused: GdUnitAssert = assert_int(paused).is_equal(GameState.Phase.PAUSED)
	var _no_other: GdUnitAssert = assert_bool(to_other).is_false()
	var _resumed: GdUnitAssert = assert_int(machine.state()).is_equal(GameState.Phase.BOSS_WARNING)


func test_state_machine_quits_to_title_only_from_pause() -> void:
	var machine: GameStateMachine = _machine_at(GameState.Phase.SKIRMISH)
	_bus.flow.announce_quit_to_title_requested()
	_bus.flow.announce_title_requested()
	var in_play: GameState.Phase = machine.state()
	_bus.flow.announce_pause_requested()
	_bus.flow.announce_title_requested()
	var still_paused: GameState.Phase = machine.state()
	_bus.flow.announce_quit_to_title_requested()
	var _ignored_in_play: GdUnitAssert = assert_int(in_play).is_equal(GameState.Phase.SKIRMISH)
	var _back_needs_quit: GdUnitAssert = assert_int(still_paused).is_equal(GameState.Phase.PAUSED)
	var _quit: GdUnitAssert = assert_int(machine.state()).is_equal(GameState.Phase.TITLE)


func test_state_machine_play_again_starts_new_run() -> void:
	var harness: RunHarness = RunHarness.new()
	harness.reach_skirmish()
	var _points: int = harness.kill(EnemyKind.Kind.FIGHTER)
	harness.lose_life()
	harness.lose_life()
	harness.lose_life()
	harness.advance(harness.levels[0].game_over_delay + RunHarness.STEP)
	var over: GameState.Phase = harness.machine.state()
	harness.states.clear()
	harness.bus.flow.announce_play_requested()
	var states: Array[GameState.Phase] = harness.states.duplicate()
	var score: int = harness.ledger.score()
	var lives: int = harness.ledger.lives()
	var level: int = harness.progression.level_number()
	harness.dispose()
	var _was_over: GdUnitAssert = assert_int(over).is_equal(GameState.Phase.GAME_OVER)
	var _straight_to_intro: GdUnitAssert = assert_array(states).is_equal(
		[GameState.Phase.LEVEL_INTRO]
	)
	var _fresh_score: GdUnitAssert = assert_int(score).is_equal(0)
	var _fresh_lives: GdUnitAssert = assert_int(lives).is_equal(RunRules.START_LIVES)
	var _level_one: GdUnitAssert = assert_int(level).is_equal(1)
