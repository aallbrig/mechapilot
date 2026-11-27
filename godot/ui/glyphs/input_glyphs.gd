class_name InputGlyphs
extends RefCounted
## The control names to show for each kind of device (#73 Controls), so every
## prompt matches the device the player used last. A prompt is a list of
## segments: a glyph (drawn as a key cap) followed by the words it explains.
## Glyphs are plain words, so they never depend on icon art or font coverage.

## The chip on a tutorial tip that has no control to show.
const TIP: String = "TIP"


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


## The movement control.
static func move(device: InputDevice.Kind) -> String:
	match device:
		InputDevice.Kind.GAMEPAD:
			return "Left stick"
		InputDevice.Kind.TOUCH:
			return "Left thumb"
		_:
			return "WASD"


## How to aim and fire with this device (#73 Controls).
static func aim_and_fire(device: InputDevice.Kind) -> Array[Segment]:
	match device:
		InputDevice.Kind.GAMEPAD:
			return [Segment.new("Right stick", "aim and fire"), Segment.new("RT", "fire ahead")]
		InputDevice.Kind.TOUCH:
			return [
				Segment.new("Tap right", "fire there"), Segment.new("Hold right", "aim and fire")
			]
		InputDevice.Kind.KEYBOARD_MOUSE:
			return [Segment.new("Mouse", "aim"), Segment.new("Click", "fire")]
		_:
			return [Segment.new("Arrows", "aim and fire"), Segment.new("Space", "fire ahead")]


## Every flight control of this device: move, aim and fire, pause.
static func every_control(device: InputDevice.Kind) -> Array[Segment]:
	var segments: Array[Segment] = [Segment.new(move(device), "move")]
	segments.append_array(aim_and_fire(device))
	segments.append(Segment.new(pause(device), "pause"))
	return segments


## A first-flight tutorial prompt for this device.
static func tutorial(prompt: TutorialPrompt.Id, device: InputDevice.Kind) -> Array[Segment]:
	match prompt:
		TutorialPrompt.Id.MOVE:
			return [Segment.new(move(device), "move")]
		TutorialPrompt.Id.AIM_AND_FIRE:
			return aim_and_fire(device)
		TutorialPrompt.Id.SHOTS_DROP:
			return [Segment.new(TIP, "Shots drop, so aim above distant targets")]
		TutorialPrompt.Id.BOSS_GAUGE:
			return [Segment.new(TIP, "Fill the Boss Gauge to summon the boss")]
		TutorialPrompt.Id.REPAIR_KITS:
			return [Segment.new(TIP, "Grab repair kits: fly through them for +30 Armor")]
		_:
			return [Segment.new(TIP, "Boss incoming: watch for glowing attacks")]


## The "press to continue" prompt.
static func continue_hint(device: InputDevice.Kind) -> Array[Segment]:
	return [Segment.new(confirm(device), "to continue")]
