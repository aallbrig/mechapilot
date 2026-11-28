extends GdUnitTestSuite
## The UI flow (#24): one screen per Game State, driven only by Events, with
## the real rules and stores behind it (tests/support/ui_harness.gd).

## The screens each Game State must show, written out independently of
## UiRoot.SCREENS_FOR.
const EXPECTED: Dictionary[GameState.Phase, Array] = {
	GameState.Phase.BOOT: [&"Boot"],
	GameState.Phase.TITLE: [&"Title"],
	GameState.Phase.LEVEL_INTRO: [&"Hud", &"LevelIntro"],
	GameState.Phase.SKIRMISH: [&"Hud"],
	GameState.Phase.BOSS_WARNING: [&"Hud", &"BossWarning"],
	GameState.Phase.BOSS_FIGHT: [&"Hud"],
	GameState.Phase.LEVEL_CLEAR: [&"LevelClear"],
	GameState.Phase.PAUSED: [&"Pause"],
	GameState.Phase.GAME_OVER: [&"GameOver"],
	GameState.Phase.VICTORY: [&"Victory"],
	GameState.Phase.SCOREBOARD: [&"Scoreboard"],
}

var _h: UiHarness
var _runs_started: int = 0
var _typed: Array[String] = []


func before_test() -> void:
	_h = UiHarness.new()
	add_child(_h.host)
	_runs_started = 0
	var _ok: GdUnitAssert = assert_int(_h.bus.run.run_started.connect(_on_run_started)).is_equal(OK)


func after_test() -> void:
	_h.dispose()


func _on_run_started(_level_number: int) -> void:
	_runs_started += 1


func _on_submitted(initials: String) -> void:
	_typed.append(initials)


func _sorted(names: Array) -> Array[String]:
	var out: Array[String] = []
	for item: Variant in names:
		out.append(str(item))
	out.sort()
	return out


func test_ui_shows_only_current_state_screen() -> void:
	_h.boot()
	var wrong: Array[String] = []
	var previous: GameState.Phase = GameState.Phase.BOOT
	for phase: GameState.Phase in EXPECTED:
		_h.bus.flow.announce_game_state_changed(previous, phase)
		if _sorted(_h.ui.visible_screens()) != _sorted(EXPECTED[phase]):
			wrong.append("%s: %s" % [GameState.Phase.keys()[phase], _h.ui.visible_screens()])
		previous = phase
	# A sub-screen closes when the Game State changes under it.
	_h.bus.flow.announce_game_state_changed(previous, GameState.Phase.TITLE)
	_h.ui.open(&"settings")
	var settings_open: Array[StringName] = _h.ui.visible_screens()
	_h.bus.flow.announce_game_state_changed(GameState.Phase.TITLE, GameState.Phase.SCOREBOARD)
	var _each: GdUnitAssert = assert_array(wrong).is_empty()
	var _sub: GdUnitAssert = assert_array(settings_open).is_equal([&"Settings"])
	var _closed: GdUnitAssert = assert_array(_h.ui.visible_screens()).is_equal([&"Scoreboard"])


func test_ui_follows_the_real_rules_through_a_level() -> void:
	_h.reach_title()
	var seen: Array[String] = [str(_h.ui.visible_screens())]
	((_h.screen(&"Title") as TitleScreen).default_focus() as Button).pressed.emit()
	seen.append(str(_h.ui.visible_screens()))
	_h.run.advance(_h.run.levels[0].intro_duration + RunHarness.STEP)
	seen.append(str(_h.ui.visible_screens()))
	_h.run.fill_gauge()
	seen.append(str(_h.ui.visible_screens()))
	_h.run.advance(RunRules.BOSS_WARNING_DURATION + RunHarness.STEP)
	seen.append(str(_h.ui.visible_screens()))
	_h.run.defeat_boss()
	seen.append(str(_h.ui.visible_screens()))
	var _flow: GdUnitAssert = (
		assert_array(seen)
		. is_equal(
			[
				str([&"Title"]),
				str([&"Hud", &"LevelIntro"]),
				str([&"Hud"]),
				str([&"Hud", &"BossWarning"]),
				str([&"Hud"]),
				str([&"LevelClear"]),
			]
		)
	)


func test_initials_up_goes_to_previous_letter() -> void:
	var picker: InitialsPicker = auto_free(InitialsPicker.new())
	add_child(picker)
	picker._gui_input(_key_event(KEY_UP))
	var after_up: String = picker.initials()
	picker.move_slot(1)
	picker._gui_input(_key_event(KEY_DOWN))
	var after_down: String = picker.initials()
	var _up: GdUnitAssert = assert_str(after_up).is_equal("ZAA")
	var _down: GdUnitAssert = assert_str(after_down).is_equal("ZBA")


func test_initials_down_from_z_wraps_to_a() -> void:
	var picker: InitialsPicker = auto_free(InitialsPicker.new())
	add_child(picker)
	picker.letter_up()
	var at_z: String = picker.initials()
	picker.letter_down()
	var _up_from_a: GdUnitAssert = assert_str(at_z).is_equal("ZAA")
	var _down_from_z: GdUnitAssert = assert_str(picker.initials()).is_equal("AAA")


func test_initials_arrow_buttons_match_keys() -> void:
	var picker: InitialsPicker = auto_free(InitialsPicker.new())
	add_child(picker)
	var buttons: Array[BaseButton] = picker.buttons()
	var up: ArrowButton = buttons[0] as ArrowButton
	var down: ArrowButton = buttons[InitialsPicker.LENGTH] as ArrowButton
	up.pressed.emit()
	var after_up: String = picker.initials()
	down.pressed.emit()
	down.pressed.emit()
	var _up: GdUnitAssert = assert_str(after_up).is_equal("ZAA")
	var _down: GdUnitAssert = assert_str(picker.initials()).is_equal("BAA")
	var _up_tip: GdUnitAssert = assert_str(up.tooltip_text).is_equal("Previous letter")
	var _down_tip: GdUnitAssert = assert_str(down.tooltip_text).is_equal("Next letter")


func _key_event(key: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	return event


func test_initials_typing_and_slots() -> void:
	var picker: InitialsPicker = auto_free(InitialsPicker.new())
	add_child(picker)
	_typed.clear()
	var _ok: GdUnitAssert = assert_int(picker.submitted.connect(_on_submitted)).is_equal(OK)
	for code: Key in [KEY_Z, KEY_E, KEY_D]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = code
		key.pressed = true
		picker._gui_input(key)
	var slot_after_typing: int = picker.slot()
	var accept: InputEventKey = InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.physical_keycode = KEY_ENTER
	accept.pressed = true
	picker._gui_input(accept)
	var _slot: GdUnitAssert = assert_int(slot_after_typing).is_equal(2)
	var _submitted: GdUnitAssert = assert_array(_typed).is_equal(["ZED"])


func test_game_over_saves_scoreboard_entry() -> void:
	_h.reach_title()
	_h.bus.flow.announce_play_requested()
	_h.reach_game_over(3)
	var game_over: RunEndScreen = _h.screen(&"GameOver") as RunEndScreen
	var asking: bool = game_over.is_asking_initials()
	for letter: String in ["Z", "E", "D"]:
		game_over.picker().type_letter(letter)
	game_over.picker().submit()
	var board: ScoreboardScreen = _h.screen(&"Scoreboard") as ScoreboardScreen
	var saved: Array[ScoreEntry] = _h.scoreboard.entries()
	var _asked: GdUnitAssert = assert_bool(asking).is_true()
	var _one: GdUnitAssert = assert_int(saved.size()).is_equal(1)
	var _initials: GdUnitAssert = assert_str(saved[0].initials).is_equal("ZED")
	var _score: GdUnitAssert = assert_int(saved[0].score).is_equal(300)
	var _level: GdUnitAssert = assert_int(saved[0].level_reached).is_equal(1)
	var _stored: GdUnitAssert = assert_int(_h.scoreboard_store.write_count()).is_equal(1)
	var _board: GdUnitAssert = assert_array(_h.ui.visible_screens()).is_equal([&"Scoreboard"])
	var _row: GdUnitAssert = assert_str(board.row_lines()[0]).starts_with("1 ZED 300 1 ")


func test_game_over_without_a_place_skips_initials() -> void:
	_h.reach_title()
	_h.bus.flow.announce_play_requested()
	_h.reach_game_over(0)
	var game_over: RunEndScreen = _h.screen(&"GameOver") as RunEndScreen
	var _no_initials: GdUnitAssert = assert_bool(game_over.is_asking_initials()).is_false()
	var _offers: GdUnitAssert = assert_bool(game_over.play_again_button().visible).is_true()
	var _nothing_saved: GdUnitAssert = assert_int(_h.scoreboard_store.write_count()).is_equal(0)


func test_hud_updates_on_score_changed() -> void:
	_h.reach_title()
	_h.bus.flow.announce_play_requested()
	_h.run.advance(_h.run.levels[0].intro_duration + RunHarness.STEP)
	var hud: Hud = _h.screen(&"Hud") as Hud
	var at_start: String = hud.score_text()
	var _points: int = _h.run.kill(EnemyKind.Kind.FIGHTER)
	var after_kill: String = hud.score_text()
	_h.bus.run.announce_score_changed(1234567, 100)
	var _start: GdUnitAssert = assert_str(at_start).is_equal("0")
	var _kill: GdUnitAssert = assert_str(after_kill).is_equal("100")
	var _grouped: GdUnitAssert = assert_str(hud.score_text()).is_equal("1,234,567")


func test_play_again_starts_new_run() -> void:
	_h.reach_title()
	_h.bus.flow.announce_play_requested()
	_h.reach_game_over(0)
	var game_over: RunEndScreen = _h.screen(&"GameOver") as RunEndScreen
	var focused: bool = game_over.play_again_button().has_focus()
	game_over.play_again_button().pressed.emit()
	var _focus: GdUnitAssert = assert_bool(focused).is_true()
	var _two_runs: GdUnitAssert = assert_int(_runs_started).is_equal(2)
	var _state: GdUnitAssert = assert_int(_h.run.machine.state()).is_equal(
		GameState.Phase.LEVEL_INTRO
	)
	var _shown: GdUnitAssert = assert_array(_h.ui.visible_screens()).is_equal(
		[&"Hud", &"LevelIntro"]
	)
	var _fresh: GdUnitAssert = assert_str((_h.screen(&"Hud") as Hud).score_text()).is_equal("0")


func test_game_over_saves_with_production_listener_order() -> void:
	var h: UiHarness = UiHarness.new(UiHarness.LANDSCAPE, true, true)
	add_child(h.host)
	h.reach_title()
	h.bus.flow.announce_play_requested()
	h.reach_game_over(2)
	var game_over: RunEndScreen = h.screen(&"GameOver") as RunEndScreen
	var asking: bool = game_over.is_asking_initials()
	game_over.picker().type_letter("Q")
	game_over.picker().submit()
	var saved: Array[ScoreEntry] = h.scoreboard.entries()
	var shown: Array[StringName] = h.ui.visible_screens()
	h.dispose()
	var _asked: GdUnitAssert = assert_bool(asking).is_true()
	var _saved: GdUnitAssert = assert_int(saved.size()).is_equal(1)
	var _initials: GdUnitAssert = assert_str(saved[0].initials).is_equal("QAA")
	var _board: GdUnitAssert = assert_array(shown).is_equal([&"Scoreboard"])


func test_run_end_screens_take_only_their_own_run_and_reset_on_enter() -> void:
	_h.reach_title()
	var game_over: RunEndScreen = _h.screen(&"GameOver") as RunEndScreen
	var victory: RunEndScreen = _h.screen(&"Victory") as RunEndScreen
	# A Victory summary never fills the Game Over screen, and the reverse.
	_h.bus.flow.announce_game_state_changed(GameState.Phase.BOSS_FIGHT, GameState.Phase.GAME_OVER)
	_h.bus.run.announce_run_ended(RunSummary.new(5000, 6, 60.0, 9, true))
	var game_over_rows: int = game_over.tally().lines().size()
	_h.bus.flow.announce_game_state_changed(GameState.Phase.GAME_OVER, GameState.Phase.VICTORY)
	_h.bus.run.announce_run_ended(RunSummary.new(5000, 3, 60.0, 9, false))
	var victory_rows: int = victory.tally().lines().size()
	# A Run that placed asks for initials; entering again for a Run that did
	# not place must not ask again.
	_h.bus.flow.announce_game_state_changed(GameState.Phase.VICTORY, GameState.Phase.GAME_OVER)
	_h.bus.run.announce_run_ended(RunSummary.new(7000, 2, 60.0, 9, false))
	_h.bus.profile.announce_scoreboard_qualified(0)
	var first_asks: bool = game_over.is_asking_initials()
	_h.bus.flow.announce_game_state_changed(GameState.Phase.GAME_OVER, GameState.Phase.LEVEL_INTRO)
	_h.bus.flow.announce_game_state_changed(GameState.Phase.SKIRMISH, GameState.Phase.GAME_OVER)
	# A score of 0 never places, so the real Scoreboard stays quiet.
	_h.bus.run.announce_run_ended(RunSummary.new(0, 1, 5.0, 0, false))
	var second_asks: bool = game_over.is_asking_initials()
	var _own_only: GdUnitAssert = assert_int(game_over_rows).is_equal(0)
	var _victory_own_only: GdUnitAssert = assert_int(victory_rows).is_equal(0)
	var _asked: GdUnitAssert = assert_bool(first_asks).is_true()
	var _reset: GdUnitAssert = assert_bool(second_asks).is_false()
	var _offers: GdUnitAssert = assert_bool(game_over.play_again_button().visible).is_true()
