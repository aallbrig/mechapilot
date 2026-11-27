extends GdUnitTestSuite
## Every screen works with every device (#24, #73): focus defaults for keyboard
## and gamepad, Back from sub-screens, the confirmed quit, the Boot press, and
## hover, focus and press juice with sound on every interactive control.

var _h: UiHarness


func before_test() -> void:
	_h = UiHarness.new()
	add_child(_h.host)


func after_test() -> void:
	_h.dispose()


func _key(code: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	return key


func _focused(screen_name: StringName) -> String:
	for control: Control in _h.screen(screen_name).juiced_controls():
		if control.has_focus():
			if control is Button:
				return (control as Button).text
			return str(control.name)
	return ""


## Every control under `root` that a player can focus or press.
func _interactive(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in root.get_children():
		if (
			child is BaseButton
			or (child is Control and (child as Control).focus_mode != Control.FOCUS_NONE)
		):
			found.append(child as Control)
		found.append_array(_interactive(child))
	return found


func test_ui_default_focus_per_screen() -> void:
	_h.reach_title()
	var title: String = _focused(&"Title")
	_h.ui.open(&"settings")
	var settings_focus: bool = (
		(_h.screen(&"Settings") as SettingsScreen).default_focus().has_focus()
	)
	_h.ui.close_top()
	var title_again: String = _focused(&"Title")
	_h.ui.open(&"credits")
	var credits: String = _focused(&"Credits")
	_h.ui.close_top()
	_h.bus.flow.announce_play_requested()
	_h.run.advance(_h.run.levels[0].intro_duration + RunHarness.STEP)
	var in_play: String = _focused(&"Hud")
	_h.bus.flow.announce_pause_requested()
	var paused: String = _focused(&"Pause")
	_h.bus.flow.announce_resume_requested()
	_h.reach_game_over(1)
	var picker_focused: bool = (_h.screen(&"GameOver") as RunEndScreen).picker().has_focus()
	var _title: GdUnitAssert = assert_str(title).is_equal("PLAY")
	var _settings: GdUnitAssert = assert_bool(settings_focus).is_true()
	var _back: GdUnitAssert = assert_str(title_again).is_equal("PLAY")
	var _credits: GdUnitAssert = assert_str(credits).is_equal("BACK")
	var _play: GdUnitAssert = assert_str(in_play).is_empty()
	var _pause: GdUnitAssert = assert_str(paused).is_equal("RESUME")
	var _initials: GdUnitAssert = assert_bool(picker_focused).is_true()


func test_scoreboard_focus_starts_on_play() -> void:
	_h.reach_title()
	_h.bus.flow.announce_scoreboard_requested()
	var _play: GdUnitAssert = assert_str(_focused(&"Scoreboard")).is_equal("PLAY")


func test_back_closes_sub_screens_with_every_device() -> void:
	_h.reach_title()
	_h.ui.open(&"settings")
	_h.ui._gui_input(_key(KEY_ESCAPE))
	var after_escape: Array[StringName] = _h.ui.visible_screens()
	_h.ui.open(&"credits")
	var pad_back: InputEventJoypadButton = InputEventJoypadButton.new()
	pad_back.button_index = JOY_BUTTON_B
	pad_back.pressed = true
	_h.ui._gui_input(pad_back)
	var after_pad: Array[StringName] = _h.ui.visible_screens()
	_h.ui.open(&"settings")
	var back: Button = null
	for control: Control in _h.screen(&"Settings").juiced_controls():
		if control is Button and (control as Button).text == "BACK":
			back = control as Button
	back.pressed.emit()
	var _esc: GdUnitAssert = assert_array(after_escape).is_equal([&"Title"])
	var _pad: GdUnitAssert = assert_array(after_pad).is_equal([&"Title"])
	var _touch: GdUnitAssert = assert_array(_h.ui.visible_screens()).is_equal([&"Title"])


func test_pause_settings_and_resume_by_key() -> void:
	_h.reach_title()
	_h.bus.flow.announce_play_requested()
	_h.ui._unhandled_input(_key(KEY_P))
	var paused: GameState.Phase = _h.run.machine.state()
	_h.ui.open(&"settings")
	var over_pause: Array[StringName] = _h.ui.visible_screens()
	_h.ui._gui_input(_key(KEY_ESCAPE))
	var back_on_pause: Array[StringName] = _h.ui.visible_screens()
	var start: InputEventJoypadButton = InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	_h.ui._gui_input(start)
	var _paused: GdUnitAssert = assert_int(paused).is_equal(GameState.Phase.PAUSED)
	var _over: GdUnitAssert = assert_array(over_pause).is_equal([&"Settings"])
	var _back: GdUnitAssert = assert_array(back_on_pause).is_equal([&"Pause"])
	var _resumed: GdUnitAssert = assert_int(_h.run.machine.state()).is_equal(
		GameState.Phase.LEVEL_INTRO
	)


func test_pause_button_pauses_for_touch() -> void:
	_h.reach_title()
	_h.bus.flow.announce_play_requested()
	(_h.screen(&"Hud") as Hud).pause_button().pressed.emit()
	var _paused: GdUnitAssert = assert_int(_h.run.machine.state()).is_equal(GameState.Phase.PAUSED)


func test_pause_quit_asks_for_confirmation() -> void:
	var ended: Array[RunSummary] = _h.run.run_summaries
	_h.reach_title()
	_h.bus.flow.announce_play_requested()
	_h.bus.flow.announce_pause_requested()
	var pause: PauseScreen = _h.screen(&"Pause") as PauseScreen
	var quit: Button = null
	for control: Control in pause.juiced_controls():
		if control is Button and (control as Button).text == "QUIT TO TITLE":
			quit = control as Button
	quit.pressed.emit()
	var asking: bool = pause.is_asking_to_quit()
	var no_focused: bool = (pause.default_focus() as Button).text == "NO, KEEP FLYING"
	var still_paused: GameState.Phase = _h.run.machine.state()
	_h.ui._gui_input(_key(KEY_ESCAPE))
	var closed: bool = not pause.is_asking_to_quit()
	quit.pressed.emit()
	for control: Control in pause.juiced_controls():
		if control is Button and (control as Button).text == "YES, QUIT":
			(control as Button).pressed.emit()
	var _asks: GdUnitAssert = assert_bool(asking).is_true()
	var _safe_default: GdUnitAssert = assert_bool(no_focused).is_true()
	var _not_yet: GdUnitAssert = assert_int(still_paused).is_equal(GameState.Phase.PAUSED)
	var _cancel: GdUnitAssert = assert_bool(closed).is_true()
	var _quit: GdUnitAssert = assert_int(_h.run.machine.state()).is_equal(GameState.Phase.TITLE)
	var _abandoned: GdUnitAssert = assert_array(ended).is_empty()


func test_boot_press_starts_game_with_any_device() -> void:
	var presses: Array[InputEvent] = [_key(KEY_SPACE)]
	var tap: InputEventScreenTouch = InputEventScreenTouch.new()
	tap.pressed = true
	presses.append(tap)
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	presses.append(pad)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	presses.append(click)
	var reached: Array[GameState.Phase] = []
	for press: InputEvent in presses:
		var h: UiHarness = UiHarness.new()
		add_child(h.host)
		h.boot()
		var boot: BootScreen = h.screen(&"Boot") as BootScreen
		boot._unhandled_input(press)
		reached.append(h.run.machine.state())
		var started_cue: bool = h.cues.has(UiCue.Cue.START)
		h.dispose()
		if not started_cue:
			reached.append(GameState.Phase.BOOT)
	var _all: GdUnitAssert = assert_array(reached).is_equal(
		[GameState.Phase.TITLE, GameState.Phase.TITLE, GameState.Phase.TITLE, GameState.Phase.TITLE]
	)


func test_every_control_has_hover_focus_and_press_juice() -> void:
	_h.reach_title()
	var unjuiced: Array[String] = []
	for screen_node: UiScreen in _h.ui.screens():
		var juiced: Array[Control] = screen_node.juiced_controls()
		for control: Control in _interactive(screen_node):
			if not juiced.has(control):
				unjuiced.append("%s/%s" % [screen_node.name, control.name])
	var _all: GdUnitAssert = assert_array(unjuiced).is_empty()


func test_hover_focus_and_press_animate_and_sound() -> void:
	_h.reach_title()
	TweenFx.reduced_motion = false
	var title: TitleScreen = _h.screen(&"Title") as TitleScreen
	var credits: Button = null
	for control: Control in title.juiced_controls():
		if control is Button and (control as Button).text == "CREDITS":
			credits = control as Button
	_h.cues.clear()
	credits.mouse_entered.emit()
	await await_millis(300)
	var hover_scale: float = credits.scale.x
	var hover_focused: bool = credits.has_focus()
	var hover_cues: Array[UiCue.Cue] = _h.cues.duplicate()
	credits.button_down.emit()
	await await_millis(150)
	var press_scale: float = credits.scale.x
	credits.pressed.emit()
	var _grew: GdUnitAssert = assert_float(hover_scale).is_equal_approx(TweenFx.HOVER_SCALE, 0.01)
	var _hover_focus: GdUnitAssert = assert_bool(hover_focused).is_true()
	var _focus_cue: GdUnitAssert = assert_array(hover_cues).contains([UiCue.Cue.FOCUS])
	var _squashed: GdUnitAssert = assert_float(press_scale).is_equal_approx(
		TweenFx.PRESS_SCALE, 0.01
	)
	var _press_cue: GdUnitAssert = assert_array(_h.cues).contains([UiCue.Cue.CONFIRM])
	var _opened: GdUnitAssert = assert_array(_h.ui.visible_screens()).is_equal([&"Credits"])


func test_reduced_motion_setting_stops_juice_motion() -> void:
	_h.reach_title()
	var wanted: GameSettings = _h.settings.current()
	wanted.reduced_motion = false
	_h.bus.profile.announce_settings_change_requested(wanted)
	var motion_on: bool = TweenFx.reduced_motion
	wanted.reduced_motion = true
	_h.bus.profile.announce_settings_change_requested(wanted)
	var play: Button = (_h.screen(&"Title") as TitleScreen).default_focus() as Button
	play.button_down.emit()
	var _was_on: GdUnitAssert = assert_bool(motion_on).is_false()
	var _now_off: GdUnitAssert = assert_bool(TweenFx.reduced_motion).is_true()
	var _no_squash: GdUnitAssert = assert_float(play.scale.x).is_equal_approx(1.0, 0.001)


## The real input path: each press goes through a viewport (Viewport.push_input:
## _input, GUI focus, then _unhandled_input), so a key seen by two handlers
## would show up as a pause followed by an immediate resume.
func test_esc_p_and_start_pause_once_through_the_viewport() -> void:
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(UiHarness.LANDSCAPE)
	viewport.gui_disable_input = false
	add_child(viewport)
	_h.host.reparent(viewport)
	_h.reach_title()
	_h.bus.flow.announce_play_requested()
	_h.run.advance(_h.run.levels[0].intro_duration + RunHarness.STEP)
	var start: InputEventJoypadButton = InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	var seen: Array[String] = []
	for press: InputEvent in [_key(KEY_ESCAPE), _key(KEY_P), start]:
		viewport.push_input(press)
		await await_idle_frame()
		seen.append(GameState.Phase.keys()[_h.run.machine.state()])
		viewport.push_input(press)
		await await_idle_frame()
		seen.append(GameState.Phase.keys()[_h.run.machine.state()])
	var _once_each: GdUnitAssert = assert_array(seen).is_equal(
		["PAUSED", "SKIRMISH", "PAUSED", "SKIRMISH", "PAUSED", "SKIRMISH"]
	)
