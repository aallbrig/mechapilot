class_name ControlJuice
extends RefCounted
## Hover, focus and press juice for one interactive control, with its sound
## cues (#73: every interactive element has hover, focus, press, sound and juice).
##
## - Pointer over a focusable control gives it focus, so mouse, touch, keyboard
##   and gamepad all share one highlight.
## - Focus (or hover on a control that cannot take focus) eases the scale up and
##   cues FOCUS; losing it eases back.
## - Pressing a button squashes it; releasing punches it and cues `press_cue`
##   (TOGGLE for toggles). Moving a slider punches it and cues SLIDE.
##
## The screen that owns the control keeps the returned juice alive and hears
## `cued`, so this helper never reaches for the bus itself.

## A sound cue for the owner to announce.
signal cued(cue: UiCue.Cue)

var _control: Control
var _press_cue: UiCue.Cue = UiCue.Cue.CONFIRM


## Juice `control`. The caller must keep the result referenced.
static func attach(control: Control, press_cue: UiCue.Cue = UiCue.Cue.CONFIRM) -> ControlJuice:
	var juice: ControlJuice = ControlJuice.new()
	juice._control = control
	juice._press_cue = press_cue
	juice._wire()
	return juice


## The control this juice drives.
func target() -> Control:
	return _control


func _wire() -> void:
	var results: Array[int] = [
		_control.mouse_entered.connect(_on_pointer_entered),
		_control.mouse_exited.connect(_on_pointer_exited),
		_control.focus_entered.connect(_on_focus_entered),
		_control.focus_exited.connect(_on_focus_exited),
	]
	if _control is BaseButton:
		var button: BaseButton = _control as BaseButton
		results.append(button.button_down.connect(_on_button_down))
		results.append(button.pressed.connect(_on_pressed))
	if _control is Range:
		var range_control: Range = _control as Range
		results.append(range_control.value_changed.connect(_on_value_changed))
	for result: int in results:
		if result != OK:
			push_error(
				"ControlJuice: could not wire %s: %s" % [_control.name, error_string(result)]
			)


func _on_pointer_entered() -> void:
	if _control.focus_mode != Control.FOCUS_NONE and _control.is_visible_in_tree():
		_control.grab_focus()
		return
	TweenFx.scale_to(_control, TweenFx.HOVER_SCALE)
	_announce(UiCue.Cue.FOCUS)


func _on_pointer_exited() -> void:
	if not _control.has_focus():
		TweenFx.scale_to(_control, 1.0)


func _on_focus_entered() -> void:
	TweenFx.scale_to(_control, TweenFx.HOVER_SCALE)
	_announce(UiCue.Cue.FOCUS)


func _on_focus_exited() -> void:
	TweenFx.scale_to(_control, 1.0)


func _on_button_down() -> void:
	TweenFx.scale_to(_control, TweenFx.PRESS_SCALE, TweenFx.PRESS_TIME)


func _on_pressed() -> void:
	TweenFx.punch(_control)
	var button: BaseButton = _control as BaseButton
	_announce(UiCue.Cue.TOGGLE if button.toggle_mode else _press_cue)


func _on_value_changed(_value: float) -> void:
	TweenFx.punch(_control, TweenFx.PUNCH_AMOUNT * 0.25)
	_announce(UiCue.Cue.SLIDE)


func _announce(cue: UiCue.Cue) -> void:
	cued.emit(cue)
