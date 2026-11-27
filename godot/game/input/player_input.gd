class_name PlayerInput
extends Node
## Reads every device into one PilotIntent per frame and tracks the last-used
## device. Keyboard, mouse and gamepad come through the InputMap (InputBindings).
##
## Touch seam (#25): the touch controls call set_touch_sticks() with their
## sticks, request_tap_shot() for a quick tap and clear_touch() on leaving play.
## Nothing else about touch lives here, beyond the device detector noticing
## screen events.

## The last-used device changed (also published on the Events bus, see PlayerBusLink).
signal device_changed(device: InputDevice.Kind)

## Stick or key aim shorter than this keeps the last aim.
const AIM_THRESHOLD: float = 0.1
## A touch aim stick shorter than this does not fire.
const TOUCH_AIM_THRESHOLD: float = 0.15
const USEC_PER_SECOND: float = 1_000_000.0

var _detector: DeviceDetector = DeviceDetector.new()
var _mouse_point: Vector2 = Vector2.ZERO
var _touch_move: Vector2 = Vector2.ZERO
var _touch_aim: Vector2 = Vector2.ZERO
var _tap_pending: bool = false
var _tap_point: Vector2 = Vector2.ZERO


func _init() -> void:
	InputBindings.install()


func _input(event: InputEvent) -> void:
	handle_event(event, Time.get_ticks_usec() / USEC_PER_SECOND)


## Feed one raw event observed at `now` seconds (the engine calls this through _input).
func handle_event(event: InputEvent, now: float) -> void:
	if event is InputEventMouseMotion:
		_mouse_point = (event as InputEventMouseMotion).position
	if _detector.observe(event, now):
		device_changed.emit(_detector.current)


func current_device() -> InputDevice.Kind:
	return _detector.current


## Touch seam: the virtual sticks, in world terms (x right, y up), length at most 1.
## The move stick never fires; the aim stick fires along its direction.
func set_touch_sticks(move: Vector2, aim: Vector2) -> void:
	_touch_move = move.limit_length(1.0)
	_touch_aim = aim.limit_length(1.0)


## Touch seam: fire one shot at `screen_point` on the next read.
func request_tap_shot(screen_point: Vector2) -> void:
	_tap_pending = true
	_tap_point = screen_point


## Touch seam: forget the sticks and any pending tap (the controls left play).
func clear_touch() -> void:
	_touch_move = Vector2.ZERO
	_touch_aim = Vector2.ZERO
	_tap_pending = false


func read_intent() -> PilotIntent:
	var intent: PilotIntent = PilotIntent.new()
	var keys_and_pad: Vector2 = Input.get_vector(
		InputBindings.MOVE_LEFT,
		InputBindings.MOVE_RIGHT,
		InputBindings.MOVE_DOWN,
		InputBindings.MOVE_UP
	)
	intent.move = (keys_and_pad + _touch_move).limit_length(1.0)
	var aim: Vector2 = Input.get_vector(
		InputBindings.AIM_LEFT,
		InputBindings.AIM_RIGHT,
		InputBindings.AIM_DOWN,
		InputBindings.AIM_UP
	)
	if aim.length() > AIM_THRESHOLD:
		intent.aim = aim.normalized()
		intent.firing = true
	elif _touch_aim.length() > TOUCH_AIM_THRESHOLD:
		intent.aim = _touch_aim.normalized()
		intent.firing = true
	if Input.is_action_pressed(InputBindings.FIRE):
		intent.firing = true
	if _detector.current == InputDevice.Kind.KEYBOARD_MOUSE and intent.aim == Vector2.ZERO:
		intent.has_aim_point = true
		intent.aim_point = _mouse_point
	if _tap_pending:
		intent.has_tap = true
		intent.tap_point = _tap_point
		_tap_pending = false
	return intent
