class_name PauseScreen
extends UiScreen
## Pause (#73): Resume, Settings and Quit to Title. Quitting asks first
## ("Quit this Run?", focus on No), because it abandons the Run. Back, Esc,
## P or Start resume (or close the question).

var _menu: VBoxContainer
var _resume: Button
var _confirm: VBoxContainer
var _no: Button


func _ready() -> void:
	var content: VBoxContainer = UiBuild.centered_panel(self)
	content.add_child(UiBuild.label("PAUSED", &"HeaderLabel"))
	_menu = UiBuild.column()
	content.add_child(_menu)
	_resume = _add_button(_menu, "RESUME", _resume_run, UiCue.Cue.BACK)
	var _settings: Button = _add_button(_menu, "SETTINGS", _open.bind(&"settings"))
	var _quit: Button = _add_button(_menu, "QUIT TO TITLE", _ask_quit)
	_confirm = UiBuild.column()
	_confirm.visible = false
	content.add_child(_confirm)
	_confirm.add_child(UiBuild.paragraph("Quit this Run? Your score will not be saved."))
	var _yes: Button = _add_button(_confirm, "YES, QUIT", _quit_run)
	_no = _add_button(_confirm, "NO, KEEP FLYING", _close_question, UiCue.Cue.BACK)


func default_focus() -> Control:
	return _no if _confirm.visible else _resume


## True while the quit question is open.
func is_asking_to_quit() -> bool:
	return _confirm.visible


func handle_cancel() -> bool:
	if _confirm.visible:
		_close_question()
	else:
		_resume_run()
	return true


func _on_enter() -> void:
	_confirm.visible = false
	_menu.visible = true


func _ask_quit() -> void:
	_menu.visible = false
	_confirm.visible = true
	TweenFx.pop(_confirm)
	focus_default()


func _close_question() -> void:
	_confirm.visible = false
	_menu.visible = true
	focus_default()


func _resume_run() -> void:
	cue(UiCue.Cue.BACK)
	_bus.flow.announce_resume_requested()


func _quit_run() -> void:
	_bus.flow.announce_quit_to_title_requested()


func _open(target: StringName) -> void:
	request_navigate(target)


func _add_button(
	parent: Control, text: String, action: Callable, press_cue: UiCue.Cue = UiCue.Cue.CONFIRM
) -> Button:
	var made: Button = UiBuild.button(text)
	if made.pressed.connect(action) != OK:
		push_error("PauseScreen: could not wire %s" % text)
	parent.add_child(made)
	juice(made, press_cue)
	return made
