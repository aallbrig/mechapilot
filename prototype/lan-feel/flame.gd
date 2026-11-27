extends Node3D
## PROTOTYPE layered thruster flame. The exhaust points along local +Y.
## Inner core: short, near-white, additive cone. Outer plume: longer translucent
## cone (blue-white at the nozzle, then orange, red, gone), soft at the edges.
## Both scroll noise along their length. Thrust drives a spring, never a snap.
## Plus sparse sparks, optional smoke puffs and an optional flickering light.

## Spring that eases the flame toward the thrust target (1/s^2 and 1/s).
const POWER_STIFFNESS := 140.0
const POWER_DAMPING := 16.0
const CORE_LENGTH := Vector2(0.25, 0.7)
const PLUME_LENGTH := Vector2(0.5, 2.4)
const FLAME_SHADER := """
shader_type spatial;
render_mode unshaded, %s, depth_draw_never, cull_back, fog_disabled, shadows_disabled;

uniform vec4 nozzle_color : source_color;
uniform vec4 mid_color : source_color;
uniform vec4 tail_color : source_color;
uniform float intensity = 1.0;
uniform float height = 1.0;
uniform float scroll = 6.0;
uniform float edge_power = 1.5;
uniform float seed = 0.0;
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
	along = clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
}

void fragment() {
	float t = along;
	float n = vnoise(vec2(UV.x * 8.0 + seed, t * 5.0 - TIME * scroll));
	vec3 col = t < 0.2 ? mix(nozzle_color.rgb, mid_color.rgb, t / 0.2)
		: mix(mid_color.rgb, tail_color.rgb, clamp((t - 0.2) / 0.7, 0.0, 1.0));
	float edge = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), edge_power);
	float body = pow(1.0 - t, 1.3) * smoothstep(0.0, 0.06, t + 0.02);
	ALBEDO = col * (0.85 + 0.3 * n);
	ALPHA = clamp(body * edge * (0.55 + 0.6 * n) * intensity, 0.0, 1.0);
}
"""

static var _shaders := {}
static var _spark_mesh: QuadMesh
static var _smoke_mesh: QuadMesh

var size := 1.0
var power := 0.0
var power_vel := 0.0
var core: MeshInstance3D
var plume: MeshInstance3D
var core_mat: ShaderMaterial
var plume_mat: ShaderMaterial
var sparks: CPUParticles3D
var smoke: CPUParticles3D
var light: OmniLight3D
var _clock := 0.0
var _phase := 0.0


## size scales everything; main nozzles get smoke and a light.
func setup(flame_size: float, with_smoke: bool, with_light: bool) -> void:
	size = flame_size
	_phase = randf() * 10.0
	core_mat = _material("blend_add", Color(1, 1, 1), Color(1, 0.95, 0.6), Color(1, 0.7, 0.2))
	core_mat.set_shader_parameter("edge_power", 0.8)
	plume_mat = _material(
		"blend_mix", Color(0.75, 0.85, 1.0), Color(1.0, 0.55, 0.12), Color(0.85, 0.12, 0.05)
	)
	core = _cone(0.13 * size, core_mat)
	plume_mat.set_shader_parameter("edge_power", 1.0)
	plume = _cone(0.28 * size, plume_mat)
	sparks = _sparks()
	add_child(sparks)
	if with_smoke:
		smoke = _smoke()
		add_child(smoke)
	if with_light:
		light = OmniLight3D.new()
		light.light_color = Color(1, 0.65, 0.3)
		light.omni_range = 2.5 * size
		light.position = Vector3(0, 0.3 * size, 0)
		add_child(light)


func _material(blend: String, a: Color, b: Color, c: Color) -> ShaderMaterial:
	if not _shaders.has(blend):
		var sh := Shader.new()
		sh.code = FLAME_SHADER % blend
		_shaders[blend] = sh
	var m := ShaderMaterial.new()
	m.shader = _shaders[blend]
	m.set_shader_parameter("nozzle_color", a)
	m.set_shader_parameter("mid_color", b)
	m.set_shader_parameter("tail_color", c)
	m.set_shader_parameter("height", 1.0)
	m.set_shader_parameter("seed", randf() * 50.0)
	return m


## A unit-length cone, wide at the nozzle (local origin) and pointed at +Y.
func _cone(radius: float, mat: ShaderMaterial) -> MeshInstance3D:
	var pivot := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = radius
	cm.height = 1.0
	cm.radial_segments = 12
	cm.rings = 4
	cm.cap_top = false
	cm.cap_bottom = false
	pivot.mesh = cm
	pivot.material_override = mat
	pivot.position = Vector3(0, 0.5, 0)
	var root := Node3D.new()
	root.add_child(pivot)
	add_child(root)
	return pivot


func _soft_quad(color: Color, quad_size: float, additive: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * quad_size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	var fall := Gradient.new()
	fall.set_color(0, Color(1, 1, 1, 1))
	fall.set_color(1, Color(1, 1, 1, 0))
	soft.gradient = fall
	soft.width = 32
	soft.height = 32
	m.albedo_texture = soft
	q.material = m
	return q


func _sparks() -> CPUParticles3D:
	if _spark_mesh == null:
		_spark_mesh = _soft_quad(Color(1, 1, 1), 0.14, true)
	var p := CPUParticles3D.new()
	p.amount = 6
	p.lifetime = 0.22
	p.local_coords = false
	p.mesh = _spark_mesh
	p.direction = Vector3.UP
	p.spread = 14.0
	p.gravity = Vector3(0, -6, 0)
	p.initial_velocity_min = 10.0 * size
	p.initial_velocity_max = 18.0 * size
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.95, 0.6, 1))
	g.set_color(1, Color(1, 0.35, 0.05, 0))
	p.color_ramp = g
	if "inherit_velocity_ratio" in p:
		p.set("inherit_velocity_ratio", 0.5)
	p.emitting = true
	return p


func _smoke() -> CPUParticles3D:
	if _smoke_mesh == null:
		_smoke_mesh = _soft_quad(Color(1, 1, 1), 0.6, false)
	var p := CPUParticles3D.new()
	p.amount = 6
	p.lifetime = 0.9
	p.local_coords = false
	p.mesh = _smoke_mesh
	p.position = Vector3(0, 1.0 * size, 0)
	p.direction = Vector3.UP
	p.spread = 20.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.5
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.5 * size
	p.scale_amount_max = 0.9 * size
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.8))
	p.scale_amount_curve = grow
	var g := Gradient.new()
	g.set_color(0, Color(0.95, 0.9, 0.85, 0.3))
	g.set_color(1, Color(0.5, 0.5, 0.55, 0))
	p.color_ramp = g
	p.emitting = true
	return p


## target is the thrust 0..1; idle keeps a small pilot flame.
func drive(target: float, delta: float) -> void:
	_clock += delta
	var goal := clampf(maxf(target, 0.12), 0.0, 1.0)
	power_vel += (POWER_STIFFNESS * (goal - power) - POWER_DAMPING * power_vel) * delta
	power = clampf(power + power_vel * delta, 0.0, 1.3)
	var c := _clock * TAU
	var flicker := 1.0 + 0.12 * sin(c * 4.3 + _phase) + 0.07 * sin(c * 6.7 + _phase * 2.0)
	var core_len := lerpf(CORE_LENGTH.x, CORE_LENGTH.y, power) * size * flicker
	var plume_len := lerpf(PLUME_LENGTH.x, PLUME_LENGTH.y, power) * size * (0.5 + 0.5 * flicker)
	core.get_parent().scale = Vector3(1.0, core_len, 1.0)
	plume.get_parent().scale = Vector3(1.0 + power * 0.2, plume_len, 1.0 + power * 0.2)
	core_mat.set_shader_parameter("intensity", lerpf(0.7, 1.6, power) * flicker)
	plume_mat.set_shader_parameter("intensity", lerpf(0.6, 1.5, power))
	plume_mat.set_shader_parameter("scroll", lerpf(3.0, 9.0, power))
	sparks.emitting = power > 0.35
	sparks.speed_scale = lerpf(0.7, 1.4, power)
	if smoke != null:
		smoke.emitting = power > 0.3
	if light != null:
		light.light_energy = lerpf(0.2, 1.6, power) * flicker


func set_running(on: bool) -> void:
	sparks.emitting = on
	if smoke != null:
		smoke.emitting = on
