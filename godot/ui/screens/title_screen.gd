class_name TitleScreen
extends UiScreen
## Title (#73): the "MECHA FIGHTER" title treatment (ui/title) and the menu over
## the attract-mode dogfight (game/attract), with a hint line under it that
## tells you how to select with your current device.
## Play starts a Run; Scoreboard is a Game State; Settings and Credits open
## on top of the Title.

const TITLE_LOGO: PackedScene = preload("res://ui/title/title_logo.tscn")
## The logo's share of the screen width (leaving room for its pop-in overshoot,
## about 1.12x, to stay on screen), its height as a share of its width, and the
## most of the screen height it may take (so the menu always fits).
const LOGO_WIDTH: float = 0.8
const LOGO_ASPECT: float = 0.24
const LOGO_MAX_HEIGHT: float = 0.22

var _logo: TitleLogo
var _play: Button
var _hint: GlyphHint
var _menu: Array[Control] = []


func _ready() -> void:
	var content: VBoxContainer = UiBuild.column(18)
	UiBuild.centered(self).add_child(content)
	_logo = TITLE_LOGO.instantiate() as TitleLogo
	content.add_child(_logo)
	if resized.connect(_fit_logo) != OK:
		push_error("TitleScreen: could not wire the logo size")
	_fit_logo()
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
	_logo.play_intro()
	stagger_in(_menu)


## The logo sizes its lettering to its own width: give it most of the screen's.
func _fit_logo() -> void:
	var width: float = size.x * LOGO_WIDTH
	var height: float = minf(width * LOGO_ASPECT, size.y * LOGO_MAX_HEIGHT)
	_logo.custom_minimum_size = Vector2(width, height)
	_logo.fit_to(Vector2(width, height))


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
