extends GdUnitTestSuite
## The touch overlay (#25, #73): it shows only on a touch screen and only in
## play; the sticks show only while held, at the Settings opacity; the
## on-screen pause button pauses and stays clear of the sticks; and taps reach
## menus and the initials picker as clicks, while emulated clicks never fire.

const LEFT_POINT: Vector2 = Vector2(200.0, 400.0)
const RIGHT_POINT: Vector2 = Vector2(750.0, 400.0)
const FINGER: int = 0
const OTHER_FINGER: int = 1
const OPACITY: float = 0.35

var _h: TouchHarness


func before_test() -> void:
	_h = TouchHarness.new()
	add_child(_h.holder)
	_h.settle()


func after_test() -> void:
	_h.dispose()


func test_touch_controls_hidden_without_touch() -> void:
	_h.start(false)
	_h.press(FINGER, LEFT_POINT)
	_h.drag(FINGER, LEFT_POINT + Vector2(TouchSticks.STICK_RANGE, 0.0))
	_h.press(OTHER_FINGER, RIGHT_POINT)
	_h.release(OTHER_FINGER, RIGHT_POINT)
	_h.fly(0.1)
	var intent: PilotIntent = _h.input.read_intent()
	var _hidden: GdUnitAssert = assert_bool(_h.controls.visible).is_false()
	var _no_pause: GdUnitAssert = assert_bool(_h.controls.is_pause_button_shown()).is_false()
	var _no_stick: GdUnitAssert = assert_bool(_h.controls.is_move_stick_shown()).is_false()
	var _no_move: GdUnitAssert = assert_vector(intent.move).is_equal(Vector2.ZERO)
	var _no_shots: GdUnitAssert = assert_int(_h.shots.size()).is_equal(0)


func test_touch_controls_show_only_in_play() -> void:
	_h.attach()
	var before_play: bool = _h.controls.visible
	_h.bus.flow.announce_game_state_changed(GameState.Phase.TITLE, GameState.Phase.LEVEL_INTRO)
	var in_play: bool = _h.controls.visible and _h.controls.is_pause_button_shown()
	_h.bus.flow.announce_game_state_changed(GameState.Phase.BOSS_FIGHT, GameState.Phase.GAME_OVER)
	var _not_on_title: GdUnitAssert = assert_bool(before_play).is_false()
	var _shown_in_play: GdUnitAssert = assert_bool(in_play).is_true()
	var _hidden_after: GdUnitAssert = assert_bool(_h.controls.visible).is_false()


func test_stick_visuals_show_only_while_held_at_the_settings_opacity() -> void:
	_h.start()
	var settings: GameSettings = GameSettings.new()
	settings.touch_stick_opacity = OPACITY
	_h.bus.profile.announce_settings_changed(settings)
	var idle: bool = _h.controls.is_move_stick_shown() or _h.controls.is_aim_stick_shown()
	_h.press(FINGER, LEFT_POINT)
	_h.press(OTHER_FINGER, RIGHT_POINT)
	var move_on_touch: bool = _h.controls.is_move_stick_shown()
	var aim_before_hold: bool = _h.controls.is_aim_stick_shown()
	_h.fly(TouchSticks.TAP_TIME + 0.1)
	var aim_held: bool = _h.controls.is_aim_stick_shown()
	_h.release(FINGER, LEFT_POINT)
	_h.release(OTHER_FINGER, RIGHT_POINT)
	var released: bool = _h.controls.is_move_stick_shown() or _h.controls.is_aim_stick_shown()
	var _idle_hidden: GdUnitAssert = assert_bool(idle).is_false()
	var _move_shown: GdUnitAssert = assert_bool(move_on_touch).is_true()
	var _tap_is_not_a_stick: GdUnitAssert = assert_bool(aim_before_hold).is_false()
	var _aim_shown: GdUnitAssert = assert_bool(aim_held).is_true()
	var _gone: GdUnitAssert = assert_bool(released).is_false()
	var _opacity: GdUnitAssert = assert_float(_h.controls.stick_opacity()).is_equal_approx(
		OPACITY, 0.001
	)


func test_pause_button_pauses() -> void:
	var run: RunHarness = RunHarness.new()
	_h.attach(true, run.bus)
	run.start_run()
	var playing: GameState.Phase = run.machine.state()
	var button: Rect2 = _h.controls.pause_button_rect()
	_h.press(FINGER, button.get_center())
	_h.release(FINGER, button.get_center())
	var paused: GameState.Phase = run.machine.state()
	var intent: PilotIntent = _h.input.read_intent()
	var shown_while_paused: bool = _h.controls.visible
	run.dispose()
	var _was_playing: GdUnitAssert = assert_bool(GameState.is_play(playing)).is_true()
	var _paused: GdUnitAssert = assert_int(paused).is_equal(GameState.Phase.PAUSED)
	var _not_a_shot: GdUnitAssert = assert_bool(intent.has_tap or intent.firing).is_false()
	var _hidden: GdUnitAssert = assert_bool(shown_while_paused).is_false()


func test_pause_button_is_clear_of_the_sticks() -> void:
	_h.start()
	var button: Rect2 = _h.controls.pause_button_rect()
	var screen: Vector2 = TouchHarness.SCREEN
	var top_right: Rect2 = Rect2(screen * Vector2(0.5, 0.0), screen * 0.5)
	var _in_corner: GdUnitAssert = assert_bool(top_right.encloses(button)).is_true()
	var _thumb_sized: GdUnitAssert = (
		assert_float(minf(button.size.x, button.size.y)).is_greater_equal(TouchControls.PAUSE_SIZE)
	)
	# A touch that starts on the pause button never becomes a stick or a shot.
	_h.press(FINGER, button.get_center())
	_h.drag(FINGER, button.get_center() + Vector2(-80.0, 80.0))
	_h.fly(TouchSticks.TAP_TIME + 0.1)
	_h.release(FINGER, button.get_center())
	_h.fly(0.1)
	var _no_stick: GdUnitAssert = assert_bool(_h.controls.is_aim_stick_shown()).is_false()
	var _no_shots: GdUnitAssert = assert_int(_h.shots.size()).is_equal(0)


func test_emulated_mouse_from_a_touch_never_fires() -> void:
	InputBindings.install()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.device = InputEvent.DEVICE_ID_EMULATION
	var _not_fire: GdUnitAssert = (
		assert_bool(InputMap.event_is_action(click, InputBindings.FIRE, true)).is_false()
	)


func test_menus_receive_taps_as_clicks() -> void:
	var emulates: bool = ProjectSettings.get_setting(
		"input_devices/pointing/emulate_mouse_from_touch", false
	)
	var _taps_click: GdUnitAssert = assert_bool(emulates).is_true()
