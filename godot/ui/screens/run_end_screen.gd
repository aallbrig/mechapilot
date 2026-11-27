class_name RunEndScreen
extends UiScreen
## Game Over and Victory (#73): the Run's final tally counts up; then, if the
## score placed on the Scoreboard (profile.scoreboard_qualified), the initials
## picker; confirming saves the entry (profile.initials_submitted) and opens
## the Scoreboard. A Run that did not place offers Play Again (a new Run), the
## Scoreboard and the Title.
##
## The rules announce game_state_changed first, then run_ended and
## scoreboard_qualified in the same frame, in whichever order the listeners
## were connected. So entering the screen resets it, and it shows initials
## whenever the tally is done, the Run qualified and nothing was submitted yet.

## True for the Victory screen, false for Game Over.
@export var victory: bool = false

var _header: Label
var _tally: TallyBoard
var _picker: InitialsPicker
var _picker_title: Label
var _actions: VBoxContainer
var _play_again: Button
var _summary: RunSummary = null
var _qualified: bool = false
var _submitted: bool = false


func _ready() -> void:
	var content: VBoxContainer = UiBuild.centered_panel(self)
	_header = UiBuild.label("VICTORY" if victory else "GAME OVER", &"HeaderLabel")
	content.add_child(_header)
	_tally = TallyBoard.new()
	content.add_child(_tally)
	_picker_title = UiBuild.label("NEW HIGH SCORE! ENTER YOUR INITIALS", &"HintLabel")
	_picker_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_picker_title.custom_minimum_size = Vector2(UiBuild.COLUMN_WIDTH, 0.0)
	content.add_child(_picker_title)
	_picker = InitialsPicker.new()
	content.add_child(_picker)
	_actions = UiBuild.column()
	content.add_child(_actions)
	_play_again = _action("PLAY AGAIN", _on_play_again)
	var _board: Button = _action("SCOREBOARD", _on_scoreboard)
	var _title: Button = _action("TITLE", _on_title)
	_wire(_tally.ticked.connect(cue.bind(UiCue.Cue.TICK)))
	_wire(_tally.finished.connect(_on_tally_finished))
	_wire(_picker.submitted.connect(_on_initials))
	_wire(_picker.letter_changed.connect(_on_letter_changed))
	for button: BaseButton in _picker.buttons():
		juice(button)
	_show_stage()


func default_focus() -> Control:
	if _picker.visible:
		return _picker
	if _actions.visible:
		return _play_again
	return null


## The initials picker (for tests).
func picker() -> InitialsPicker:
	return _picker


## The Play Again button.
func play_again_button() -> Button:
	return _play_again


## The tally board.
func tally() -> TallyBoard:
	return _tally


## True while the initials picker is shown.
func is_asking_initials() -> bool:
	return _picker.visible


func handle_cancel() -> bool:
	if not _tally.is_finished():
		_tally.finish()
	return true


func _gui_input(event: InputEvent) -> void:
	if not _tally.is_finished() and UiInput.is_any_press(event):
		accept_event()
		_tally.finish()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and not _tally.is_finished() and UiInput.is_any_press(event):
		_tally.finish()


func _subscribe() -> void:
	var _ok: bool = _require(
		[
			_bus.run.run_started.connect(_on_run_started),
			_bus.run.run_ended.connect(_on_run_ended),
			_bus.profile.scoreboard_qualified.connect(_on_scoreboard_qualified),
		]
	)


func _on_run_started(_level_number: int) -> void:
	_summary = null
	_qualified = false
	_submitted = false


func _on_run_ended(summary: RunSummary) -> void:
	# The rules enter Game Over or Victory before announcing the Run's end, so
	# only the screen on show takes it: a hidden screen never keeps a stale Run.
	if summary.victory != victory or not is_visible_in_tree():
		return
	_summary = summary
	_start_tally()


func _on_scoreboard_qualified(_rank: int) -> void:
	if not is_visible_in_tree():
		return
	_qualified = true
	_show_stage()


func _on_enter() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_summary = null
	_qualified = false
	_submitted = false
	_start_tally()


func _start_tally() -> void:
	_tally.clear()
	_picker.reset()
	if _summary != null:
		_tally.add_row("Score", _summary.score)
		_tally.add_row("Level reached", _summary.level_reached)
		_tally.add_text_row("Time", _summary.formatted_time())
		_tally.add_row("Kills", _summary.kills)
	_show_stage()
	_tally.play()


func _on_tally_finished() -> void:
	cue(UiCue.Cue.TALLY_DONE)
	_show_stage()


func _show_stage() -> void:
	var counted: bool = _tally.is_finished() and _summary != null
	var asking: bool = counted and _qualified and not _submitted
	var was_asking: bool = _picker.visible
	var had_actions: bool = _actions.visible
	_picker.visible = asking
	_picker_title.visible = asking
	# The initials replace the counted tally, so both fit a landscape phone.
	_tally.visible = not asking
	if asking:
		_picker_title.text = (
			"NEW HIGH SCORE %s! ENTER YOUR INITIALS" % UiFormat.score(_summary.score)
		)
	_actions.visible = counted and not asking
	if not is_visible_in_tree():
		return
	if asking and not was_asking:
		TweenFx.pop(_picker)
		cue(UiCue.Cue.POP)
		focus_default()
	elif _actions.visible and not had_actions:
		var items: Array[Control] = []
		for child: Node in _actions.get_children():
			items.append(child as Control)
		stagger_in(items)
		focus_default()


func _on_initials(initials: String) -> void:
	if _submitted:
		return
	_submitted = true
	cue(UiCue.Cue.CONFIRM)
	_bus.profile.announce_initials_submitted(initials)
	_bus.flow.announce_scoreboard_requested()


func _on_letter_changed(_slot: int, _letter: String) -> void:
	cue(UiCue.Cue.LETTER)


func _on_play_again() -> void:
	_bus.flow.announce_play_requested()


func _on_scoreboard() -> void:
	_bus.flow.announce_scoreboard_requested()


func _on_title() -> void:
	_bus.flow.announce_title_requested()


func _action(text: String, action: Callable) -> Button:
	var made: Button = UiBuild.button(text)
	_wire(made.pressed.connect(action))
	_actions.add_child(made)
	return made


func _wire(result: int) -> void:
	if result != OK:
		push_error("RunEndScreen: could not wire a control: %s" % error_string(result))
