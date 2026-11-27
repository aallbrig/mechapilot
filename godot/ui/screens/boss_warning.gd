class_name BossWarning
extends UiScreen
## The Boss Warning (#73): a flashing "WARNING" banner with the boss's name
## and a red edge vignette, over the HUD, for the warning's duration.

const FLASH_PERIOD: float = 0.5
const FLASH_LOW_ALPHA: float = 0.25
const VIGNETTE_COLOR: Color = Color(1.0, 0.05, 0.1, 0.55)
const VIGNETTE_INNER: float = 0.55

var _banner: Label
var _boss_name: Label
var _vignette: TextureRect
var _flash: Tween
var _duration: float = 0.0


func _ready() -> void:
	_vignette = TextureRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.texture = _edge_texture()
	add_child(_vignette)
	var content: VBoxContainer = UiBuild.column(8)
	UiBuild.centered(self).add_child(content)
	_banner = UiBuild.label("WARNING", &"BannerLabel")
	_boss_name = UiBuild.paragraph("", &"HeaderLabel")
	content.add_child(_banner)
	content.add_child(_boss_name)


## The banner's lines: "WARNING" and the boss's name.
func lines() -> PackedStringArray:
	return PackedStringArray([_banner.text, _boss_name.text])


## How long the last warning lasts, in seconds.
func duration() -> float:
	return _duration


func _subscribe() -> void:
	var _ok: bool = _require([_bus.boss.boss_warning_started.connect(_on_boss_warning_started)])


func _on_boss_warning_started(boss_name: String, duration_seconds: float) -> void:
	_boss_name.text = "%s INCOMING" % boss_name.to_upper()
	_duration = duration_seconds


func _on_enter() -> void:
	cue(UiCue.Cue.WARNING)
	TweenFx.pop(_banner, TweenFx.POP_FROM)
	if _flash != null:
		_flash.kill()
	_flash = TweenFx.make(self).set_loops(maxi(ceili(_duration / FLASH_PERIOD), 1))
	var low: float = 1.0 if TweenFx.reduced_motion else FLASH_LOW_ALPHA
	var half: float = FLASH_PERIOD * 0.5
	var _down: PropertyTweener = _flash.tween_property(_banner, "modulate:a", low, half)
	var _up: PropertyTweener = _flash.tween_property(_banner, "modulate:a", 1.0, half)


func _on_leave() -> void:
	if _flash != null:
		_flash.kill()
		_flash = null
	_banner.modulate.a = 1.0


static func _edge_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(VIGNETTE_COLOR, 0.0))
	gradient.set_offset(0, VIGNETTE_INNER)
	gradient.set_color(1, VIGNETTE_COLOR)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture
