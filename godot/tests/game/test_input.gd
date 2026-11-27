extends GdUnitTestSuite
## Input: the InputMap per device (keyboard, keyboard plus mouse, gamepad), the
## last-used device, and the pilot intent the mech reads (#22, #73).

const NOW: float = 100.0

var _devices: Array[InputDevice.Kind] = []


func before() -> void:
	InputBindings.install()


func _key(code: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	return ev


func _pad_button(button: JoyButton) -> InputEventJoypadButton:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


func _pad_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev


func _mouse_button(button: MouseButton) -> InputEventMouseButton:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


func _mouse_move(relative: Vector2) -> InputEventMouseMotion:
	var ev: InputEventMouseMotion = InputEventMouseMotion.new()
	ev.relative = relative
	ev.position = Vector2(400.0, 300.0)
	return ev


func _touch() -> InputEventScreenTouch:
	var ev: InputEventScreenTouch = InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = Vector2(100.0, 100.0)
	return ev


## Every action `event` triggers, as names.
func _actions(event: InputEvent) -> Array[StringName]:
	var hits: Array[StringName] = []
	for action: StringName in InputBindings.ACTIONS:
		if InputMap.event_is_action(event, action, true):
			hits.append(action)
	return hits


func test_keyboard_bindings_move_aim_fire_and_pause() -> void:
	var _w: GdUnitAssert = assert_array(_actions(_key(KEY_W))).contains_exactly(["move_up"])
	var _a: GdUnitAssert = assert_array(_actions(_key(KEY_A))).contains_exactly(["move_left"])
	var _s: GdUnitAssert = assert_array(_actions(_key(KEY_S))).contains_exactly(["move_down"])
	var _d: GdUnitAssert = assert_array(_actions(_key(KEY_D))).contains_exactly(["move_right"])
	var _up: GdUnitAssert = assert_array(_actions(_key(KEY_UP))).contains_exactly(["aim_up"])
	var _left: GdUnitAssert = assert_array(_actions(_key(KEY_LEFT))).contains_exactly(["aim_left"])
	var _down: GdUnitAssert = assert_array(_actions(_key(KEY_DOWN))).contains_exactly(["aim_down"])
	var _right: GdUnitAssert = assert_array(_actions(_key(KEY_RIGHT))).contains_exactly(
		["aim_right"]
	)
	var _space: GdUnitAssert = assert_array(_actions(_key(KEY_SPACE))).contains(["fire"])
	var _esc: GdUnitAssert = assert_array(_actions(_key(KEY_ESCAPE))).contains(
		["pause", "ui_cancel"]
	)
	var _p: GdUnitAssert = assert_array(_actions(_key(KEY_P))).contains_exactly(["pause"])
	var _enter: GdUnitAssert = assert_array(_actions(_key(KEY_ENTER))).contains(["ui_accept"])


func test_mouse_binding_fires_with_the_left_button() -> void:
	var left: Array[StringName] = _actions(_mouse_button(MOUSE_BUTTON_LEFT))
	var right: Array[StringName] = _actions(_mouse_button(MOUSE_BUTTON_RIGHT))
	var _fires: GdUnitAssert = assert_array(left).contains_exactly(["fire"])
	var _only_left: GdUnitAssert = assert_array(right).is_empty()


func test_gamepad_bindings_sticks_dpad_trigger_and_buttons() -> void:
	var _lx: GdUnitAssert = (
		assert_array(_actions(_pad_axis(JOY_AXIS_LEFT_X, 1.0))).contains_exactly(["move_right"])
	)
	var _ly: GdUnitAssert = (
		assert_array(_actions(_pad_axis(JOY_AXIS_LEFT_Y, -1.0))).contains_exactly(["move_up"])
	)
	var _dpad: GdUnitAssert = assert_array(_actions(_pad_button(JOY_BUTTON_DPAD_LEFT))).contains(
		["move_left"]
	)
	var _rx: GdUnitAssert = (
		assert_array(_actions(_pad_axis(JOY_AXIS_RIGHT_X, -1.0))).contains_exactly(["aim_left"])
	)
	var _ry: GdUnitAssert = (
		assert_array(_actions(_pad_axis(JOY_AXIS_RIGHT_Y, 1.0))).contains_exactly(["aim_down"])
	)
	var _rt: GdUnitAssert = (
		assert_array(_actions(_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))).contains_exactly(["fire"])
	)
	var _start: GdUnitAssert = (
		assert_array(_actions(_pad_button(JOY_BUTTON_START))).contains_exactly(["pause"])
	)
	var _a: GdUnitAssert = assert_array(_actions(_pad_button(JOY_BUTTON_A))).contains(["ui_accept"])
	var _b: GdUnitAssert = assert_array(_actions(_pad_button(JOY_BUTTON_B))).contains(["ui_cancel"])


func test_gamepad_bindings_match_any_connected_pad() -> void:
	var second_pad: InputEventJoypadButton = _pad_button(JOY_BUTTON_START)
	second_pad.device = 3
	var _any_pad: GdUnitAssert = assert_array(_actions(second_pad)).contains_exactly(["pause"])


func test_install_is_idempotent() -> void:
	var before_count: int = InputMap.action_get_events(&"fire").size()
	InputBindings.install()
	var after_count: int = InputMap.action_get_events(&"fire").size()
	var _same: GdUnitAssert = assert_int(after_count).is_equal(before_count)


func test_detects_the_last_used_device() -> void:
	var detector: DeviceDetector = DeviceDetector.new()
	var seen: Array[InputDevice.Kind] = []
	var events: Array[InputEvent] = [
		_mouse_move(Vector2(30.0, 0.0)),
		_pad_button(JOY_BUTTON_A),
		_key(KEY_UP),
		_touch(),
	]
	for ev: InputEvent in events:
		var _changed: bool = detector.observe(ev, NOW)
		seen.append(detector.current)
	var _order: GdUnitAssert = (
		assert_array(seen)
		. is_equal(
			[
				InputDevice.Kind.KEYBOARD_MOUSE,
				InputDevice.Kind.GAMEPAD,
				InputDevice.Kind.KEYBOARD,
				InputDevice.Kind.TOUCH,
			]
		)
	)


func test_device_change_is_reported_once() -> void:
	var detector: DeviceDetector = DeviceDetector.new()
	var first: bool = detector.observe(_pad_button(JOY_BUTTON_A), NOW)
	var again: bool = detector.observe(_pad_button(JOY_BUTTON_B), NOW)
	var _changed: GdUnitAssert = assert_bool(first).is_true()
	var _unchanged: GdUnitAssert = assert_bool(again).is_false()


func test_move_keys_keep_keyboard_and_mouse_mode() -> void:
	var detector: DeviceDetector = DeviceDetector.new()
	var _m: bool = detector.observe(_mouse_move(Vector2(30.0, 0.0)), NOW)
	var _w: bool = detector.observe(_key(KEY_W), NOW)
	var with_wasd: InputDevice.Kind = detector.current
	var _arrow: bool = detector.observe(_key(KEY_LEFT), NOW)
	var with_arrows: InputDevice.Kind = detector.current
	var _kept: GdUnitAssert = assert_int(with_wasd).is_equal(InputDevice.Kind.KEYBOARD_MOUSE)
	var _switched: GdUnitAssert = assert_int(with_arrows).is_equal(InputDevice.Kind.KEYBOARD)


func test_stick_noise_and_mouse_jitter_do_not_switch_device() -> void:
	var detector: DeviceDetector = DeviceDetector.new()
	var _noise: bool = detector.observe(_pad_axis(JOY_AXIS_LEFT_X, 0.1), NOW)
	var _jitter: bool = detector.observe(_mouse_move(Vector2(0.5, 0.0)), NOW)
	var _kept: GdUnitAssert = assert_int(detector.current).is_equal(InputDevice.Kind.KEYBOARD)


func test_emulated_mouse_after_touch_is_ignored() -> void:
	var detector: DeviceDetector = DeviceDetector.new()
	var _t: bool = detector.observe(_touch(), NOW)
	var emulated: InputEventMouseButton = _mouse_button(MOUSE_BUTTON_LEFT)
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	var _e: bool = detector.observe(emulated, NOW + 2.0)
	var _compat: bool = detector.observe(_mouse_button(MOUSE_BUTTON_LEFT), NOW + 0.3)
	var still_touch: InputDevice.Kind = detector.current
	var _real: bool = detector.observe(_mouse_move(Vector2(30.0, 0.0)), NOW + 2.0)
	var _ignored: GdUnitAssert = assert_int(still_touch).is_equal(InputDevice.Kind.TOUCH)
	var _later_mouse: GdUnitAssert = assert_int(detector.current).is_equal(
		InputDevice.Kind.KEYBOARD_MOUSE
	)


func test_player_input_announces_device_changes() -> void:
	var input: PlayerInput = PlayerInput.new()
	add_child(input)
	var err: Error = input.device_changed.connect(_record_device) as Error
	input.handle_event(_pad_button(JOY_BUTTON_A), NOW)
	input.handle_event(_pad_button(JOY_BUTTON_B), NOW)
	input.free()
	var _connected: GdUnitAssert = assert_int(err).is_equal(OK)
	var _announced_once: GdUnitAssert = assert_array(_devices).is_equal([InputDevice.Kind.GAMEPAD])


func _record_device(device: InputDevice.Kind) -> void:
	_devices.append(device)


func test_intent_reads_move_and_aim_actions() -> void:
	var input: PlayerInput = PlayerInput.new()
	add_child(input)
	Input.action_press(&"move_right")
	Input.action_press(&"aim_up")
	var intent: PilotIntent = input.read_intent()
	Input.action_release(&"move_right")
	Input.action_release(&"aim_up")
	var idle: PilotIntent = input.read_intent()
	input.free()
	var _move: GdUnitAssert = assert_vector(intent.move).is_equal_approx(
		Vector2.RIGHT, Vector2.ONE * 1e-5
	)
	var _aim: GdUnitAssert = assert_vector(intent.aim).is_equal_approx(
		Vector2(0.0, 1.0), Vector2.ONE * 1e-5
	)
	var _fires: GdUnitAssert = assert_bool(intent.firing).is_true()
	var _idle_move: GdUnitAssert = assert_vector(idle.move).is_equal(Vector2.ZERO)
	var _idle_fire: GdUnitAssert = assert_bool(idle.firing).is_false()


func test_fire_button_fires_along_the_last_aim() -> void:
	var input: PlayerInput = PlayerInput.new()
	add_child(input)
	Input.action_press(&"fire")
	var intent: PilotIntent = input.read_intent()
	Input.action_release(&"fire")
	input.free()
	var _fires: GdUnitAssert = assert_bool(intent.firing).is_true()
	var _last_aim: GdUnitAssert = assert_vector(intent.aim).is_equal(Vector2.ZERO)


func test_touch_sticks_feed_the_intent() -> void:
	var input: PlayerInput = PlayerInput.new()
	add_child(input)
	input.set_touch_sticks(Vector2(0.0, 0.5), Vector2(-1.0, 0.0))
	var held: PilotIntent = input.read_intent()
	input.set_touch_sticks(Vector2.ZERO, Vector2.ZERO)
	input.request_tap_shot(Vector2(320.0, 200.0))
	var tapped: PilotIntent = input.read_intent()
	var after_tap: PilotIntent = input.read_intent()
	input.free()
	var _move: GdUnitAssert = assert_vector(held.move).is_equal_approx(
		Vector2(0.0, 0.5), Vector2.ONE * 1e-5
	)
	var _aim: GdUnitAssert = assert_vector(held.aim).is_equal_approx(
		Vector2.LEFT, Vector2.ONE * 1e-5
	)
	var _fires: GdUnitAssert = assert_bool(held.firing).is_true()
	var _tap: GdUnitAssert = assert_bool(tapped.has_tap).is_true()
	var _tap_at: GdUnitAssert = assert_vector(tapped.tap_point).is_equal(Vector2(320.0, 200.0))
	var _once: GdUnitAssert = assert_bool(after_tap.has_tap).is_false()


func test_mouse_mode_aims_at_the_cursor() -> void:
	var input: PlayerInput = PlayerInput.new()
	add_child(input)
	input.handle_event(_mouse_move(Vector2(30.0, 0.0)), NOW)
	var intent: PilotIntent = input.read_intent()
	input.free()
	var _aims_at_cursor: GdUnitAssert = assert_bool(intent.has_aim_point).is_true()
	var _at: GdUnitAssert = assert_vector(intent.aim_point).is_equal(Vector2(400.0, 300.0))
