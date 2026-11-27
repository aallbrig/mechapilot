class_name InputBindings
extends RefCounted
## The InputMap for every non-touch device, defined once in code so it is
## reviewable and tested (#73 Controls):
##
## | Device           | Move               | Aim and fire                            | Pause    |
## | Keyboard         | WASD               | arrow keys fire while held; Space fires | Esc or P |
## |                  |                    | along the last aim                      |          |
## | Keyboard + mouse | WASD               | the cursor aims, left button fires      | Esc or P |
## | Gamepad          | left stick, D-pad  | right stick aims and fires; RT fires    | Start    |
## |                  |                    | along the last aim                      |          |
##
## Menus use Godot's ui_accept (Enter, gamepad A) and ui_cancel (Esc, gamepad B),
## which install() makes sure are bound. Keys use physical codes, so WASD stays
## under the same fingers on any layout. Gamepad events match every pad.
## Touch (#25) does not use the InputMap: it feeds PlayerInput.set_touch_sticks().

const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const MOVE_UP: StringName = &"move_up"
const MOVE_DOWN: StringName = &"move_down"
const AIM_LEFT: StringName = &"aim_left"
const AIM_RIGHT: StringName = &"aim_right"
const AIM_UP: StringName = &"aim_up"
const AIM_DOWN: StringName = &"aim_down"
const FIRE: StringName = &"fire"
const PAUSE: StringName = &"pause"
const UI_ACCEPT: StringName = &"ui_accept"
const UI_CANCEL: StringName = &"ui_cancel"
## Every action this game binds.
const ACTIONS: Array[StringName] = [
	MOVE_LEFT,
	MOVE_RIGHT,
	MOVE_UP,
	MOVE_DOWN,
	AIM_LEFT,
	AIM_RIGHT,
	AIM_UP,
	AIM_DOWN,
	FIRE,
	PAUSE,
	UI_ACCEPT,
	UI_CANCEL,
]
## Stick travel below which an axis action stays released.
const MOVE_DEADZONE: float = 0.2
const AIM_DEADZONE: float = 0.3
const TRIGGER_DEADZONE: float = 0.4
const BUTTON_DEADZONE: float = 0.5
## Matches every connected gamepad.
const ALL_DEVICES: int = -1


## Add every action and binding that is missing. Safe to call more than once.
static func install() -> void:
	_bind(
		MOVE_LEFT,
		MOVE_DEADZONE,
		[_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0), _pad(JOY_BUTTON_DPAD_LEFT)]
	)
	_bind(
		MOVE_RIGHT,
		MOVE_DEADZONE,
		[_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0), _pad(JOY_BUTTON_DPAD_RIGHT)]
	)
	_bind(
		MOVE_UP,
		MOVE_DEADZONE,
		[_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0), _pad(JOY_BUTTON_DPAD_UP)]
	)
	_bind(
		MOVE_DOWN,
		MOVE_DEADZONE,
		[_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0), _pad(JOY_BUTTON_DPAD_DOWN)]
	)
	_bind(AIM_LEFT, AIM_DEADZONE, [_key(KEY_LEFT), _axis(JOY_AXIS_RIGHT_X, -1.0)])
	_bind(AIM_RIGHT, AIM_DEADZONE, [_key(KEY_RIGHT), _axis(JOY_AXIS_RIGHT_X, 1.0)])
	_bind(AIM_UP, AIM_DEADZONE, [_key(KEY_UP), _axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_bind(AIM_DOWN, AIM_DEADZONE, [_key(KEY_DOWN), _axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_bind(
		FIRE,
		TRIGGER_DEADZONE,
		[_key(KEY_SPACE), _mouse(MOUSE_BUTTON_LEFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)]
	)
	_bind(PAUSE, BUTTON_DEADZONE, [_key(KEY_ESCAPE), _key(KEY_P), _pad(JOY_BUTTON_START)])
	_bind(UI_ACCEPT, BUTTON_DEADZONE, [_key(KEY_ENTER), _key(KEY_KP_ENTER), _pad(JOY_BUTTON_A)])
	_bind(UI_CANCEL, BUTTON_DEADZONE, [_key(KEY_ESCAPE), _pad(JOY_BUTTON_B)])


static func _bind(action: StringName, deadzone: float, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	for ev: InputEvent in events:
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)


static func _key(code: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = code
	return ev


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = button
	return ev


static func _pad(button: JoyButton) -> InputEventJoypadButton:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = ALL_DEVICES
	return ev


static func _axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = direction
	ev.device = ALL_DEVICES
	return ev
