class_name CreditsScreen
extends UiScreen
## Credits (#73): every asset and its licence, scrolling. The list is read from
## res://CREDITS.md, the same table the asset-credits check reads, so the
## screen can never drift from it (the Web export includes the file). Each
## credit shows the asset's name, its author and its licence (file paths are
## for the asset-credits check, not for players). The full SIL Open Font
## Licence of each bundled font follows the list: the OFL requires it to ship
## with the font, and the Web export includes those files too.

const SCROLL_SPEED: float = 40.0
const SCROLL_START_DELAY: float = 1.5
const LIST_HEIGHT: float = 360.0

var _scroll: ScrollContainer
var _list: VBoxContainer
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


func _on_enter() -> void:
	_scroll.scroll_vertical = 0
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
