class_name AudioUnlock
extends Node
## The audio gate (#73: the Boot screen's tap unlocks audio). Browsers start a
## page's audio suspended until a user gesture, and audio started before that
## logs console warnings, so nothing may play until the player's first press:
## a key, a mouse button or a touch, Events.flow.start_requested, or the Boot
## screen's UiCue.Cue.START (heard before the cue plays). On the web a gamepad
## button is not a user gesture to the browser, so it unlocks only the other
## platforms, and a Boot start made with one waits for the next real gesture.
## `unlocked` is reported once.

## The first gesture arrived: audio may play from now on.
signal unlocked

var _unlocked: bool = false
## Whether the latest press was a user gesture (a gamepad press on the web is not).
var _last_press_was_gesture: bool = true
var _on_web: bool = OS.has_feature("web")


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	handle_input(event)


## Subscribe to `bus` (the Events autoload, or a test bus).
func bind(bus: EventBus) -> void:
	(
		BusLinks
		. require_ok(
			"AudioUnlock",
			[
				bus.flow.start_requested.connect(_on_start_requested),
				bus.flow.ui_cue_requested.connect(_on_ui_cue_requested),
			]
		)
	)


## Treat the platform as the web (true) or not, for tests.
func assume_web(on_web: bool) -> void:
	_on_web = on_web


## Unlock if `event` is a user gesture.
func handle_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		_last_press_was_gesture = is_gesture(event, _on_web)
	if not _unlocked and is_gesture(event, _on_web):
		unlock()


func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	unlocked.emit()


func is_unlocked() -> bool:
	return _unlocked


func _on_start_requested() -> void:
	_unlock_from_screen()


func _on_ui_cue_requested(cue: UiCue.Cue) -> void:
	if cue == UiCue.Cue.START:
		_unlock_from_screen()


## The Boot screen started the game. It unlocks only if the press behind it was
## a user gesture: on the web a gamepad press is not, so the unlock waits for
## the next key, click or touch.
func _unlock_from_screen() -> void:
	if _last_press_was_gesture:
		unlock()


## True when `event` counts as a user gesture (on the web if `on_web`).
static func is_gesture(event: InputEvent, on_web: bool) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		return true
	return event is InputEventJoypadButton and not on_web
