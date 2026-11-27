class_name ScoreboardScreen
extends UiScreen
## The Scoreboard (#73): the local top 10 (rank, initials, score, Level
## reached, time as mm:ss), from profile.scoreboard_changed. A newly saved
## entry is highlighted and pops once, the first time it is shown. Play starts
## a new Run; Back returns to the Title.

const CAPACITY: int = 10
const COLUMN_WIDTHS: Array[float] = [44.0, 80.0, 180.0, 50.0, 90.0]
const ROW_STAGGER: float = 0.04
## Ten rows must fit a 640 UI pixel high landscape screen.
const COMPACT_GAP: int = 8
const HIGHLIGHT_DELAY: float = 0.45
const HIGHLIGHT_PUNCH: float = 0.25
const EMPTY_TEXT: String = "No scores yet. Go fly!"

var _rows_box: VBoxContainer
var _play: Button
var _entries: Array[ScoreEntry] = []
var _highlight: int = -1
var _shown_highlight: int = -1
var _pops: int = 0


func _ready() -> void:
	var content: VBoxContainer = UiBuild.centered_panel(self)
	content.add_theme_constant_override(&"separation", COMPACT_GAP)
	content.add_child(UiBuild.label("SCOREBOARD", &"HeaderLabel"))
	content.add_child(_row(["#", "NAME", "SCORE", "LVL", "TIME"], &"HintLabel"))
	_rows_box = UiBuild.column(0)
	content.add_child(_rows_box)
	var actions: HBoxContainer = UiBuild.row()
	content.add_child(actions)
	_play = _button(actions, "PLAY", _on_play)
	var back: Button = _button(actions, "BACK", _on_back)
	juice(back, UiCue.Cue.BACK)


func default_focus() -> Control:
	return _play


func handle_cancel() -> bool:
	_on_back()
	return true


## The rows shown, as "rank initials score level time" lines.
func row_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for row_panel: Node in _rows_box.get_children():
		var parts: PackedStringArray = []
		for cell: Node in row_panel.get_child(0).get_children():
			var _added: bool = parts.append((cell as Label).text)
		var _line: bool = lines.append(" ".join(parts))
	return lines


## The rank highlighted on screen, or -1.
func highlighted_rank() -> int:
	return _shown_highlight


## How many times a new entry's highlight has popped.
func highlight_pops() -> int:
	return _pops


func _subscribe() -> void:
	var _ok: bool = _require([_bus.profile.scoreboard_changed.connect(_on_scoreboard_changed)])


func _on_scoreboard_changed(entries: Array[ScoreEntry], highlight_rank: int) -> void:
	_entries = entries.duplicate()
	_highlight = highlight_rank
	if is_visible_in_tree():
		_render()


func _on_enter() -> void:
	_render()


func _render() -> void:
	for child: Node in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_shown_highlight = _highlight
	if _entries.is_empty():
		_rows_box.add_child(UiBuild.label(EMPTY_TEXT, &"BodyLabel"))
	var items: Array[Control] = []
	for i: int in mini(_entries.size(), CAPACITY):
		var entry: ScoreEntry = _entries[i]
		var cells: Array[String] = [
			"%d" % (i + 1),
			entry.initials,
			UiFormat.score(entry.score),
			"%d" % entry.level_reached,
			entry.formatted_time(),
		]
		var row_panel: PanelContainer = _row(cells, &"BodyLabel")
		row_panel.theme_type_variation = &"RowHighlight" if i == _highlight else &"RowPlain"
		_rows_box.add_child(row_panel)
		items.append(row_panel)
	for i: int in items.size():
		TweenFx.fade_in(items[i], TweenFx.SLIDE_TIME, ROW_STAGGER * i)
	if _highlight >= 0 and _highlight < items.size():
		_pop_highlight(items[_highlight])
	# The highlight pops once: later visits show the board without it.
	_highlight = -1


func _pop_highlight(row_panel: Control) -> void:
	_pops += 1
	cue(UiCue.Cue.POP)
	var tween: Tween = TweenFx.make(row_panel)
	var _wait: IntervalTweener = tween.tween_interval(
		0.0 if TweenFx.reduced_motion else HIGHLIGHT_DELAY
	)
	var _pop: CallbackTweener = tween.tween_callback(
		TweenFx.punch.bind(row_panel, HIGHLIGHT_PUNCH, TweenFx.PUNCH_TIME)
	)


func _row(cells: Array[String], variation: StringName) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"RowPlain"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = UiBuild.row(10)
	panel.add_child(line)
	for i: int in cells.size():
		var cell: Label = UiBuild.label(cells[i], variation)
		cell.custom_minimum_size = Vector2(COLUMN_WIDTHS[i], 0.0)
		cell.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_RIGHT if i == 2 else HORIZONTAL_ALIGNMENT_CENTER
		)
		line.add_child(cell)
	return panel


func _button(parent: Control, text: String, action: Callable) -> Button:
	var made: Button = UiBuild.button(text)
	made.custom_minimum_size = Vector2(
		UiBuild.COLUMN_WIDTH * 0.5 - UiBuild.GAP, UiBuild.BUTTON_HEIGHT
	)
	if made.pressed.connect(action) != OK:
		push_error("ScoreboardScreen: could not wire %s" % text)
	parent.add_child(made)
	return made


func _on_play() -> void:
	_bus.flow.announce_play_requested()


func _on_back() -> void:
	cue(UiCue.Cue.BACK)
	_bus.flow.announce_title_requested()
