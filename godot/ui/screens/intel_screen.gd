class_name IntelScreen
extends UiScreen
## Intel, the enemy and boss codex (#73, #75): a turntable preview, the name,
## a one-line description, hit points and points for each entry. An entry
## stays "???" until it is first encountered in play (core/intel_codex.gd
## decides and persists that; this screen only hears profile.intel_*).
## Opened from the Title; Left and Right (or Prev and Next) choose the entry.

const LOCKED: String = "???"
const LOCKED_DESCRIPTION: String = "Not encountered yet. Fly to find out."
const ENTRY_FLIP: Vector2 = Vector2(60.0, 0.0)

## Prev, Back and Next share one row.
const NAV_WIDTH: float = 160.0

var _entries: Array[IntelEntry] = []
var _unlocked: Array[StringName] = []
var _index: int = 0
var _entry_box: VBoxContainer
var _name: Label
var _preview: TurntablePreview
var _description: Label
var _stats: Label
var _counter: Label
var _next: Button


func _ready() -> void:
	var content: VBoxContainer = UiBuild.centered_panel(self)
	content.add_theme_constant_override(&"separation", 10)
	_counter = UiBuild.label("INTEL", &"HintLabel")
	content.add_child(_counter)
	_entry_box = UiBuild.column(8)
	content.add_child(_entry_box)
	_name = UiBuild.label(LOCKED, &"HeaderLabel")
	_preview = TurntablePreview.new()
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_description = UiBuild.paragraph("")
	_stats = UiBuild.label("", &"HintLabel")
	for item: Control in [_name, _preview, _description, _stats]:
		_entry_box.add_child(item)
	var nav: HBoxContainer = UiBuild.row()
	content.add_child(nav)
	var _prev: Button = _nav_button(nav, "PREV", choose.bind(-1))
	var back: Button = _nav_button(nav, "BACK", request_back)
	juice(back, UiCue.Cue.BACK)
	_next = _nav_button(nav, "NEXT", choose.bind(1))
	_show_entry()


func default_focus() -> Control:
	return _next


func handle_cancel() -> bool:
	request_back()
	return true


## Moves `step` entries along (wrapping).
func choose(step: int) -> void:
	if _entries.is_empty():
		return
	_index = posmod(_index + step, _entries.size())
	_show_entry()
	TweenFx.slide_in(_entry_box, ENTRY_FLIP * signf(step))


## Shows the entry with `id`, if the catalog has it.
func select(id: StringName) -> void:
	for i: int in _entries.size():
		if _entries[i].id == id:
			_index = i
			_show_entry()


## The shown entry's lines: name, description, stats.
func lines() -> PackedStringArray:
	return PackedStringArray([_name.text, _description.text, _stats.text])


## True when the shown entry's preview is a locked silhouette.
func preview_locked() -> bool:
	return _preview.is_locked()


## How many entries the codex lists.
func entry_count() -> int:
	return _entries.size()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left", false, true):
		choose(-1)
		accept_event()
	elif event.is_action_pressed(&"ui_right", false, true):
		choose(1)
		accept_event()


func _subscribe() -> void:
	var _ok: bool = _require(
		[
			_bus.profile.intel_catalog_changed.connect(_on_intel_catalog_changed),
			_bus.profile.intel_changed.connect(_on_intel_changed),
			_bus.profile.intel_unlocked.connect(_on_intel_unlocked),
		]
	)


func _on_intel_catalog_changed(entries: Array[IntelEntry]) -> void:
	_entries = entries.duplicate()
	_index = clampi(_index, 0, maxi(_entries.size() - 1, 0))
	_show_entry()


func _on_intel_changed(unlocked: Array[StringName]) -> void:
	_unlocked = unlocked.duplicate()
	_show_entry()


func _on_intel_unlocked(entry_id: StringName) -> void:
	if not _unlocked.has(entry_id):
		_unlocked.append(entry_id)
	_show_entry()


func _on_enter() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_show_entry()


func _show_entry() -> void:
	if _entries.is_empty():
		_counter.text = "INTEL"
		return
	var entry: IntelEntry = _entries[_index]
	var known: bool = _unlocked.has(entry.id)
	_name.text = entry.display_name.to_upper() if known else LOCKED
	_description.text = entry.description if known else LOCKED_DESCRIPTION
	_stats.text = (
		"%s HP   %s PTS" % [UiFormat.score(entry.hit_points), UiFormat.score(entry.points)]
		if known
		else "%s HP   %s PTS" % [LOCKED, LOCKED]
	)
	_preview.show_entry(entry, known)
	_counter.text = "INTEL   %d / %d" % [_index + 1, _entries.size()]


func _nav_button(parent: Control, text: String, action: Callable) -> Button:
	var made: Button = UiBuild.button(text)
	made.custom_minimum_size = Vector2(NAV_WIDTH, UiBuild.BUTTON_HEIGHT)
	if made.pressed.connect(action) != OK:
		push_error("IntelScreen: could not wire %s" % text)
	parent.add_child(made)
	return made
