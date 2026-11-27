class_name LevelClearScreen
extends UiScreen
## Level Clear (#73): the tally (kills, accuracy, Armor bonus, no-death bonus)
## counts up with sound, then "Press to continue" starts the next Level.
## Confirm during the count skips to the end.

var _header: Label
var _tally: TallyBoard
var _continue: Button
var _hint: GlyphHint
var _last: LevelTally = null


func _ready() -> void:
	var content: VBoxContainer = UiBuild.centered_panel(self)
	_header = UiBuild.label("LEVEL CLEAR", &"HeaderLabel")
	content.add_child(_header)
	_tally = TallyBoard.new()
	content.add_child(_tally)
	_continue = UiBuild.button("CONTINUE")
	_continue.visible = false
	if _continue.pressed.connect(_on_continue) != OK:
		push_error("LevelClearScreen: could not wire Continue")
	content.add_child(_continue)
	_hint = GlyphHint.new()
	content.add_child(_hint)
	if _tally.ticked.connect(cue.bind(UiCue.Cue.TICK)) != OK:
		push_error("LevelClearScreen: could not hear the tally")
	if _tally.finished.connect(_on_tally_finished) != OK:
		push_error("LevelClearScreen: could not hear the tally")


func default_focus() -> Control:
	return _continue if _continue.visible else null


## The tally board (for tests).
func tally() -> TallyBoard:
	return _tally


## The Continue button, shown once the tally has counted up.
func continue_button() -> Button:
	return _continue


func handle_cancel() -> bool:
	_tally.finish()
	return true


func _gui_input(event: InputEvent) -> void:
	if not _tally.is_finished() and (UiInput.is_accept(event) or UiInput.is_any_press(event)):
		accept_event()
		_tally.finish()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and not _tally.is_finished() and UiInput.is_any_press(event):
		_tally.finish()


func _subscribe() -> void:
	var _ok: bool = _require([_bus.run.level_cleared.connect(_on_level_cleared)])


func _on_level_cleared(cleared: LevelTally) -> void:
	_last = cleared


func _on_enter() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_continue.visible = false
	_hint.visible = false
	_tally.clear()
	if _last != null:
		_header.text = "LEVEL %d CLEAR" % _last.level_number
		_tally.add_row("Kills", _last.kills)
		_tally.add_row("Accuracy", _last.accuracy(), TallyBoard.Format.PERCENT)
		_tally.add_row("Armor bonus", _last.armor_bonus)
		_tally.add_row("No-death bonus", _last.no_death_bonus)
		_tally.add_row("Bonus total", _last.bonus_total())
	_tally.play()


func _on_device_changed() -> void:
	_hint.show_segments(InputGlyphs.continue_hint(_device))


func _on_tally_finished() -> void:
	cue(UiCue.Cue.TALLY_DONE)
	_continue.visible = true
	_hint.visible = true
	_on_device_changed()
	TweenFx.pop(_continue)
	if is_visible_in_tree():
		focus_default()


func _on_continue() -> void:
	_bus.flow.announce_continue_requested()
