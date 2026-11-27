class_name TitleLogo
extends Control
## The "MECHA FIGHTER" title treatment for the Title screen: heavy italic
## lettering with a chrome gradient, a dark outline and drop shadow, a red
## speed stripe beneath, and a shine that sweeps across the letters. It sizes
## its lettering to its own width, so it reads from a 360 px phone to 4K.
## play_intro() slams it in (skipped, like every motion, under reduced motion).

## Lettering size as a fraction of the logo's width, and its limits in pixels.
const FONT_TO_WIDTH: float = 0.105
const MIN_FONT_SIZE: int = 28
const MAX_FONT_SIZE: int = 220
## Outline and shadow sizes relative to the font size.
const OUTLINE_RATIO: float = 0.09
const SHADOW_RATIO: float = 0.05
## The speed stripe's width relative to the font size.
const STRIPE_TO_FONT: float = 6.5
## The intro: start scale, duration and the settle overshoot.
const INTRO_SCALE: float = 1.8
const INTRO_TIME: float = 0.45
const STRIPE_TIME: float = 0.3
## Idle float: amplitude in pixels and period in seconds.
const FLOAT_AMPLITUDE: float = 4.0
const FLOAT_PERIOD: float = 3.0
const TEXT_SIZE_PARAM: StringName = &"text_size"

## Skip the intro slam and the idle float (the reduced-motion setting).
@export var reduced_motion: bool = false

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
	_fit()
	_update_shine_area()


func _process(delta: float) -> void:
	if reduced_motion:
		_lettering.position.y = 0.0
		return
	_clock = fmod(_clock + delta, FLOAT_PERIOD)
	_lettering.position.y = sin(_clock / FLOAT_PERIOD * TAU) * FLOAT_AMPLITUDE


## Slam the title in: it drops from large and faded to its place, then the
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


func _fit() -> void:
	var font_px: int = clampi(roundi(size.x * FONT_TO_WIDTH), MIN_FONT_SIZE, MAX_FONT_SIZE)
	var settings: LabelSettings = _title.label_settings
	settings.font_size = font_px
	settings.outline_size = maxi(1, roundi(font_px * OUTLINE_RATIO))
	settings.shadow_size = maxi(1, roundi(font_px * SHADOW_RATIO))
	settings.shadow_offset = Vector2.ONE * roundf(font_px * SHADOW_RATIO)
	_stripe.custom_minimum_size = Vector2(
		roundf(font_px * STRIPE_TO_FONT), maxf(2.0, roundf(font_px * SHADOW_RATIO))
	)
	_stripe.pivot_offset = Vector2(_stripe.size.x * 0.5, 0.0)


func _update_shine_area() -> void:
	var shine: ShaderMaterial = _title.material as ShaderMaterial
	if shine != null:
		shine.set_shader_parameter(TEXT_SIZE_PARAM, _title.size)
