class_name UiInput
extends RefCounted
## How the screens read raw input events. Menus use Godot's ui_* actions
## (keyboard, gamepad), and the pointer reaches them through the GUI. Pause
## follows #73: Esc or P, gamepad Start, or the on-screen button. When the game's
## `pause` action exists (game/input, #22), it is honoured as well.

const PAUSE_ACTION: StringName = &"pause"
const PAUSE_KEYS: Array[Key] = [KEY_ESCAPE, KEY_P]


## True for a fresh press of a pause control.
static func is_pause(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and PAUSE_KEYS.has(key.physical_keycode):
			return true
	if event is InputEventJoypadButton:
		var pad: InputEventJoypadButton = event as InputEventJoypadButton
		if pad.pressed and pad.button_index == JOY_BUTTON_START:
			return true
	return InputMap.has_action(PAUSE_ACTION) and event.is_action_pressed(PAUSE_ACTION)


## True for a fresh press of Back (Esc, gamepad B, or whatever ui_cancel maps).
static func is_cancel(event: InputEvent) -> bool:
	return _is_pad_button(event, JOY_BUTTON_B) or event.is_action_pressed(&"ui_cancel", false, true)


## True for a fresh press of Confirm (Enter, Space, gamepad A, or ui_accept).
static func is_accept(event: InputEvent) -> bool:
	return _is_pad_button(event, JOY_BUTTON_A) or event.is_action_pressed(&"ui_accept", false, true)


static func _is_pad_button(event: InputEvent, button: JoyButton) -> bool:
	if event is InputEventJoypadButton:
		var pad: InputEventJoypadButton = event as InputEventJoypadButton
		return pad.pressed and pad.button_index == button
	return false


## True for any fresh press of a key, button, mouse button or touch: the Boot
## screen's "press anything".
static func is_any_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return key.pressed and not key.echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false
