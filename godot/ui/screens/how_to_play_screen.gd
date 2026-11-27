class_name HowToPlayScreen
extends UiScreen
## How to Play, the game guide (#73, #75): one short illustrated page per
## topic, each showing the controls of the device the player used last.
## Opened from the Title and from Pause. Left and Right (or the arrows, or a
## tap on Prev and Next) turn the page; Back closes it.

const PAGE_FLIP: Vector2 = Vector2(60.0, 0.0)

## Prev, Back and Next share one row.
const NAV_WIDTH: float = 160.0

var _page: int = 0
var _title: Label
var _illustration: GuideIllustration
var _body: Label
var _controls: GlyphHint
var _counter: Label
var _next: Button
var _page_box: VBoxContainer


func _ready() -> void:
	var content: VBoxContainer = UiBuild.centered_panel(self)
	content.add_theme_constant_override(&"separation", 10)
	_counter = UiBuild.label("", &"HintLabel")
	content.add_child(_counter)
	_page_box = UiBuild.column(10)
	content.add_child(_page_box)
	_title = UiBuild.paragraph("", &"ComboLabel")
	_illustration = GuideIllustration.new()
	_illustration.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body = UiBuild.paragraph("")
	_controls = GlyphHint.new()
	_page_box.add_child(_title)
	_page_box.add_child(_illustration)
	_page_box.add_child(_body)
	_page_box.add_child(_controls)
	var nav: HBoxContainer = UiBuild.row()
	content.add_child(nav)
	var _prev: Button = _nav_button(nav, "PREV", turn.bind(-1))
	var back: Button = _nav_button(nav, "BACK", request_back)
	juice(back, UiCue.Cue.BACK)
	_next = _nav_button(nav, "NEXT", turn.bind(1))
	_show_page()


func default_focus() -> Control:
	return _next


func handle_cancel() -> bool:
	request_back()
	return true


## Turns `step` pages (wrapping).
func turn(step: int) -> void:
	_page = posmod(_page + step, GuidePages.count())
	_show_page()
	TweenFx.slide_in(_page_box, PAGE_FLIP * signf(step))


## The page shown (0-based).
func page() -> int:
	return _page


## The page's title.
func page_title() -> String:
	return _title.text


## The page's controls line, glyphs in brackets.
func controls_text() -> String:
	return _controls.text()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left", false, true):
		turn(-1)
		accept_event()
	elif event.is_action_pressed(&"ui_right", false, true):
		turn(1)
		accept_event()


func _on_enter() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_page = 0
	_show_page()


func _on_device_changed() -> void:
	_show_page()


func _show_page() -> void:
	var topic: GuidePages.Topic = _page as GuidePages.Topic
	_title.text = GuidePages.TITLES[topic]
	_body.text = GuidePages.BODIES[topic]
	_illustration.show_topic(topic)
	_controls.show_segments(GuidePages.controls(topic, _device))
	_counter.text = "HOW TO PLAY   %d / %d" % [_page + 1, GuidePages.count()]


func _nav_button(parent: Control, text: String, action: Callable) -> Button:
	var made: Button = UiBuild.button(text)
	made.custom_minimum_size = Vector2(NAV_WIDTH, UiBuild.BUTTON_HEIGHT)
	if made.pressed.connect(action) != OK:
		push_error("HowToPlayScreen: could not wire %s" % text)
	parent.add_child(made)
	return made
