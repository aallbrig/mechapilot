class_name InitialsPicker
extends VBoxContainer
## Three-letter initials entry for the Scoreboard (#24, #73), for every device:
##
## - Keyboard and gamepad (while focused): Up is the previous letter (A wraps
##   to Z), Down the next one (A to B, Z wraps to A); Left and Right choose the slot;
##   typing a letter sets the slot and moves on; Backspace moves back; Confirm
##   submits.
## - Mouse and touch: the arrows above and below each letter, a tap on a letter
##   to choose its slot, and the OK button.

## The player confirmed these three letters.
signal submitted(initials: String)
## A letter changed (for the owner's sound cue).
signal letter_changed(slot: int, letter: String)

const ALPHABET: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const LENGTH: int = 3
const ACTIVE_COLOR: Color = Color(1.0, 0.85, 0.2)
const IDLE_COLOR: Color = Color(1.0, 1.0, 1.0)
const LETTER_PUNCH: float = 0.25
const SLOT_WIDTH: float = 110.0

var _letters: Array[int] = [0, 0, 0]
var _slot: int = 0
var _letter_labels: Array[Label] = []
var _up_buttons: Array[ArrowButton] = []
var _down_buttons: Array[ArrowButton] = []
var _ok: Button


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", UiBuild.GAP)
	var slots: HBoxContainer = UiBuild.row(24)
	add_child(slots)
	for i: int in LENGTH:
		var slot_column: VBoxContainer = UiBuild.column(4)
		slot_column.custom_minimum_size = Vector2(SLOT_WIDTH, 0.0)
		var up: ArrowButton = ArrowButton.new(true)
		_wire(up.pressed.connect(bump.bind(i, -1)))
		var letter: Label = UiBuild.label("A", &"LetterLabel")
		letter.mouse_filter = Control.MOUSE_FILTER_STOP
		_wire(letter.gui_input.connect(_on_letter_input.bind(i)))
		var down: ArrowButton = ArrowButton.new(false)
		_wire(down.pressed.connect(bump.bind(i, 1)))
		slot_column.add_child(up)
		slot_column.add_child(letter)
		slot_column.add_child(down)
		slots.add_child(slot_column)
		_letter_labels.append(letter)
		_up_buttons.append(up)
		_down_buttons.append(down)
	_ok = UiBuild.button("OK")
	_ok.focus_mode = Control.FOCUS_NONE
	_wire(_ok.pressed.connect(submit))
	add_child(_ok)
	_refresh()


## Back to "AAA", first slot.
func reset() -> void:
	_letters = [0, 0, 0]
	_slot = 0
	_refresh()


## The three letters shown.
func initials() -> String:
	var out: String = ""
	for index: int in _letters:
		out += ALPHABET[index]
	return out


## The slot being edited (0 to 2).
func slot() -> int:
	return _slot


## The arrow buttons and OK button, for the owner's juice.
func buttons() -> Array[BaseButton]:
	var all: Array[BaseButton] = []
	all.append_array(_up_buttons)
	all.append_array(_down_buttons)
	all.append(_ok)
	return all


## Moves `slot`'s letter by `step` (+1 is the next letter), wrapping Z and A.
func bump(at_slot: int, step: int) -> void:
	_slot = clampi(at_slot, 0, LENGTH - 1)
	_letters[_slot] = posmod(_letters[_slot] + step, ALPHABET.length())
	_changed()


## Up: the previous letter in the current slot (A wraps to Z) (#134).
func letter_up() -> void:
	bump(_slot, -1)


## Down: the next letter in the current slot (A to B, Z wraps to A) (#134).
func letter_down() -> void:
	bump(_slot, 1)


## Moves to the slot `step` away, staying within the three slots.
func move_slot(step: int) -> void:
	_slot = clampi(_slot + step, 0, LENGTH - 1)
	_refresh()


## Sets the current slot to `letter` (A to Z, any case) and moves on.
func type_letter(letter: String) -> void:
	var index: int = ALPHABET.find(letter.to_upper())
	if index < 0 or letter.length() != 1:
		return
	_letters[_slot] = index
	var typed_slot: int = _slot
	_slot = mini(_slot + 1, LENGTH - 1)
	_punch(typed_slot)
	letter_changed.emit(typed_slot, ALPHABET[index])
	_refresh()


## Confirms the initials.
func submit() -> void:
	submitted.emit(initials())


func _gui_input(event: InputEvent) -> void:
	if _handle_key(event):
		accept_event()


func _handle_key(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode >= KEY_A and key.keycode <= KEY_Z:
				type_letter(ALPHABET[key.keycode - KEY_A])
				return true
			if key.keycode == KEY_BACKSPACE:
				move_slot(-1)
				return true
	if event.is_action_pressed(&"ui_up", true, true):
		letter_up()
	elif event.is_action_pressed(&"ui_down", true, true):
		letter_down()
	elif event.is_action_pressed(&"ui_left", false, true):
		move_slot(-1)
	elif event.is_action_pressed(&"ui_right", false, true):
		move_slot(1)
	elif UiInput.is_accept(event):
		submit()
	else:
		return false
	return true


func _on_letter_input(event: InputEvent, at_slot: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_slot = at_slot
		grab_focus()
		_refresh()


func _changed() -> void:
	_punch(_slot)
	letter_changed.emit(_slot, ALPHABET[_letters[_slot]])
	_refresh()


func _punch(at_slot: int) -> void:
	TweenFx.punch(_letter_labels[at_slot], LETTER_PUNCH)


func _refresh() -> void:
	for i: int in LENGTH:
		_letter_labels[i].text = ALPHABET[_letters[i]]
		_letter_labels[i].modulate = ACTIVE_COLOR if i == _slot else IDLE_COLOR


func _wire(result: int) -> void:
	if result != OK:
		push_error("InitialsPicker: could not wire a control: %s" % error_string(result))
