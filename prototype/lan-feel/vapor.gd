extends Node3D
## PROTOTYPE vapor effects for hard turns (world space, child of the scene root):
## a translucent shock-collar cone that opens backward along the velocity, and two
## thin wingtip ribbons that fade over TRAIL_LIFE. Both scale with lateral g.

## Lateral acceleration (units/s^2) where vapor starts, and where it is at full.
const G_MIN := 16.5
const G_FULL := 52.0
const TRAIL_LIFE := 0.5
const TRAIL_WIDTH := 0.06
const CONE_SHADER := """
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


class Trail:
	var mesh := ImmediateMesh.new()
	var points: Array[Vector3] = []
	var ages: Array[float] = []
	var weights: Array[float] = []


var strength := 0.0
var cone: MeshInstance3D
var cone_mat: ShaderMaterial
var trails: Array[Trail] = []
var _was_on := false


func _ready() -> void:
	cone = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = 1.1
	cm.height = 1.0
	cm.radial_segments = 20
	cm.rings = 3
	cm.cap_top = false
	cm.cap_bottom = false
	cone.mesh = cm
	var sh := Shader.new()
	sh.code = CONE_SHADER
	cone_mat = ShaderMaterial.new()
	cone_mat.shader = sh
	cone.material_override = cone_mat
	cone.visible = false
	add_child(cone)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.vertex_color_use_as_albedo = true
	for i in 2:
		var tr := Trail.new()
		var mi := MeshInstance3D.new()
		mi.mesh = tr.mesh
		mi.material_override = rm
		add_child(mi)
		trails.append(tr)


## center and tips are world positions; k scales sizes with the mech.
func update(
	delta: float,
	center: Vector3,
	velocity: Vector3,
	lateral_g: float,
	tips: Array[Vector3],
	k: float
) -> void:
	var target := 0.0
	if velocity.length() > 4.0:
		target = clampf((lateral_g - G_MIN) / (G_FULL - G_MIN), 0.0, 1.0)
	strength = move_toward(strength, target, delta * (6.0 if target > strength else 2.5))
	if strength > 0.35 and not _was_on:
		_was_on = true
		Events.vapor_burst.emit(strength)
	elif strength < 0.1:
		_was_on = false
	cone.visible = strength > 0.01
	if cone.visible:
		var y := velocity.normalized()
		var x := y.cross(Vector3.BACK).normalized()
		var z := x.cross(y)
		var s := k * (1.2 + 0.6 * strength)
		cone.global_transform = Transform3D(Basis(x * s, y * s * 1.4, z * s), center + y * 0.3 * k)
		cone_mat.set_shader_parameter("strength", strength)
	for i in trails.size():
		var tip := tips[i] if i < tips.size() else center
		_update_trail(trails[i], delta, tip, k)


func _update_trail(tr: Trail, delta: float, tip: Vector3, k: float) -> void:
	for i in tr.ages.size():
		tr.ages[i] += delta
	while not tr.ages.is_empty() and tr.ages[0] > TRAIL_LIFE:
		tr.ages.pop_front()
		tr.points.pop_front()
		tr.weights.pop_front()
	if strength > 0.05:
		tr.points.append(tip)
		tr.ages.append(0.0)
		tr.weights.append(strength)
	tr.mesh.clear_surfaces()
	if tr.points.size() < 2:
		return
	tr.mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in tr.points.size():
		var p := tr.points[i]
		var nxt := tr.points[mini(i + 1, tr.points.size() - 1)]
		var prv := tr.points[maxi(i - 1, 0)]
		var dir := (nxt - prv).normalized()
		var n := Vector3(-dir.y, dir.x, 0) * TRAIL_WIDTH * k * (0.5 + tr.weights[i])
		var a := (1.0 - tr.ages[i] / TRAIL_LIFE) * tr.weights[i] * 0.7
		tr.mesh.surface_set_color(Color(1, 1, 1, a))
		tr.mesh.surface_add_vertex(p + n)
		tr.mesh.surface_set_color(Color(1, 1, 1, a))
		tr.mesh.surface_add_vertex(p - n)
	tr.mesh.surface_end()


func clear() -> void:
	strength = 0.0
	cone.visible = false
	for tr in trails:
		tr.points.clear()
		tr.ages.clear()
		tr.weights.clear()
		tr.mesh.clear_surfaces()
