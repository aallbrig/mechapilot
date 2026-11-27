class_name BootScreen
extends UiScreen
## Boot (#73): "tap or press to start". The first press anywhere, with any
## device, starts the game. That press is the user gesture browsers need to
## unlock audio; on a phone or tablet browser it also goes fullscreen.

const TITLE: String = "MECHA\nFIGHTER"
const PROMPT: String = "TAP OR PRESS ANY KEY"
const PULSE_AMOUNT: float = 0.06
const PULSE_PERIOD: float = 1.2
const MOBILE_WEB_FEATURES: Array[String] = ["web_android", "web_ios"]

var _prompt: Label
var _pulse: Tween
var _started: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var content: VBoxContainer = UiBuild.column(40)
	UiBuild.centered(self).add_child(content)
	content.add_child(UiBuild.label(TITLE, &"TitleLabel"))
	_prompt = UiBuild.paragraph(PROMPT, &"HeaderLabel")
	content.add_child(_prompt)


## Starts the game, once (the screen's whole job).
func start() -> void:
	if _started:
		return
	_started = true
	cue(UiCue.Cue.START)
	TweenFx.punch(_prompt, TweenFx.PUNCH_AMOUNT)
	if _is_mobile_web():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_bus.flow.announce_start_requested()


## True once start() has run.
func has_started() -> bool:
	return _started


## The prompt shown.
func prompt_text() -> String:
	return _prompt.text


func _on_enter() -> void:
	_started = false
	if _pulse != null:
		_pulse.kill()
	_pulse = TweenFx.pulse(_prompt, PULSE_AMOUNT, PULSE_PERIOD)


func _on_leave() -> void:
	if _pulse != null:
		_pulse.kill()
		_pulse = null


func _gui_input(event: InputEvent) -> void:
	if UiInput.is_any_press(event):
		accept_event()
		start()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and UiInput.is_any_press(event):
		start()


static func _is_mobile_web() -> bool:
	for feature: String in MOBILE_WEB_FEATURES:
		if OS.has_feature(feature):
			return true
	return false
