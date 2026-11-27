class_name TitleLogo
extends Control
## The "MECHA FIGHTER" title treatment for the Title screen: heavy italic
## lettering with a chrome gradient, a dark outline and drop shadow, a red
## speed stripe beneath, and a shine that sweeps across the letters. It measures
## its lettering and sizes it to fit its own width and height, so it reads from
## a 360 px phone to 4K without overflowing.
## play_intro() pops it in. Under reduced motion (the player's setting,
## followed through Events.profile.settings_changed) there is no pop, float or
## shine sweep.

## The share of the logo's width and height the lettering may fill (the rest
## leaves room for the outline, the italic slant and the shadow), the font size
## the lettering is measured at, and the size limits in pixels.
const FILL_WIDTH: float = 0.8
const FILL_HEIGHT: float = 0.6
const MEASURE_SIZE: int = 100
const MIN_FONT_SIZE: int = 28
const MAX_FONT_SIZE: int = 220
## Outline and shadow sizes relative to the font size.
const OUTLINE_RATIO: float = 0.09
const SHADOW_RATIO: float = 0.05
## The speed stripe's width relative to the font size.
const STRIPE_TO_FONT: float = 6.5
## The intro: the lettering pops up from this scale (from small, like the rest
## of the UI's juice, so it never spills off the screen), and how long it takes.
const INTRO_SCALE: float = 0.3
const INTRO_TIME: float = 0.45
const STRIPE_TIME: float = 0.3
## Idle float: amplitude in pixels and period in seconds.
const FLOAT_AMPLITUDE: float = 4.0
const FLOAT_PERIOD: float = 3.0
const TEXT_SIZE_PARAM: StringName = &"text_size"
const SHINE_PARAM: StringName = &"shine_amount"

## Skip the intro pop, the idle float and the shine (the reduced-motion
## setting; kept in step with the player's settings once the logo is ready).
@export var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		_apply_motion()

var _clock: float = 0.0
var _intro: Tween = null

@onready var _title: Label = $Lettering/Title
@onready var _stripe: ColorRect = $Lettering/Stripe
@onready var _lettering: Control = $Lettering


func _ready() -> void:
	for pair: Array in [[self, _fit], [_title, _update_shine_area]]:
		var source: Control = pair[0]
		var handler: Callable = pair[1]
		var err: Error = source.resized.connect(handler) as Error
		if err != OK:
			push_error("TitleLogo: could not subscribe to resized: %s" % error_string(err))
	var settings_err: Error = Events.profile.settings_changed.connect(_on_settings_changed) as Error
	if settings_err != OK:
		push_error(
			"TitleLogo: could not subscribe to settings_changed: %s" % error_string(settings_err)
		)
	_fit()
	_update_shine_area()
	_apply_motion()


func _on_settings_changed(settings: GameSettings) -> void:
	reduced_motion = settings.reduced_motion


## Settle everything that moves when reduced motion turns on.
func _apply_motion() -> void:
	if not is_node_ready():
		return
	if reduced_motion:
		if _intro != null and _intro.is_valid():
			_intro.kill()
		_lettering.scale = Vector2.ONE
		_lettering.modulate.a = 1.0
		_float_to(0.0)
		_stripe.scale.x = 1.0
	var shine: ShaderMaterial = _title.material as ShaderMaterial
	if shine != null:
		shine.set_shader_parameter(SHINE_PARAM, 0.0 if reduced_motion else 1.0)


func _process(delta: float) -> void:
	if reduced_motion:
		_float_to(0.0)
		return
	_clock = fmod(_clock + delta, FLOAT_PERIOD)
	_float_to(sin(_clock / FLOAT_PERIOD * TAU) * FLOAT_AMPLITUDE)


## Float the lettering `rise` pixels down (negative: up) inside the logo's box.
## The lettering is anchored to the whole box, so it moves through its offsets:
## writing its position instead would turn the box's size at that moment into
## offsets (a 0x0 box while hidden behind Boot left the lettering sliding under
## the menu once the Title appeared).
func _float_to(rise: float) -> void:
	_lettering.offset_left = 0.0
	_lettering.offset_right = 0.0
	_lettering.offset_top = rise
	_lettering.offset_bottom = rise


## Pop the title in: it grows from small and faded to its place, then the
## stripe sweeps out under it. Under reduced motion it simply appears.
func play_intro() -> void:
	if _intro != null and _intro.is_valid():
		_intro.kill()
	_lettering.pivot_offset = _lettering.size * 0.5
	if reduced_motion:
		_lettering.scale = Vector2.ONE
		_lettering.modulate.a = 1.0
		_stripe.scale.x = 1.0
		return
	_lettering.scale = Vector2.ONE * INTRO_SCALE
	_lettering.modulate.a = 0.0
	_stripe.scale.x = 0.0
	_intro = create_tween()
	var _p1: PropertyTweener = (
		_intro
		. tween_property(_lettering, "scale", Vector2.ONE, INTRO_TIME)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	var _p2: PropertyTweener = _intro.parallel().tween_property(
		_lettering, "modulate:a", 1.0, INTRO_TIME * 0.5
	)
	var _p3: PropertyTweener = (
		_intro
		. tween_property(_stripe, "scale:x", 1.0, STRIPE_TIME)
		. set_trans(Tween.TRANS_QUART)
		. set_ease(Tween.EASE_OUT)
	)


## The lettering's current font size in pixels.
func font_size() -> int:
	return _title.label_settings.font_size


## Size the lettering to fit a box of `box` pixels now, without waiting for the
## containers to lay the logo out (the Title screen calls it as it resizes).
func fit_to(box: Vector2) -> void:
	if not is_node_ready():
		return
	var settings: LabelSettings = _title.label_settings
	# Measure the lettering, then size it to fit both the logo's width and height.
	var measured: Vector2 = settings.font.get_string_size(
		_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, MEASURE_SIZE
	)
	var per_px: float = measured.x / MEASURE_SIZE
	var by_width: float = box.x * FILL_WIDTH / maxf(per_px, 1e-3)
	var by_height: float = box.y * FILL_HEIGHT if box.y > 0.0 else by_width
	var font_px: int = clampi(floori(minf(by_width, by_height)), MIN_FONT_SIZE, MAX_FONT_SIZE)
	settings.font_size = font_px
	settings.outline_size = maxi(1, roundi(font_px * OUTLINE_RATIO))
	settings.shadow_size = maxi(1, roundi(font_px * SHADOW_RATIO))
	settings.shadow_offset = Vector2.ONE * roundf(font_px * SHADOW_RATIO)
	_stripe.custom_minimum_size = Vector2(
		minf(roundf(font_px * STRIPE_TO_FONT), box.x), maxf(2.0, roundf(font_px * SHADOW_RATIO))
	)
	_stripe.pivot_offset = Vector2(_stripe.size.x * 0.5, 0.0)


## On its own resize, fit the box the parent asked for (its minimum size) when
## there is one: a resize from an older layout pass must not refit the lettering
## to a stale, larger box after the parent already fitted the new one.
func _fit() -> void:
	fit_to(custom_minimum_size if custom_minimum_size != Vector2.ZERO else size)


func _update_shine_area() -> void:
	var shine: ShaderMaterial = _title.material as ShaderMaterial
	if shine != null:
		shine.set_shader_parameter(TEXT_SIZE_PARAM, _title.size)
