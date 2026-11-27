class_name ScreenOverlay
extends CanvasLayer
## Full-screen juice drawn over the sky and under the screens (#26, #73):
##
##   damage vignette   a red edge that flares on every hit, stronger for
##                     bigger hits, then fades; a steady glow while Armor is low
##   boss warning      a red edge that pulses for the Boss Warning
##   desaturate        the world drains to grey when the mech is destroyed and
##                     comes back on respawn, a new Run or the Title
##
## It runs in real time, so hit-stop and slow-mo never freeze it. Reduced motion
## stops the pulsing (the edges hold steady instead). Canvas shaders only, so it
## is safe in the Compatibility renderer; the desaturate pass is hidden while it
## is not in use, so it costs nothing in normal play.

## Below the default canvas layer: over the 3D world, under every screen.
const LAYER: int = -1
## A hit flares to DAMAGE_BASE plus DAMAGE_PER_POINT per Armor lost, at most 1.
const DAMAGE_BASE: float = 0.35
const DAMAGE_PER_POINT: float = 0.02
## How fast a hit's flare fades (intensity per second).
const DAMAGE_FADE: float = 1.6
## Armor at or below this share of the maximum glows the edge.
const LOW_ARMOR_SHARE: float = 0.3
const LOW_ARMOR_LEVEL: float = 0.35
const WARNING_LEVEL: float = 0.8
## Pulse rate of the warning and low-Armor edges (radians per second).
const PULSE_SPEED: float = 9.0
## How fast the world drains to grey and back (per second).
const DESATURATE_SPEED: float = 2.5
const VIGNETTE_SHADER: String = """
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.9, 0.05, 0.05, 1.0);
uniform float intensity = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p * vec2(1.0, 0.85));
	float edge = smoothstep(0.55, 1.45, d);
	COLOR = vec4(tint.rgb, tint.a * edge * clamp(intensity, 0.0, 1.0));
}
"""
const DESATURATE_SHADER: String = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float amount = 0.0;

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c, vec3(grey) * 0.85, clamp(amount, 0.0, 1.0)), 1.0);
}
"""

var _real_time: RealClock = RealClock.new()
var _vignette: ColorRect = ColorRect.new()
var _desaturate: ColorRect = ColorRect.new()
var _vignette_material: ShaderMaterial = ShaderMaterial.new()
var _desaturate_material: ShaderMaterial = ShaderMaterial.new()
var _damage: float = 0.0
var _low_armor: bool = false
var _warning_left: float = 0.0
var _desaturation: float = 0.0
var _desaturate_to: float = 0.0
var _pulse_clock: float = 0.0
var _pulses: bool = true


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_desaturate_material.shader = _shader(DESATURATE_SHADER)
	_vignette_material.shader = _shader(VIGNETTE_SHADER)
	for rect: ColorRect in [_desaturate, _vignette]:
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.color = Color.WHITE
		add_child(rect)
	_desaturate.material = _desaturate_material
	_vignette.material = _vignette_material
	_show()


func _process(_delta: float) -> void:
	advance(_real_time.step())


## Subscribe to `bus` (the Events autoload, or a test bus).
func bind(bus: EventBus) -> void:
	(
		BusLinks
		. require_ok(
			"ScreenOverlay",
			[
				bus.player.armor_changed.connect(_on_armor_changed),
				bus.player.player_destroyed.connect(_on_player_destroyed),
				bus.player.player_respawned.connect(_on_restored),
				bus.run.run_started.connect(_on_run_started),
				bus.boss.boss_warning_started.connect(_on_boss_warning_started),
				bus.flow.game_state_changed.connect(_on_game_state_changed),
				bus.profile.settings_changed.connect(_on_settings_changed),
			]
		)
	)


## Move the overlay on by `real_delta` seconds of real time.
func advance(real_delta: float) -> void:
	_pulse_clock += real_delta
	_damage = maxf(0.0, _damage - DAMAGE_FADE * real_delta)
	_warning_left = maxf(0.0, _warning_left - real_delta)
	_desaturation = move_toward(_desaturation, _desaturate_to, DESATURATE_SPEED * real_delta)
	_show()


## The red edge's strength now (0..1).
func vignette() -> float:
	var level: float = _damage
	if _low_armor:
		level = maxf(level, LOW_ARMOR_LEVEL * _pulse())
	if _warning_left > 0.0:
		level = maxf(level, WARNING_LEVEL * _pulse())
	return minf(level, 1.0)


## How grey the world is now (0..1).
func desaturation() -> float:
	return _desaturation


## True while the desaturate pass draws at all.
func desaturating() -> bool:
	return _desaturate.visible


func _pulse() -> float:
	if not _pulses:
		return 1.0
	return 0.6 + 0.4 * sin(_pulse_clock * PULSE_SPEED)


func _show() -> void:
	var level: float = vignette()
	_vignette.visible = level > 0.0
	_vignette_material.set_shader_parameter(&"intensity", level)
	_desaturate.visible = _desaturation > 0.0
	_desaturate_material.set_shader_parameter(&"amount", _desaturation)


func _clear() -> void:
	_damage = 0.0
	_low_armor = false
	_warning_left = 0.0
	_desaturate_to = 0.0
	_desaturation = 0.0
	_show()


static func _shader(code: String) -> Shader:
	var shader: Shader = Shader.new()
	shader.code = code
	return shader


func _on_armor_changed(armor: int, max_armor: int, delta: int) -> void:
	if delta < 0:
		_damage = minf(1.0, maxf(_damage, DAMAGE_BASE + DAMAGE_PER_POINT * float(-delta)))
	_low_armor = armor > 0 and float(armor) <= float(max_armor) * LOW_ARMOR_SHARE
	_show()


func _on_player_destroyed(_position: Vector3, _cause: DestroyCause.Cause) -> void:
	_low_armor = false
	_desaturate_to = 1.0
	_show()


func _on_restored() -> void:
	_desaturate_to = 0.0


func _on_run_started(_level_number: int) -> void:
	_clear()


func _on_boss_warning_started(_boss_name: String, duration: float) -> void:
	_warning_left = duration
	_show()


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	if to == GameState.Phase.TITLE or to == GameState.Phase.LEVEL_CLEAR:
		_clear()


func _on_settings_changed(settings: GameSettings) -> void:
	_pulses = JuiceSettings.flashes(settings)
