extends GdUnitTestSuite
## What each screen shows (#24, #73), from Events and the stores only.

var _h: UiHarness


func before_test() -> void:
	_h = UiHarness.new()
	add_child(_h.host)


func after_test() -> void:
	_h.dispose()


func _button(screen_name: StringName, text: String) -> Button:
	for control: Control in _h.screen(screen_name).juiced_controls():
		if control is Button and (control as Button).text == text:
			return control as Button
	return null


func test_hud_shows_armor_lives_gauge_and_boss_bar() -> void:
	_h.reach_title()
	_h.bus.flow.announce_play_requested()
	var hud: Hud = _h.screen(&"Hud") as Hud
	_h.run.advance(_h.run.levels[0].intro_duration + RunHarness.STEP)
	var lives: int = hud.lives_shown()
	_h.bus.player.announce_player_hit(DamageSource.Source.ENEMY_COLLISION, Vector3.ZERO, 0)
	var armor: float = hud.armor_value()
	var _points: int = _h.run.kill(EnemyKind.Kind.FIGHTER)
	var gauge: float = hud.gauge_ratio()
	_h.run.advance(RunRules.COMBO_WINDOW + RunHarness.STEP)
	_h.run.reach_boss_fight()
	var boss_shown: bool = hud.boss_bar_shown()
	var boss_full: float = hud.boss_ratio()
	_h.bus.boss.announce_boss_hit(1, Vector3.ZERO)
	var boss_hurt: float = hud.boss_ratio()
	_h.run.defeat_boss()
	var _lives: GdUnitAssert = assert_int(lives).is_equal(RunRules.START_LIVES)
	var _armor: GdUnitAssert = assert_float(armor).is_equal(75.0)
	var _gauge: GdUnitAssert = assert_float(gauge).is_greater(0.0)
	var _boss: GdUnitAssert = assert_bool(boss_shown).is_true()
	var _full: GdUnitAssert = assert_float(boss_full).is_equal(1.0)
	var _hurt: GdUnitAssert = assert_float(boss_hurt).is_less(1.0)
	var _gone: GdUnitAssert = assert_bool(hud.boss_bar_shown()).is_false()


func test_hud_combo_and_bonus_life() -> void:
	_h.reach_title()
	_h.bus.flow.announce_play_requested()
	var hud: Hud = _h.screen(&"Hud") as Hud
	_h.bus.run.announce_combo_changed(3)
	var combo: String = hud.combo_text()
	_h.bus.run.announce_combo_changed(1)
	_h.bus.player.announce_bonus_life_awarded(4)
	_h.bus.player.announce_lives_changed(4)
	var _combo: GdUnitAssert = assert_str(combo).is_equal("x3 COMBO")
	var _none: GdUnitAssert = assert_str(hud.combo_text()).is_empty()
	var _four: GdUnitAssert = assert_int(hud.lives_shown()).is_equal(4)
	var _pop: GdUnitAssert = assert_array(_h.cues).contains([UiCue.Cue.POP])


func test_level_intro_card_and_boss_warning_show_the_level() -> void:
	_h.reach_title()
	_h.bus.flow.announce_play_requested()
	var card: LevelIntroCard = _h.screen(&"LevelIntro") as LevelIntroCard
	var lines: PackedStringArray = card.lines()
	_h.run.advance(_h.run.levels[0].intro_duration + RunHarness.STEP)
	_h.run.fill_gauge()
	var warning: BossWarning = _h.screen(&"BossWarning") as BossWarning
	var level: LevelDefinition = _h.run.levels[0]
	var _number: GdUnitAssert = assert_str(lines[0]).is_equal("LEVEL 1")
	var _name: GdUnitAssert = assert_str(lines[1]).is_equal(level.display_name.to_upper())
	var _objective: GdUnitAssert = assert_str(lines[2]).is_equal(level.objective)
	var _banner: GdUnitAssert = assert_str(warning.lines()[0]).is_equal("WARNING")
	var _boss: GdUnitAssert = assert_str(warning.lines()[1]).contains(
		level.boss.display_name.to_upper()
	)
	var _siren: GdUnitAssert = assert_array(_h.cues).contains([UiCue.Cue.WARNING])


func test_level_clear_tally_counts_up() -> void:
	_h.reach_title()
	TweenFx.reduced_motion = false
	_h.bus.run.announce_level_cleared(LevelTally.new(1, 12, 40, 30, 4000, 10000))
	_h.bus.flow.announce_game_state_changed(GameState.Phase.BOSS_FIGHT, GameState.Phase.LEVEL_CLEAR)
	var clear: LevelClearScreen = _h.screen(&"LevelClear") as LevelClearScreen
	var at_start: PackedStringArray = clear.tally().lines()
	await await_millis(300)
	var counting: PackedStringArray = clear.tally().lines()
	var continue_early: bool = clear.continue_button().visible
	clear._unhandled_input(_accept())
	var done: PackedStringArray = clear.tally().lines()
	var focused: bool = clear.continue_button().has_focus()
	clear.continue_button().pressed.emit()
	var _zero: GdUnitAssert = assert_str(at_start[0]).is_equal("Kills 0")
	var _partway: GdUnitAssert = assert_str(counting[0]).is_not_equal("Kills 0")
	var _not_yet: GdUnitAssert = assert_bool(continue_early).is_false()
	var _ticks: GdUnitAssert = assert_array(_h.cues).contains(
		[UiCue.Cue.TICK, UiCue.Cue.TALLY_DONE]
	)
	var _full: GdUnitAssert = assert_array(done).is_equal(
		[
			"Kills 12",
			"Accuracy 75%",
			"Armor bonus 4,000",
			"No-death bonus 10,000",
			"Bonus total 14,000"
		]
	)
	var _focus: GdUnitAssert = assert_bool(focused).is_true()


func _accept() -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.physical_keycode = KEY_ENTER
	key.pressed = true
	return key


func test_level_clear_continue_starts_next_level() -> void:
	_h.reach_title()
	_h.bus.flow.announce_play_requested()
	_h.run.reach_skirmish()
	_h.run.reach_boss_fight()
	_h.run.defeat_boss()
	var clear: LevelClearScreen = _h.screen(&"LevelClear") as LevelClearScreen
	clear.continue_button().pressed.emit()
	var card: LevelIntroCard = _h.screen(&"LevelIntro") as LevelIntroCard
	var _next: GdUnitAssert = assert_str(card.lines()[0]).is_equal("LEVEL 2")
	var _state: GdUnitAssert = assert_int(_h.run.machine.state()).is_equal(
		GameState.Phase.LEVEL_INTRO
	)


func test_settings_screen_round_trips_the_store() -> void:
	_h.reach_title()
	_h.ui.open(&"settings")
	var screen: SettingsScreen = _h.screen(&"Settings") as SettingsScreen
	var controls: Dictionary[StringName, Control] = screen.controls()
	(controls[&"master"] as HSlider).value = 0.3
	(controls[&"rumble"] as CheckButton).button_pressed = false
	(controls[&"opacity"] as HSlider).value = 0.9
	var stored: GameSettings = _h.settings.current()
	var reloaded: Settings = Settings.new(_h.bus, _h.settings_store)
	reloaded.restore()
	var shown_after_restore: GameSettings = screen.shown()
	_button(&"Settings", "RESET").pressed.emit()
	var defaults: GameSettings = GameSettings.new()
	defaults.reduced_motion = false
	var _master: GdUnitAssert = assert_float(stored.master_volume).is_equal_approx(0.3, 0.001)
	var _rumble: GdUnitAssert = assert_bool(stored.rumble).is_false()
	var _opacity: GdUnitAssert = assert_float(stored.touch_stick_opacity).is_equal_approx(
		0.9, 0.001
	)
	var _round_trip: GdUnitAssert = assert_bool(shown_after_restore.equals(stored)).is_true()
	var _reset: GdUnitAssert = assert_bool(_h.settings.current().equals(defaults)).is_true()
	var _shown: GdUnitAssert = assert_float((controls[&"master"] as HSlider).value).is_equal_approx(
		GameSettings.DEFAULT_VOLUME, 0.001
	)


func test_scoreboard_shows_top_10_with_level_and_time() -> void:
	for i: int in 12:
		var _rank: int = _h.scoreboard.submit(ScoreEntry.new("ABC", 1000 * (i + 1), 3, 125.0))
	_h.reach_title()
	_h.bus.flow.announce_scoreboard_requested()
	var board: ScoreboardScreen = _h.screen(&"Scoreboard") as ScoreboardScreen
	var rows: PackedStringArray = board.row_lines()
	var _ten: GdUnitAssert = assert_int(rows.size()).is_equal(10)
	var _best: GdUnitAssert = assert_str(rows[0]).is_equal("1 ABC 12,000 3 02:05")
	var _tenth: GdUnitAssert = assert_str(rows[9]).is_equal("10 ABC 3,000 3 02:05")


func test_scoreboard_new_entry_pops_once() -> void:
	_h.reach_title()
	_h.bus.flow.announce_play_requested()
	_h.reach_game_over(2)
	(_h.screen(&"GameOver") as RunEndScreen).picker().submit()
	var board: ScoreboardScreen = _h.screen(&"Scoreboard") as ScoreboardScreen
	var highlighted: int = board.highlighted_rank()
	var pops_first: int = board.highlight_pops()
	_h.bus.flow.announce_title_requested()
	_h.bus.flow.announce_scoreboard_requested()
	var _rank: GdUnitAssert = assert_int(highlighted).is_equal(0)
	var _one_pop: GdUnitAssert = assert_int(pops_first).is_equal(1)
	var _still_one: GdUnitAssert = assert_int(board.highlight_pops()).is_equal(1)
	var _plain_later: GdUnitAssert = assert_int(board.highlighted_rank()).is_equal(-1)
	var _entry: GdUnitAssert = assert_str(board.row_lines()[0]).starts_with("1 AAA 200 1 ")


func test_victory_shows_final_tally_then_initials() -> void:
	_h.reach_title()
	_h.bus.flow.announce_game_state_changed(GameState.Phase.BOSS_FIGHT, GameState.Phase.VICTORY)
	_h.bus.run.announce_run_ended(RunSummary.new(250000, 6, 754.0, 321, true))
	_h.bus.profile.announce_scoreboard_qualified(0)
	var victory: RunEndScreen = _h.screen(&"Victory") as RunEndScreen
	var game_over: RunEndScreen = _h.screen(&"GameOver") as RunEndScreen
	var _tally: GdUnitAssert = assert_array(victory.tally().lines()).is_equal(
		["Score 250,000", "Level reached 6", "Time 12:34", "Kills 321"]
	)
	var _initials: GdUnitAssert = assert_bool(victory.is_asking_initials()).is_true()
	var _focus: GdUnitAssert = assert_bool(victory.picker().has_focus()).is_true()
	var _not_game_over: GdUnitAssert = assert_bool(game_over.is_asking_initials()).is_false()


func test_title_hint_follows_the_last_used_device() -> void:
	_h.reach_title()
	var title: TitleScreen = _h.screen(&"Title") as TitleScreen
	var hints: Array[String] = [title.hint_text()]
	for device: InputDevice.Kind in [
		InputDevice.Kind.GAMEPAD, InputDevice.Kind.TOUCH, InputDevice.Kind.KEYBOARD_MOUSE
	]:
		_h.bus.flow.announce_input_device_changed(device)
		hints.append(title.hint_text())
	var _hints: GdUnitAssert = (
		assert_array(hints)
		. is_equal(
			[
				"[Arrows] choose [Enter] select",
				"[D-pad] choose [A] select",
				"[Tap] to select",
				"[Click] to select",
			]
		)
	)


func test_credits_list_every_row_of_credits_md() -> void:
	var file: FileAccess = FileAccess.open("res://CREDITS.md", FileAccess.READ)
	var rows: int = 0
	for line: String in file.get_as_text().split("\n"):
		if (
			line.begins_with("| ")
			and not line.begins_with("| Asset")
			and not line.begins_with("| ---")
		):
			rows += 1
	_h.reach_title()
	_h.ui.open(&"credits")
	var credits: Array[PackedStringArray] = (_h.screen(&"Credits") as CreditsScreen).credits()
	var fonts: Array[String] = []
	for credit: PackedStringArray in credits:
		if credit[2] == "OFL 1.1":
			fonts.append(credit[0])
	var _all: GdUnitAssert = assert_int(credits.size()).is_equal(rows)
	var _plain: GdUnitAssert = assert_str(credits[0][1]).not_contains("](")
	var _fonts: GdUnitAssert = assert_int(fonts.size()).is_equal(2)


func test_credits_show_name_author_and_licence_text() -> void:
	_h.reach_title()
	_h.ui.open(&"credits")
	var screen: CreditsScreen = _h.screen(&"Credits") as CreditsScreen
	var with_paths: Array[String] = []
	for credit: PackedStringArray in screen.credits():
		for cell: String in credit:
			if cell.contains("`") or cell.contains("/") or cell.contains("()"):
				with_paths.append(cell)
	var licences: PackedStringArray = screen.licence_texts()
	var _no_paths: GdUnitAssert = assert_array(with_paths).is_empty()
	var _name: GdUnitAssert = assert_str(screen.credits()[0][0]).is_equal(
		"Orbitron, the display font"
	)
	var _author: GdUnitAssert = assert_str(screen.credits()[0][1]).is_equal(
		"The Orbitron Project Authors, via Google Fonts"
	)
	var _licence: GdUnitAssert = assert_str(screen.credits()[0][2]).is_equal("OFL 1.1")
	var _two: GdUnitAssert = assert_int(licences.size()).is_equal(2)
	var _ofl_a: GdUnitAssert = assert_str(licences[0]).contains("SIL Open Font License")
	var _ofl_b: GdUnitAssert = assert_str(licences[1]).contains("Chakra Petch")


func test_hud_gauge_hides_behind_level_intro_card() -> void:
	_h.reach_title()
	_h.bus.flow.announce_play_requested()
	var hud: Hud = _h.screen(&"Hud") as Hud
	var during_intro: bool = hud.gauge_shown()
	_h.run.advance(_h.run.levels[0].intro_duration + RunHarness.STEP)
	var _hidden: GdUnitAssert = assert_bool(during_intro).is_false()
	var _back: GdUnitAssert = assert_bool(hud.gauge_shown()).is_true()
