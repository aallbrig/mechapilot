class_name DeviceDetector
extends RefCounted
## Decides which device the player used last, from the raw input events, so
## prompts can show matching glyphs (#73). Rules:
## - Touch: any screen touch or drag.
## - Keyboard + mouse: a real mouse button, or a mouse move of at least
##   MOUSE_SLOP pixels. Browsers send emulated mouse events after a touch, so
##   emulated events, and any mouse event within TOUCH_MOUSE_GRACE seconds of a
##   touch, are ignored.
## - Keyboard: a key press. In keyboard + mouse mode, keys that are not aim or
##   fire keys (WASD, pause, menus) keep that mode, since both modes move with WASD.
## - Gamepad: a button press, or a stick or trigger past PAD_THRESHOLD.

const MOUSE_SLOP: float = 2.0
const TOUCH_MOUSE_GRACE: float = 1.0
const PAD_THRESHOLD: float = 0.5
const KEYBOARD_ONLY_ACTIONS: Array[StringName] = [
	InputBindings.AIM_LEFT,
	InputBindings.AIM_RIGHT,
	InputBindings.AIM_UP,
	InputBindings.AIM_DOWN,
	InputBindings.FIRE,
]

var current: InputDevice.Kind = InputDevice.Kind.KEYBOARD
var _last_touch: float = -INF


## Update from one event at time `now` (seconds). True when the device changed.
func observe(event: InputEvent, now: float) -> bool:
	var kind: int = _classify(event, now)
	if kind < 0 or kind == current:
		return false
	current = kind as InputDevice.Kind
	return true


## The device `event` signals, or -1 when it says nothing about the device.
func _classify(event: InputEvent, now: float) -> int:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_last_touch = now
		return InputDevice.Kind.TOUCH
	if event is InputEventMouse:
		return _classify_mouse(event as InputEventMouse, now)
	if event is InputEventKey:
		return _classify_key(event as InputEventKey)
	if event is InputEventJoypadButton:
		return InputDevice.Kind.GAMEPAD if (event as InputEventJoypadButton).pressed else -1
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		return InputDevice.Kind.GAMEPAD if absf(motion.axis_value) >= PAD_THRESHOLD else -1
	return -1


func _classify_mouse(event: InputEventMouse, now: float) -> int:
	if event.device == InputEvent.DEVICE_ID_EMULATION or now - _last_touch < TOUCH_MOUSE_GRACE:
		return -1
	if event is InputEventMouseMotion:
		var moved: float = (event as InputEventMouseMotion).relative.length()
		return InputDevice.Kind.KEYBOARD_MOUSE if moved >= MOUSE_SLOP else -1
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		return InputDevice.Kind.KEYBOARD_MOUSE
	return -1


func _classify_key(event: InputEventKey) -> int:
	if not event.pressed or event.echo:
		return -1
	if current != InputDevice.Kind.KEYBOARD_MOUSE:
		return InputDevice.Kind.KEYBOARD
	for action: StringName in KEYBOARD_ONLY_ACTIONS:
		if InputMap.has_action(action) and InputMap.event_is_action(event, action, true):
			return InputDevice.Kind.KEYBOARD
	return -1
