class_name ThrusterFlame
extends Node3D
## A layered thruster flame, ported from the LAN prototype. The exhaust points
## along local +Y. An inner core (short, near-white, additive) sits inside an
## outer plume (longer, translucent: blue-white at the nozzle, then orange, red,
## gone, soft at the edges). Both scroll noise along their length. Thrust drives
## a spring, never a snap, and idle keeps a small pilot flame. Sparse sparks,
## and optional smoke puffs complete it. No light: a positional light costs a
## pass per lit object in the Compatibility renderer, which the Gameplay
## draw-call budget cannot afford (#84); the flame's HDR colours bloom instead.

## Spring that eases the flame toward the thrust target (1/s^2 and 1/s).
const POWER_STIFFNESS: float = 140.0
const POWER_DAMPING: float = 16.0
const POWER_MAX: float = 1.3
## The pilot flame: thrust never drops below this.
const IDLE_POWER: float = 0.12
## Lengths at power 0 and 1 (units, before size).
const CORE_LENGTH: Vector2 = Vector2(0.25, 0.7)
const PLUME_LENGTH: Vector2 = Vector2(0.5, 2.4)
const CORE_RADIUS: float = 0.13
const PLUME_RADIUS: float = 0.28
const PLUME_SWELL: float = 0.2
const CORE_INTENSITY: Vector2 = Vector2(0.7, 1.6)
const PLUME_INTENSITY: Vector2 = Vector2(0.6, 1.5)
const PLUME_SCROLL: Vector2 = Vector2(3.0, 9.0)
const CORE_EDGE: float = 0.8
const PLUME_EDGE: float = 1.0
## Flicker: two sines (Hz) and their depths.
const FLICKER_A: Vector2 = Vector2(4.3, 0.12)
const FLICKER_B: Vector2 = Vector2(6.7, 0.07)
const SPARKS_FROM: float = 0.35
const SMOKE_FROM: float = 0.3
const SPARK_SPEED: Vector2 = Vector2(0.7, 1.4)
const CONE_SEGMENTS: int = 12
const CONE_RINGS: int = 4
const SEED_RANGE: float = 50.0
const PHASE_RANGE: float = 10.0
const FLAME_SHADER: String = """
shader_type spatial;
render_mode unshaded, %s, depth_draw_never, cull_back, fog_disabled, shadows_disabled;

uniform vec4 nozzle_color : source_color;
uniform vec4 mid_color : source_color;
uniform vec4 tail_color : source_color;
uniform float intensity = 1.0;
uniform float scroll = 6.0;
uniform float edge_power = 1.5;
uniform float noise_seed = 0.0;
varying float along;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	along = clamp(VERTEX.y + 0.5, 0.0, 1.0);
}

void fragment() {
	float t = along;
	float n = vnoise(vec2(UV.x * 8.0 + noise_seed, t * 5.0 - TIME * scroll));
	vec3 col = t < 0.2 ? mix(nozzle_color.rgb, mid_color.rgb, t / 0.2)
		: mix(mid_color.rgb, tail_color.rgb, clamp((t - 0.2) / 0.7, 0.0, 1.0));
	float edge = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), edge_power);
	float body = pow(1.0 - t, 1.3) * smoothstep(0.0, 0.06, t + 0.02);
	ALBEDO = col * (0.85 + 0.3 * n);
	ALPHA = clamp(body * edge * (0.55 + 0.6 * n) * intensity, 0.0, 1.0);
}
"""

static var _additive_shader: Shader
static var _mix_shader: Shader

## 0 (idle) to POWER_MAX: the spring-eased thrust.
var power: float = 0.0

var _size: float = 1.0
var _power_velocity: float = 0.0
var _core_root: Node3D = Node3D.new()
var _plume_root: Node3D = Node3D.new()
var _core_mat: ShaderMaterial
var _plume_mat: ShaderMaterial
var _sparks: CPUParticles3D
var _smoke: CPUParticles3D
var _clock: float = 0.0
var _phase: float = 0.0


## `flame_size` scales everything; main engines also get smoke.
func setup(flame_size: float, main_engine: bool, rng: RandomNumberGenerator) -> void:
	_size = flame_size
	_phase = rng.randf() * PHASE_RANGE
	_core_mat = _material(true, Color(1, 1, 1), Color(1, 0.95, 0.6), Color(1, 0.7, 0.2), rng)
	_core_mat.set_shader_parameter("edge_power", CORE_EDGE)
	_plume_mat = _material(
		false, Color(0.75, 0.85, 1.0), Color(1.0, 0.55, 0.12), Color(0.85, 0.12, 0.05), rng
	)
	_plume_mat.set_shader_parameter("edge_power", PLUME_EDGE)
	_cone(_core_root, CORE_RADIUS * _size, _core_mat)
	_cone(_plume_root, PLUME_RADIUS * _size, _plume_mat)
	_sparks = FlameParticles.sparks(_size)
	add_child(_sparks)
	if main_engine:
		_smoke = FlameParticles.smoke(_size)
		add_child(_smoke)
	drive(0.0, 0.0)


## Ease toward `target` thrust (0..1) over `delta` seconds.
func drive(target: float, delta: float) -> void:
	_clock += delta
	var goal: float = clampf(maxf(target, IDLE_POWER), 0.0, 1.0)
	_power_velocity += (POWER_STIFFNESS * (goal - power) - POWER_DAMPING * _power_velocity) * delta
	power = clampf(power + _power_velocity * delta, 0.0, POWER_MAX)
	var c: float = _clock * TAU
	var flicker: float = (
		1.0
		+ FLICKER_A.y * sin(c * FLICKER_A.x + _phase)
		+ FLICKER_B.y * sin(c * FLICKER_B.x + _phase * 2.0)
	)
	var core_len: float = lerpf(CORE_LENGTH.x, CORE_LENGTH.y, power) * _size * flicker
	var plume_len: float = (
		lerpf(PLUME_LENGTH.x, PLUME_LENGTH.y, power) * _size * (0.5 + 0.5 * flicker)
	)
	var swell: float = 1.0 + power * PLUME_SWELL
	_core_root.scale = Vector3(1.0, core_len, 1.0)
	_plume_root.scale = Vector3(swell, plume_len, swell)
	_core_mat.set_shader_parameter(
		"intensity", lerpf(CORE_INTENSITY.x, CORE_INTENSITY.y, power) * flicker
	)
	_plume_mat.set_shader_parameter("intensity", lerpf(PLUME_INTENSITY.x, PLUME_INTENSITY.y, power))
	_plume_mat.set_shader_parameter("scroll", lerpf(PLUME_SCROLL.x, PLUME_SCROLL.y, power))
	_sparks.emitting = power > SPARKS_FROM
	_sparks.speed_scale = lerpf(SPARK_SPEED.x, SPARK_SPEED.y, power)
	if _smoke != null:
		_smoke.emitting = power > SMOKE_FROM


## The plume's current length (units), for tests.
func plume_length() -> float:
	return _plume_root.scale.y


## Stop every particle (the mech broke apart).
func extinguish() -> void:
	power = 0.0
	_power_velocity = 0.0
	visible = false
	_sparks.emitting = false
	if _smoke != null:
		_smoke.emitting = false


func reignite() -> void:
	visible = true


func _material(
	additive: bool, nozzle: Color, mid: Color, tail: Color, rng: RandomNumberGenerator
) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader(additive)
	m.set_shader_parameter("nozzle_color", nozzle)
	m.set_shader_parameter("mid_color", mid)
	m.set_shader_parameter("tail_color", tail)
	m.set_shader_parameter("noise_seed", rng.randf() * SEED_RANGE)
	return m


static func _shader(additive: bool) -> Shader:
	if additive:
		if _additive_shader == null:
			_additive_shader = Shader.new()
			_additive_shader.code = FLAME_SHADER % "blend_add"
		return _additive_shader
	if _mix_shader == null:
		_mix_shader = Shader.new()
		_mix_shader.code = FLAME_SHADER % "blend_mix"
	return _mix_shader


## A unit-length cone, wide at the nozzle (the root's origin), pointed at +Y.
func _cone(root: Node3D, radius: float, mat: ShaderMaterial) -> void:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = radius
	cm.height = 1.0
	cm.radial_segments = CONE_SEGMENTS
	cm.rings = CONE_RINGS
	cm.cap_top = false
	cm.cap_bottom = false
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = cm
	mi.material_override = mat
	mi.position = Vector3(0.0, 0.5, 0.0)
	root.add_child(mi)
	add_child(root)
