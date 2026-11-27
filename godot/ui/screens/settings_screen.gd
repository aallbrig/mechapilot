class_name SettingsScreen
extends UiScreen
## Settings (#73): master, music and SFX volume, screen shake, reduced motion,
## tutorial hints, rumble and touch stick opacity, plus reset to defaults.
## Every change is an intent (profile.settings_change_requested); the shown
## values always come from profile.settings_changed, so the screen shows what
## was really stored. Opened from the Title and from Pause. Everything,
## Reset and Back included, fits on screen from a phone in portrait to 4K.

const VOLUME_STEP: float = 0.05
const OPACITY_STEP: float = 0.05
const ITEM_WIDTH: float = 300.0
const SLIDER_SIZE: Vector2 = Vector2(ITEM_WIDTH, 36.0)
const ACTION_WIDTH: float = 240.0
const COLUMN_GAP: int = 32
## Wider than tall: the sliders and toggles sit side by side (so the panel fits
## a 640 UI pixel high landscape screen); otherwise they stack.
const SIDE_BY_SIDE: int = 2

var _shown: GameSettings = GameSettings.new()
var _master: HSlider
var _music: HSlider
var _sfx: HSlider
var _shake: CheckButton
var _reduced_motion: CheckButton
var _hints: CheckButton
var _rumble: CheckButton
var _opacity: HSlider
var _back: Button
var _columns: GridContainer


func _ready() -> void:
	var content: VBoxContainer = UiBuild.centered_panel(self)
	content.add_theme_constant_override(&"separation", UiBuild.GAP)
	content.add_child(UiBuild.label("SETTINGS", &"HeaderLabel"))
	_columns = GridContainer.new()
	_columns.add_theme_constant_override(&"h_separation", COLUMN_GAP)
	_columns.add_theme_constant_override(&"v_separation", UiBuild.GAP)
	_columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_columns)
	var sliders: VBoxContainer = UiBuild.column(6)
	var toggles: VBoxContainer = UiBuild.column(6)
	_columns.add_child(sliders)
	_columns.add_child(toggles)
	_master = _slider(sliders, "Master volume", 0.0, 1.0, VOLUME_STEP)
	_music = _slider(sliders, "Music volume", 0.0, 1.0, VOLUME_STEP)
	_sfx = _slider(sliders, "SFX volume", 0.0, 1.0, VOLUME_STEP)
	_opacity = _slider(
		sliders,
		"Touch stick opacity",
		GameSettings.MIN_TOUCH_STICK_OPACITY,
		GameSettings.MAX_TOUCH_STICK_OPACITY,
		OPACITY_STEP
	)
	_shake = _toggle(toggles, "Screen shake")
	_reduced_motion = _toggle(toggles, "Reduced motion")
	_hints = _toggle(toggles, "Tutorial hints")
	_rumble = _toggle(toggles, "Rumble")
	var actions: HBoxContainer = UiBuild.row()
	content.add_child(actions)
	var reset: Button = UiBuild.button("RESET")
	reset.custom_minimum_size.x = ACTION_WIDTH
	_wire(reset.pressed.connect(_on_reset))
	actions.add_child(reset)
	_back = UiBuild.button("BACK")
	_back.custom_minimum_size.x = ACTION_WIDTH
	_wire(_back.pressed.connect(request_back))
	actions.add_child(_back)
	juice(_back, UiCue.Cue.BACK)
	_fit()
	for check: CheckButton in [_shake, _reduced_motion, _hints, _rumble]:
		_wire(check.toggled.connect(_on_changed.unbind(1)))
	for slider: HSlider in [_master, _music, _sfx, _opacity]:
		_wire(slider.value_changed.connect(_on_changed.unbind(1)))
	_show(_shown)


func default_focus() -> Control:
	return _master


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _columns != null:
		_fit()


## Two columns when the screen is wider than tall, one otherwise.
func _fit() -> void:
	_columns.columns = SIDE_BY_SIDE if size.x > size.y else 1


## How many columns the controls use now.
func column_count() -> int:
	return _columns.columns


func handle_cancel() -> bool:
	request_back()
	return true


## The settings the screen shows.
func shown() -> GameSettings:
	return _shown.copy()


## The controls, by setting, for tests: master, music, sfx, shake,
## reduced_motion, hints, rumble, opacity.
func controls() -> Dictionary[StringName, Control]:
	return {
		&"master": _master,
		&"music": _music,
		&"sfx": _sfx,
		&"shake": _shake,
		&"reduced_motion": _reduced_motion,
		&"hints": _hints,
		&"rumble": _rumble,
		&"opacity": _opacity,
	}


func _subscribe() -> void:
	var _ok: bool = _require([_bus.profile.settings_changed.connect(_show)])


func _show(settings: GameSettings) -> void:
	_shown = settings.copy()
	_master.set_value_no_signal(settings.master_volume)
	_music.set_value_no_signal(settings.music_volume)
	_sfx.set_value_no_signal(settings.sfx_volume)
	_opacity.set_value_no_signal(settings.touch_stick_opacity)
	_shake.set_pressed_no_signal(settings.screen_shake)
	_reduced_motion.set_pressed_no_signal(settings.reduced_motion)
	_hints.set_pressed_no_signal(settings.tutorial_hints)
	_rumble.set_pressed_no_signal(settings.rumble)


func _on_changed() -> void:
	var wanted: GameSettings = _shown.copy()
	wanted.master_volume = _master.value
	wanted.music_volume = _music.value
	wanted.sfx_volume = _sfx.value
	wanted.touch_stick_opacity = _opacity.value
	wanted.screen_shake = _shake.button_pressed
	wanted.reduced_motion = _reduced_motion.button_pressed
	wanted.tutorial_hints = _hints.button_pressed
	wanted.rumble = _rumble.button_pressed
	if _bus != null and not wanted.equals(_shown):
		_bus.profile.announce_settings_change_requested(wanted)


func _on_reset() -> void:
	_bus.profile.announce_settings_reset_requested()


func _slider(parent: Control, text: String, low: float, high: float, step: float) -> HSlider:
	parent.add_child(UiBuild.label(text, &"HintLabel"))
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.focus_mode = Control.FOCUS_ALL
	slider.custom_minimum_size = SLIDER_SIZE
	parent.add_child(slider)
	return slider


func _toggle(parent: Control, text: String) -> CheckButton:
	var check: CheckButton = CheckButton.new()
	check.text = text
	check.focus_mode = Control.FOCUS_ALL
	check.custom_minimum_size = Vector2(ITEM_WIDTH, UiBuild.BUTTON_HEIGHT)
	parent.add_child(check)
	return check


func _wire(result: int) -> void:
	if result != OK:
		push_error("SettingsScreen: could not wire a control: %s" % error_string(result))
