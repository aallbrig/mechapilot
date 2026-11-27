class_name TitleScreen
extends UiScreen
## Title (#73): the menu over the attract-mode dogfight (game/attract), with a
## hint line under it that tells you how to select with your current device.
## Play starts a Run; Scoreboard is a Game State; Settings and Credits open
## on top of the Title.

const TITLE: String = "MECHA\nFIGHTER"
const LOGO_POP_FROM: float = 0.3
const LOGO_POP_TIME: float = 0.6

var _logo: Label
var _play: Button
var _hint: GlyphHint
var _menu: Array[Control] = []


func _ready() -> void:
	var content: VBoxContainer = UiBuild.column(18)
	UiBuild.centered(self).add_child(content)
	_logo = UiBuild.label(TITLE, &"TitleLabel")
	content.add_child(_logo)
	var menu: VBoxContainer = UiBuild.column()
	content.add_child(menu)
	_play = _menu_button(menu, "PLAY", _on_play)
	var _board: Button = _menu_button(menu, "SCOREBOARD", _on_scoreboard)
	var _settings: Button = _menu_button(menu, "SETTINGS", _open.bind(&"settings"))
	var _credits: Button = _menu_button(menu, "CREDITS", _open.bind(&"credits"))
	_hint = GlyphHint.new()
	content.add_child(_hint)
	_on_device_changed()


func default_focus() -> Control:
	return _play


## The hint line's text, glyphs in brackets.
func hint_text() -> String:
	return _hint.text()


func _on_enter() -> void:
	TweenFx.pop(_logo, LOGO_POP_FROM, LOGO_POP_TIME)
	stagger_in(_menu)


func _on_device_changed() -> void:
	_hint.show_segments(InputGlyphs.select_hint(_device))


func _on_play() -> void:
	_bus.flow.announce_play_requested()


func _on_scoreboard() -> void:
	_bus.flow.announce_scoreboard_requested()


func _open(target: StringName) -> void:
	request_navigate(target)


func _menu_button(parent: Control, text: String, action: Callable) -> Button:
	var made: Button = UiBuild.button(text)
	if made.pressed.connect(action) != OK:
		push_error("TitleScreen: could not wire %s" % text)
	parent.add_child(made)
	_menu.append(made)
	return made
