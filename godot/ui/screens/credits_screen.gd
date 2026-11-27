class_name CreditsScreen
extends UiScreen
## Credits (#73): every asset and its licence, scrolling. The list is read from
## res://CREDITS.md, the same table the asset-credits check reads, so the
## screen can never drift from it (the Web export includes the file). Each
## credit shows the asset's name, its author and its licence (file paths are
## for the asset-credits check, not for players). The full SIL Open Font
## Licence of each bundled font follows the list: the OFL requires it to ship
## with the font, and the Web export includes those files too. The list opens
## with the game's creator (#105), read from the same file's "Created by" line.

const SCROLL_SPEED: float = 40.0
const SCROLL_START_DELAY: float = 1.5
const LIST_HEIGHT: float = 360.0
const CREATOR_PREFIX: String = "Created by "
const CREATOR_GAP: int = 4
const CREATOR_POP_FROM: float = 0.85
const CREATOR_POP_DELAY: float = 0.1
## The creator's name starts at the TitleLabel size and steps down by this
## until it fits the column on one line, but never below the floor.
const CREATOR_FIT_STEP: int = 2
const CREATOR_MIN_FONT_SIZE: int = 32

var _scroll: ScrollContainer
var _list: VBoxContainer
var _opening: VBoxContainer
var _creator_name: Label

var _back: Button
var _scroll_tween: Tween
var _credits: Array[PackedStringArray] = []
var _licences: PackedStringArray = []


func _ready() -> void:
	var content: VBoxContainer = UiBuild.centered_panel(self)
	content.add_child(UiBuild.label("CREDITS", &"HeaderLabel"))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(UiBuild.COLUMN_WIDTH, LIST_HEIGHT)
	content.add_child(_scroll)
	_list = UiBuild.column(18)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_add_opening(read_creator())
	_credits = read_credits()
	for credit: PackedStringArray in _credits:
		var entry: VBoxContainer = UiBuild.column(2)
		entry.add_child(UiBuild.paragraph(credit[0], &"BodyLabel"))
		entry.add_child(UiBuild.paragraph("%s  -  %s" % [credit[1], credit[2]], &"HintLabel"))
		_list.add_child(entry)
	_list.add_child(
		UiBuild.paragraph(
			(
				"Mecha Fighter is an independent remix inspired by Konami's 1982 arcade game"
				+ " Time Pilot. It uses no Konami assets and is not affiliated with Konami."
			),
			&"HintLabel"
		)
	)
	_list.add_child(UiBuild.label("FONT LICENCES", &"ComboLabel"))
	_licences = read_font_licences()
	for licence: String in _licences:
		_list.add_child(UiBuild.paragraph(licence, &"HintLabel"))
	_back = UiBuild.button("BACK")
	if _back.pressed.connect(request_back) != OK:
		push_error("CreditsScreen: could not wire Back")
	content.add_child(_back)
	juice(_back, UiCue.Cue.BACK)


func default_focus() -> Control:
	return _back


func handle_cancel() -> bool:
	request_back()
	return true


## The labels of the entry the list opens with: "Created by", then the
## creator's name in the title style.
func opening() -> Array[Label]:
	var labels: Array[Label] = []
	if _opening != null:
		for child: Node in _opening.get_children():
			labels.append(child as Label)
	return labels


## Where the creator entry sits in the list (0: before every other entry).
func opening_index() -> int:
	return _opening.get_index() if _opening != null else -1


## The credits shown: [asset, source, licence] per row of CREDITS.md.
func credits() -> Array[PackedStringArray]:
	return _credits.duplicate()


## The full text of each bundled font's licence (SIL OFL 1.1).
func licence_texts() -> PackedStringArray:
	return _licences.duplicate()


## Reads the OFL text shipped next to each bundled font.
static func read_font_licences() -> PackedStringArray:
	var texts: PackedStringArray = []
	for file: FileAccess in [
		FileAccess.open("res://ui/theme/fonts/Orbitron-OFL.txt", FileAccess.READ),
		FileAccess.open("res://ui/theme/fonts/ChakraPetch-OFL.txt", FileAccess.READ),
	]:
		if file == null:
			push_error("CreditsScreen: a font licence file is missing")
			continue
		var _added: bool = texts.append(file.get_as_text().strip_edges())
	return texts


## The creator named on the "Created by <name>." line of res://CREDITS.md,
## or "" when the file has no such line above its asset table.
static func read_creator() -> String:
	var file: FileAccess = FileAccess.open("res://CREDITS.md", FileAccess.READ)
	if file == null:
		push_error("CreditsScreen: res://CREDITS.md is missing")
		return ""
	var creator: String = creator_in(file.get_as_text())
	if creator.is_empty():
		push_error('CreditsScreen: res://CREDITS.md has no "Created by" line above its table')
	return creator


## The name on the first "Created by <name>." line of a CREDITS.md text that
## comes before the asset table; a table cell or a line below the table never
## counts. "" when there is none.
static func creator_in(text: String) -> String:
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("|"):
			break
		if line.begins_with(CREATOR_PREFIX) and line.ends_with("."):
			return line.trim_prefix(CREATOR_PREFIX).trim_suffix(".").strip_edges()
	return ""


## The rows of the asset table in res://CREDITS.md, as plain text cells.
static func read_credits() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file: FileAccess = FileAccess.open("res://CREDITS.md", FileAccess.READ)
	if file == null:
		push_error("CreditsScreen: res://CREDITS.md is missing")
		return rows
	while not file.eof_reached():
		var cells: PackedStringArray = parse_row(file.get_line())
		if cells.size() == 3:
			rows.append(cells)
	return rows


## One Markdown table row as three plain cells (links become their text,
## backticks are dropped); empty for the header, the rule or any other line.
static func parse_row(line: String) -> PackedStringArray:
	var trimmed: String = line.strip_edges()
	if not trimmed.begins_with("|") or trimmed.begins_with("| ---") or trimmed.begins_with("|---"):
		return PackedStringArray()
	var cells: PackedStringArray = trimmed.trim_prefix("|").trim_suffix("|").split("|")
	if cells.size() != 3 or cells[0].strip_edges() == "Asset":
		return PackedStringArray()
	var plain: PackedStringArray = []
	for cell: String in cells:
		var _added: bool = plain.append(plain_text(cell))
	return plain


## A Markdown cell as player-facing text: links become their text, and
## backticked file paths (with any "(licence: ...)" note left empty by them)
## are dropped.
static func plain_text(cell: String) -> String:
	var text: String = RegEx.create_from_string("\\[([^\\]]*)\\]\\([^)]*\\)").sub(cell, "$1", true)
	text = RegEx.create_from_string("`[^`]*`").sub(text, "", true)
	text = RegEx.create_from_string("\\(\\s*(licence:)?[\\s,]*\\)").sub(text, "", true)
	text = RegEx.create_from_string("\\s+").sub(text, " ", true)
	return text.replace(" ,", ",").strip_edges().trim_prefix(",").strip_edges()


func _add_opening(creator: String) -> void:
	if creator.is_empty():
		return
	_opening = UiBuild.column(CREATOR_GAP)
	var by: Label = UiBuild.label(CREATOR_PREFIX.strip_edges(), &"ComboLabel")
	by.uppercase = true
	_opening.add_child(by)
	_creator_name = UiBuild.paragraph(creator, &"TitleLabel")
	_opening.add_child(_creator_name)
	_list.add_child(_opening)
	_fit_on_one_line(_creator_name, UiBuild.COLUMN_WIDTH)


## Steps `label`'s font size down from its theme size until its text, with its
## outline, fits `width` on one line (or the size reaches the floor).
static func _fit_on_one_line(label: Label, width: float) -> void:
	var font: Font = label.get_theme_font(&"font")
	var outline: int = label.get_theme_constant(&"outline_size")
	var font_size: int = label.get_theme_font_size(&"font_size")
	while (
		font_size > CREATOR_MIN_FONT_SIZE
		and (
			font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + outline
			> width
		)
	):
		font_size -= CREATOR_FIT_STEP
	label.add_theme_font_size_override(&"font_size", font_size)


func _on_enter() -> void:
	_scroll.scroll_vertical = 0
	if _creator_name != null:
		TweenFx.pop(_creator_name, CREATOR_POP_FROM, TweenFx.POP_TIME, CREATOR_POP_DELAY)
	if _scroll_tween != null:
		_scroll_tween.kill()
	if TweenFx.reduced_motion:
		return
	var distance: float = maxf(_list.get_combined_minimum_size().y - LIST_HEIGHT, 0.0)
	_scroll_tween = TweenFx.make(_scroll)
	var _roll: PropertyTweener = (
		_scroll_tween
		. tween_property(_scroll, "scroll_vertical", int(distance), distance / SCROLL_SPEED)
		. set_delay(SCROLL_START_DELAY)
	)


func _on_leave() -> void:
	if _scroll_tween != null:
		_scroll_tween.kill()
		_scroll_tween = null
