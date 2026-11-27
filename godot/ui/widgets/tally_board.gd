class_name TallyBoard
extends GridContainer
## A tally that counts up (#73 Level Clear, Game Over and Victory): rows of a
## name and a number, each counting from 0 to its value in turn, ticking as it
## goes. finish() skips to the end. Text rows (a time) appear without counting.

## A counter moved on (for the owner's tick sound).
signal ticked
## Every row has reached its value.
signal finished

enum Format { NUMBER, PERCENT, TEXT }

const ROW_TIME: float = 0.55
const TICKS_PER_ROW: int = 8
const VALUE_PUNCH: float = 0.15
const NAME_WIDTH: float = 220.0
const VALUE_WIDTH: float = 240.0

var _names: Array[String] = []
var _targets: Array[float] = []
var _formats: Array[Format] = []
var _texts: Array[String] = []
var _value_labels: Array[Label] = []
var _row: int = 0
var _last_tick: int = 0
var _tween: Tween
var _done: bool = true


func _init() -> void:
	columns = 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"h_separation", 24)
	add_theme_constant_override(&"v_separation", 6)


## Removes every row.
func clear() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_names.clear()
	_targets.clear()
	_formats.clear()
	_texts.clear()
	_value_labels.clear()
	_done = true


## Adds a counted row: `value` shown as a number or a percentage (0 to 1).
func add_row(row_name: String, value: float, format: Format = Format.NUMBER) -> void:
	_add(row_name, value, format, "")


## Adds a row whose value is fixed text.
func add_text_row(row_name: String, text: String) -> void:
	_add(row_name, 0.0, Format.TEXT, text)


## Starts counting from the first row. With reduced motion, it finishes at once.
func play() -> void:
	_done = false
	_row = 0
	if TweenFx.reduced_motion:
		finish()
		return
	for i: int in _value_labels.size():
		_value_labels[i].text = _format(i, 0.0)
	_play_row()


## Jumps every row to its value and finishes.
func finish() -> void:
	if _done:
		return
	if _tween != null:
		_tween.kill()
		_tween = null
	for i: int in _value_labels.size():
		_value_labels[i].text = _format(i, 1.0)
	_done = true
	finished.emit()


## True once every row shows its value.
func is_finished() -> bool:
	return _done


## The rows as "name value" lines (for tests).
func lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for i: int in _value_labels.size():
		var _added: bool = out.append("%s %s" % [_names[i], _value_labels[i].text])
	return out


func _add(row_name: String, value: float, format: Format, text: String) -> void:
	var name_label: Label = UiBuild.label(row_name, &"BodyLabel")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.custom_minimum_size = Vector2(NAME_WIDTH, 0.0)
	var value_label: Label = UiBuild.label("", &"TallyLabel")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(VALUE_WIDTH, 0.0)
	add_child(name_label)
	add_child(value_label)
	_names.append(row_name)
	_targets.append(value)
	_formats.append(format)
	_texts.append(text)
	_value_labels.append(value_label)


func _play_row() -> void:
	if _done:
		return
	if _row >= _value_labels.size():
		_done = true
		finished.emit()
		return
	_last_tick = 0
	var time: float = 0.0 if _formats[_row] == Format.TEXT else ROW_TIME
	_tween = TweenFx.count(self, time, _step, _row_done)


func _step(t: float) -> void:
	if _done or _row >= _value_labels.size():
		return
	_value_labels[_row].text = _format(_row, t)
	var tick: int = floori(t * TICKS_PER_ROW)
	if tick > _last_tick:
		_last_tick = tick
		ticked.emit()


func _row_done() -> void:
	if _done:
		return
	_value_labels[_row].text = _format(_row, 1.0)
	TweenFx.punch(_value_labels[_row], VALUE_PUNCH)
	ticked.emit()
	_row += 1
	_play_row()


func _format(row: int, t: float) -> String:
	match _formats[row]:
		Format.PERCENT:
			return UiFormat.percent(_targets[row] * t)
		Format.TEXT:
			return _texts[row]
		_:
			return UiFormat.score(roundi(_targets[row] * t))
