class_name VaporCone
extends Node3D
## Vapor on hard turns, ported from the LAN prototype. In world space: a
## translucent shock-collar cone that opens backward along the velocity, and two
## thin wingtip ribbons that fade over TRAIL_LIFE. Both scale with lateral g.


class Ribbon:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	var points: Array[Vector3] = []
	var ages: Array[float] = []
	var weights: Array[float] = []


## The vapor came on strongly (for a whoosh, #26).
signal burst(strength: float)

## Lateral acceleration (units/s^2) where vapor starts, and where it is full.
const G_MIN: float = 16.5
const G_FULL: float = 52.0
## No vapor below this speed (units/s).
const MIN_SPEED: float = 4.0
## Strength rises and falls at these rates (1/s).
const RISE_RATE: float = 6.0
const FALL_RATE: float = 2.5
## Strength above which a burst is announced, and below which it re-arms.
const BURST_ON: float = 0.35
const BURST_RESET: float = 0.1
const VISIBLE_FROM: float = 0.01
const RIBBON_FROM: float = 0.05
const TRAIL_LIFE: float = 0.5
const TRAIL_WIDTH: float = 0.06
const TRAIL_ALPHA: float = 0.7
const RIBBONS: int = 2
## Cone size: base scale plus strength share; length stretch; offset forward.
const CONE_SCALE: Vector2 = Vector2(1.2, 0.6)
const CONE_STRETCH: float = 1.4
const CONE_LEAD: float = 0.3
const CONE_TOP: float = 0.08
const CONE_BOTTOM: float = 1.1
const CONE_SEGMENTS: int = 20
const CONE_RINGS: int = 3
const CONE_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform float strength = 0.0;
varying float along;

void vertex() {
	along = clamp(VERTEX.y + 0.5, 0.0, 1.0);
}

void fragment() {
	float t = 1.0 - along;
	float ring = pow(sin(t * 3.14159), 1.5);
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	float streak = 0.75 + 0.25 * sin(UV.x * 40.0 + TIME * 3.0);
	ALBEDO = vec3(1.0);
	ALPHA = clamp(strength * ring * (0.25 + 0.75 * rim) * streak * 0.7, 0.0, 1.0);
}
"""

var strength: float = 0.0

var _cone: MeshInstance3D = MeshInstance3D.new()
var _cone_mat: ShaderMaterial = ShaderMaterial.new()
var _ribbons: Array[Ribbon] = []
var _armed: bool = true


func _init() -> void:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = CONE_TOP
	cm.bottom_radius = CONE_BOTTOM
	cm.height = 1.0
	cm.radial_segments = CONE_SEGMENTS
	cm.rings = CONE_RINGS
	cm.cap_top = false
	cm.cap_bottom = false
	_cone.mesh = cm
	var sh: Shader = Shader.new()
	sh.code = CONE_SHADER
	_cone_mat.shader = sh
	_cone.material_override = _cone_mat
	_cone.visible = false
	add_child(_cone)
	var rm: StandardMaterial3D = StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.vertex_color_use_as_albedo = true
	for _i: int in RIBBONS:
		var ribbon: Ribbon = Ribbon.new()
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = ribbon.mesh
		mi.material_override = rm
		add_child(mi)
		_ribbons.append(ribbon)


## React to one frame of the mech's motion.
func on_motion(sample: MechMotionSample) -> void:
	var delta: float = sample.delta
	var target: float = 0.0
	if sample.velocity.length() > MIN_SPEED:
		target = clampf((sample.lateral_g - G_MIN) / (G_FULL - G_MIN), 0.0, 1.0)
	var rate: float = RISE_RATE if target > strength else FALL_RATE
	strength = move_toward(strength, target, delta * rate)
	if strength > BURST_ON and _armed:
		_armed = false
		burst.emit(strength)
	elif strength < BURST_RESET:
		_armed = true
	_cone.visible = strength > VISIBLE_FROM
	var k: float = sample.scale
	if _cone.visible:
		var y: Vector3 = sample.velocity.normalized()
		var x: Vector3 = y.cross(Vector3.BACK).normalized()
		var z: Vector3 = x.cross(y)
		var s: float = k * (CONE_SCALE.x + CONE_SCALE.y * strength)
		_cone.global_transform = Transform3D(
			Basis(x * s, y * s * CONE_STRETCH, z * s), sample.position + y * CONE_LEAD * k
		)
		_cone_mat.set_shader_parameter("strength", strength)
	for i: int in _ribbons.size():
		var tip: Vector3 = sample.wing_tips[i] if i < sample.wing_tips.size() else sample.position
		_update_ribbon(_ribbons[i], delta, tip, k)


func cone_visible() -> bool:
	return _cone.visible


func clear() -> void:
	strength = 0.0
	_cone.visible = false
	for ribbon: Ribbon in _ribbons:
		ribbon.points.clear()
		ribbon.ages.clear()
		ribbon.weights.clear()
		ribbon.mesh.clear_surfaces()


func _update_ribbon(ribbon: Ribbon, delta: float, tip: Vector3, k: float) -> void:
	for i: int in ribbon.ages.size():
		ribbon.ages[i] += delta
	while not ribbon.ages.is_empty() and ribbon.ages[0] > TRAIL_LIFE:
		ribbon.ages.remove_at(0)
		ribbon.points.remove_at(0)
		ribbon.weights.remove_at(0)
	if strength > RIBBON_FROM:
		ribbon.points.append(tip)
		ribbon.ages.append(0.0)
		ribbon.weights.append(strength)
	ribbon.mesh.clear_surfaces()
	var count: int = ribbon.points.size()
	if count < 2:
		return
	ribbon.mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in count:
		var p: Vector3 = ribbon.points[i]
		var dir: Vector3 = (
			(ribbon.points[mini(i + 1, count - 1)] - ribbon.points[maxi(i - 1, 0)]).normalized()
		)
		var n: Vector3 = Vector3(-dir.y, dir.x, 0.0) * TRAIL_WIDTH * k * (0.5 + ribbon.weights[i])
		var a: float = (1.0 - ribbon.ages[i] / TRAIL_LIFE) * ribbon.weights[i] * TRAIL_ALPHA
		ribbon.mesh.surface_set_color(Color(1, 1, 1, a))
		ribbon.mesh.surface_add_vertex(p + n)
		ribbon.mesh.surface_set_color(Color(1, 1, 1, a))
		ribbon.mesh.surface_add_vertex(p - n)
	ribbon.mesh.surface_end()
