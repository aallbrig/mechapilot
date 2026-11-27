class_name TutorialBanner
extends PanelContainer
## The first-flight tutorial prompt on the HUD (#73, #75): one prompt at a
## time, with the current device's glyphs. It pops in when the rules show a
## prompt and fades out when they dismiss it (with a pop when it was done).

const DONE_PUNCH: float = 0.2
const NO_PROMPT: int = -1

var _hint: GlyphHint
var _prompt: int = NO_PROMPT
var _device: InputDevice.Kind = InputDevice.Kind.KEYBOARD


func _init() -> void:
	theme_type_variation = &"MenuPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_hint = GlyphHint.new()
	_hint.custom_minimum_size = Vector2(UiBuild.COLUMN_WIDTH, 0.0)
	add_child(_hint)


## Shows `prompt` for the current device.
func show_prompt(prompt: TutorialPrompt.Id) -> void:
	_prompt = prompt
	_refresh()
	visible = true
	modulate.a = 1.0
	TweenFx.pop(self)


## Hides `prompt` if it is the one shown; `completed` pops it first.
func dismiss(prompt: TutorialPrompt.Id, completed: bool) -> void:
	if _prompt != prompt:
		return
	_prompt = NO_PROMPT
	if completed:
		TweenFx.punch(self, DONE_PUNCH)
	visible = false


## Switches the glyphs to `device`.
func set_device(device: InputDevice.Kind) -> void:
	_device = device
	_refresh()


## The prompt shown, or -1.
func shown_prompt() -> int:
	return _prompt


## The prompt's text, glyphs in brackets ("" when hidden).
func text() -> String:
	return _hint.text() if visible else ""


func _refresh() -> void:
	if _prompt != NO_PROMPT:
		_hint.show_segments(InputGlyphs.tutorial(_prompt as TutorialPrompt.Id, _device))
