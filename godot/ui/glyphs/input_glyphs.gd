class_name InputGlyphs
extends RefCounted
## The control names to show for each kind of device (#73 Controls), so every
## prompt matches the device the player used last. A prompt is a list of
## segments: a glyph (drawn as a key cap) followed by the words it explains.
## Glyphs are plain words, so they never depend on icon art or font coverage.


## One glyph and what it does, e.g. ("Enter", "select").
class Segment:
	extends RefCounted
	var glyph: String = ""
	var words: String = ""

	func _init(segment_glyph: String, segment_words: String) -> void:
		glyph = segment_glyph
		words = segment_words


## The confirm control: Enter, A, a tap or a click.
static func confirm(device: InputDevice.Kind) -> String:
	match device:
		InputDevice.Kind.GAMEPAD:
			return "A"
		InputDevice.Kind.TOUCH:
			return "Tap"
		InputDevice.Kind.KEYBOARD_MOUSE:
			return "Click"
		_:
			return "Enter"


## The back control: Esc, B, or the on-screen Back button.
static func back(device: InputDevice.Kind) -> String:
	match device:
		InputDevice.Kind.GAMEPAD:
			return "B"
		InputDevice.Kind.TOUCH:
			return "Back"
		_:
			return "Esc"


## The pause control.
static func pause(device: InputDevice.Kind) -> String:
	match device:
		InputDevice.Kind.GAMEPAD:
			return "Start"
		InputDevice.Kind.TOUCH:
			return "II"
		_:
			return "Esc"


## The menu-choosing control.
static func navigate(device: InputDevice.Kind) -> String:
	match device:
		InputDevice.Kind.GAMEPAD:
			return "D-pad"
		InputDevice.Kind.TOUCH:
			return "Tap"
		InputDevice.Kind.KEYBOARD_MOUSE:
			return "Mouse"
		_:
			return "Arrows"


## The Title's hint line: how to choose and select with this device.
static func select_hint(device: InputDevice.Kind) -> Array[Segment]:
	if device == InputDevice.Kind.TOUCH or device == InputDevice.Kind.KEYBOARD_MOUSE:
		return [Segment.new(confirm(device), "to select")]
	return [Segment.new(navigate(device), "choose"), Segment.new(confirm(device), "select")]


## The "press to continue" prompt.
static func continue_hint(device: InputDevice.Kind) -> Array[Segment]:
	return [Segment.new(confirm(device), "to continue")]
