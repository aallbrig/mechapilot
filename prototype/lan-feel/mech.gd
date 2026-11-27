extends Node3D
## PROTOTYPE flying mech (throwaway, an original design). Slim humanoid with two
## swept binder wings that carry the main thrusters, a beaked crested head with
## three red eyes, rounded shoulders, tapered legs on thruster feet and a long arm
## cannon. Seen side-on: the body yaws to face left or right.
## Limbs are hand-rolled spring-dampers on joint angles (rotation.x in the body
## frame: positive swings a hanging limb forward, negative trails it back). Two
## tuning groups, THRUST_* (input held: streamlined, stiff) and COAST_* (input
## released: loose, dangling), blend over POSE_BLEND_TIME.

# ---- pose blend
const POSE_BLEND_TIME := 0.15

# ---- THRUST: stick or keys held. Streamlined flying pose, stiff and damped.
const THRUST_THIGH_REST := -0.6
const THRUST_SHIN_REST := -0.08
const THRUST_ARM_REST := -0.75
const THRUST_WING_REST := 0.35
const THRUST_LEG_SPRING := Vector2(95.0, 17.0)
const THRUST_SHIN_SPRING := Vector2(120.0, 18.0)
const THRUST_ARM_SPRING := Vector2(100.0, 17.0)
const THRUST_WING_SPRING := Vector2(80.0, 13.0)
const THRUST_VEL_LAG := 0.012
const THRUST_ACC_LAG := 0.1
## Max body lean toward the direction of travel (rad).
const THRUST_LEAN := 1.15

# ---- COAST: input released. Loose springs, limbs dangle and flail.
const COAST_THIGH_REST := 0.15
const COAST_SHIN_REST := -0.45
const COAST_ARM_REST := 0.15
const COAST_WING_REST := -0.3
const COAST_LEG_SPRING := Vector2(14.0, 1.0)
const COAST_SHIN_SPRING := Vector2(18.0, 1.2)
const COAST_ARM_SPRING := Vector2(12.0, 0.8)
const COAST_WING_SPRING := Vector2(16.0, 1.5)
const COAST_VEL_LAG := 0.05
const COAST_ACC_LAG := 0.5
## How strongly dangling limbs keep pointing at world-down as the body tilts.
const COAST_GRAVITY := 0.85
## Lazy body tilt with the velocity (rad per unit/s), and its follow rate.
const COAST_TILT := 0.025
const COAST_TILT_RATE := 1.5

# ---- shared
const CLIMB_LAG := 0.03
const SHIN_COUPLING := 0.7
const IDLE_BOB := 0.06
const MAX_ANGLE := 1.8
const RECOIL_KICK := 3.0
const DEBRIS_GRAVITY := 24.0
const DEBRIS_LIFE := 2.2
const EYE_TRAIL_PARTICLES := 8
## Muzzle of the arm cannon in gun_pivot space.
const MUZZLE := Vector3(0, 0, -2.1)
## Exhaust directions (in the parent's frame) for the wing and foot thrusters.
const WING_EXHAUST := Vector3(0, -0.35, 1.0)
const FOOT_EXHAUST := Vector3(0, -1.0, 0.3)
## Binder wing segments, root to tip: (length, chord, sweep back).
const WING_SEGMENTS: Array[Vector3] = [
	Vector3(0.75, 0.85, 0.0), Vector3(0.65, 0.6, 0.14), Vector3(0.55, 0.36, 0.28)
]

const COL_WHITE := Color(0.92, 0.92, 0.88)
const COL_GREY := Color(0.55, 0.58, 0.63)
const COL_FRAME := Color(0.12, 0.16, 0.36)
const COL_RED := Color(0.85, 0.1, 0.12)

const Flame := preload("res://flame.gd")


class Joint:
	var node: Node3D
	var angle := 0.0
	var vel := 0.0
	var phase := 0.0
	var gain := 1.0


class Debris:
	var node: MeshInstance3D
	var mat: StandardMaterial3D
	var vel := Vector3.ZERO
	var axis := Vector3.UP
	var spin := 0.0
	var life := DEBRIS_LIFE


var body: Node3D
var gun_pivot: Node3D
var thighs: Array[Joint] = []
var shins: Array[Joint] = []
var arms: Array[Joint] = []
var wings: Array[Joint] = []
var flames: Array[Flame] = []
var wing_tips: Array[Node3D] = []
var debris: Array[Debris] = []
var eye_trails: Array[CPUParticles3D] = []
## 0 = coasting, 1 = thrusting.
var fly := 0.0
var lateral_g := 0.0
var _last_vel := Vector3.ZERO
var _acc := Vector3.ZERO
var _clock := 0.0
var _mats := {}


func _ready() -> void:
	body = Node3D.new()
	body.rotation.y = -PI / 2.0
	add_child(body)
	var white := _mat(COL_WHITE)
	var grey := _mat(COL_GREY)
	var frame := _mat(COL_FRAME)
	var red := _mat(COL_RED)
	_box(body, Vector3(0.62, 0.45, 0.5), Vector3(0, 0.25, 0), white)
	_box(body, Vector3(0.22, 0.1, 0.05), Vector3(0, 0.3, -0.26), red)
	_box(body, Vector3(0.36, 0.32, 0.38), Vector3(0, -0.1, 0), frame)
	_box(body, Vector3(0.5, 0.16, 0.44), Vector3(0, -0.32, 0), grey)
	_box(body, Vector3(0.42, 0.45, 0.3), Vector3(0, 0.2, 0.36), frame)
	_build_head(white, red)
	for side: float in [-1.0, 1.0]:
		_build_shoulder(side, white, grey, frame)
		_build_leg(side, white, grey, frame, red)
		_build_wing(side, white, grey, frame, red)
	gun_pivot = Node3D.new()
	gun_pivot.position = Vector3(0, 0.28, 0.5)
	add_child(gun_pivot)
	_box(gun_pivot, Vector3(0.2, 0.22, 0.8), Vector3(0, 0, -0.2), white)
	_box(gun_pivot, Vector3(0.14, 0.1, 0.5), Vector3(0, 0.13, -0.3), frame)
	var barrel := _cyl(gun_pivot, 0.05, 1.5, Vector3(0, 0, -1.25), grey)
	barrel.rotation.x = PI / 2.0
	_box(gun_pivot, Vector3(0.13, 0.13, 0.1), Vector3(0, 0, -2.0), red)


func _build_head(white: Material, red: Material) -> void:
	var head := Node3D.new()
	head.position = Vector3(0, 0.62, -0.02)
	body.add_child(head)
	_box(head, Vector3(0.3, 0.26, 0.34), Vector3.ZERO, white)
	var beak := _cyl(head, 0.0, 0.42, Vector3(0, -0.03, -0.36), white, 0.13, 4)
	beak.rotation.x = -PI / 2.0
	var crest := _box(head, Vector3(0.03, 0.34, 0.3), Vector3(0, 0.25, 0.06), red)
	crest.rotation.x = 0.55
	var eye_mesh := _particle_quad(Color(1, 0.15, 0.1), 0.12)
	var eye_mat := _mat(Color(1, 0.08, 0.05), 7.0)
	for at: Vector3 in [
		Vector3(0.09, 0.04, -0.19), Vector3(-0.09, 0.04, -0.19), Vector3(0, 0.11, -0.2)
	]:
		var eye := _box(head, Vector3(0.07, 0.06, 0.06), at, eye_mat)
		var trail := CPUParticles3D.new()
		trail.amount = EYE_TRAIL_PARTICLES
		trail.lifetime = 0.22
		trail.local_coords = false
		trail.mesh = eye_mesh
		trail.gravity = Vector3.ZERO
		trail.initial_velocity_max = 0.0
		var shrink := Curve.new()
		shrink.add_point(Vector2(0, 1))
		shrink.add_point(Vector2(1, 0.2))
		trail.scale_amount_curve = shrink
		var g := Gradient.new()
		g.set_color(0, Color(1, 0.2, 0.15, 0.5))
		g.set_color(1, Color(1, 0.1, 0.1, 0))
		trail.color_ramp = g
		eye.add_child(trail)
		eye_trails.append(trail)


func _build_shoulder(side: float, white: Material, grey: Material, frame: Material) -> void:
	var pad := _sphere(body, 0.24, Vector3(0.45 * side, 0.38, 0), white)
	pad.scale = Vector3(1.0, 0.85, 1.15)
	var arm := _joint(Vector3(0.45 * side, 0.3, 0), side * 2.0)
	_box(arm.node, Vector3(0.13, 0.38, 0.13), Vector3(0, -0.22, 0), frame)
	_box(arm.node, Vector3(0.17, 0.36, 0.2), Vector3(0, -0.55, 0), white)
	_box(arm.node, Vector3(0.12, 0.12, 0.12), Vector3(0, -0.78, 0), grey)
	arms.append(arm)


func _build_leg(
	side: float, white: Material, grey: Material, frame: Material, red: Material
) -> void:
	var thigh := _joint(Vector3(0.15 * side, -0.38, 0), side)
	thigh.gain = 1.0 + side * 0.08
	_box(thigh.node, Vector3(0.16, 0.5, 0.2), Vector3(0, -0.25, 0), frame)
	_box(thigh.node, Vector3(0.2, 0.32, 0.24), Vector3(0, -0.2, -0.03), white)
	thighs.append(thigh)
	var shin := Joint.new()
	shin.node = Node3D.new()
	shin.node.position = Vector3(0, -0.52, 0)
	thigh.node.add_child(shin.node)
	shin.gain = 1.3
	_box(shin.node, Vector3(0.12, 0.1, 0.1), Vector3(0, 0, -0.12), red)
	_cyl(shin.node, 0.13, 0.62, Vector3(0, -0.32, 0), white, 0.08)
	_box(shin.node, Vector3(0.2, 0.2, 0.42), Vector3(0, -0.68, -0.04), grey)
	_box(shin.node, Vector3(0.16, 0.08, 0.16), Vector3(0, -0.79, 0.06), frame)
	var f := _flame(shin.node, Vector3(0, -0.83, 0.06), FOOT_EXHAUST, 0.5, false)
	f.name = "FootFlame"
	shins.append(shin)


## A swept, flat binder wing with its main thruster pod built into the root.
func _build_wing(
	side: float, white: Material, grey: Material, frame: Material, red: Material
) -> void:
	var w := _joint(Vector3(0.22 * side, 0.35, 0.4), side)
	wings.append(w)
	var plate := Node3D.new()
	plate.rotation = Vector3(0.75, 0, -0.25 * side)
	w.node.add_child(plate)
	# Tapered, swept panel built from segments: (length, chord, sweep back).
	var y := 0.0
	for seg: Vector3 in WING_SEGMENTS:
		var mid := Vector3(0, y + seg.x * 0.5, seg.z)
		_box(plate, Vector3(0.05, seg.x, seg.y), mid, grey)
		_box(plate, Vector3(0.07, seg.x, 0.1), mid + Vector3(0, 0, -seg.y * 0.5), white)
		_box(plate, Vector3(0.06, seg.x * 0.9, 0.12), mid + Vector3(0, 0, seg.y * 0.45), frame)
		y += seg.x
	_box(plate, Vector3(0.08, 0.14, 0.3), Vector3(0, y, 0.24), red)
	var tip := Node3D.new()
	tip.position = Vector3(0, y + 0.05, 0.3)
	plate.add_child(tip)
	wing_tips.append(tip)
	var dir := WING_EXHAUST.normalized()
	var pod := _cyl(w.node, 0.14, 0.75, Vector3(0, -0.05, 0.25), white, 0.17)
	pod.basis = Basis(Quaternion(Vector3.UP, dir))
	_flame(w.node, Vector3(0, -0.05, 0.25) + dir * 0.38, dir, 1.0, true)


func _flame(parent: Node3D, at: Vector3, dir: Vector3, flame_size: float, main: bool) -> Flame:
	var f := Flame.new()
	f.position = at
	f.basis = Basis(Quaternion(Vector3.UP, dir.normalized()))
	parent.add_child(f)
	f.setup(flame_size, main, main)
	flames.append(f)
	return f


func _mat(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mesh(parent, bm, pos, mat)


func _cyl(
	parent: Node3D,
	top: float,
	height: float,
	pos: Vector3,
	mat: Material,
	bottom: float = -1.0,
	segments: int = 12
) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = top if bottom < 0.0 else bottom
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	return _mesh(parent, cm, pos, mat)


func _sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	return _mesh(parent, sm, pos, mat)


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _particle_quad(color: Color, size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	return q


func _joint(pos: Vector3, phase: float) -> Joint:
	var j := Joint.new()
	j.node = Node3D.new()
	j.node.position = pos
	j.phase = phase
	body.add_child(j.node)
	return j


func muzzle_position() -> Vector3:
	return gun_pivot.global_transform * MUZZLE


func wing_tip_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for t in wing_tips:
		out.append(t.global_position)
	return out


## Advance pose, springs and flames. velocity is world-space, facing is +1 or -1,
## thrust is the move-input magnitude 0..1.
func step(delta: float, velocity: Vector3, facing: float, thrust: float = 0.0) -> void:
	if delta <= 0.0:
		return
	_clock += delta
	var raw_acc := (velocity - _last_vel) / delta
	_last_vel = velocity
	_acc = _acc.lerp(raw_acc, 0.5)
	var vdir := velocity.normalized() if velocity.length() > 0.5 else Vector3.ZERO
	var lat := (raw_acc - vdir * raw_acc.dot(vdir)).length()
	lateral_g = lerpf(lateral_g, lat, 1.0 - exp(-6.0 * delta))
	fly = move_toward(fly, 1.0 if thrust > 0.15 else 0.0, delta / POSE_BLEND_TIME)

	var yaw := -PI / 2.0 * facing
	body.rotation.y = lerp_angle(body.rotation.y, yaw, 1.0 - exp(-12.0 * delta))
	var fwd_vel := velocity.x * facing
	var lean := -clampf(atan2(fwd_vel, velocity.y) * 0.75, -0.9, THRUST_LEAN)
	if velocity.length() < 2.0:
		lean = 0.0
	var coast_tilt := clampf(velocity.y * COAST_TILT * facing - fwd_vel * 0.02, -0.5, 0.5)
	var pitch_goal := lerpf(coast_tilt, lean, fly)
	var rate := lerpf(COAST_TILT_RATE, 9.0, fly)
	body.rotation.x = lerpf(body.rotation.x, pitch_goal, 1.0 - exp(-rate * delta))
	body.position.y = sin(_clock * 2.2) * 0.05 * (1.0 - fly)

	var vel_lag := lerpf(COAST_VEL_LAG, THRUST_VEL_LAG, fly)
	var acc_lag := lerpf(COAST_ACC_LAG, THRUST_ACC_LAG, fly)
	var drive := -fwd_vel * vel_lag - velocity.y * CLIMB_LAG * (1.0 - fly)
	var push := -_acc.x * facing * acc_lag - _acc.y * acc_lag * 0.4
	var hang := -body.rotation.x * COAST_GRAVITY * (1.0 - fly)
	var bob := IDLE_BOB * (1.0 - fly)
	var leg_k := COAST_LEG_SPRING.lerp(THRUST_LEG_SPRING, fly)
	var shin_k := COAST_SHIN_SPRING.lerp(THRUST_SHIN_SPRING, fly)
	var arm_k := COAST_ARM_SPRING.lerp(THRUST_ARM_SPRING, fly)
	var wing_k := COAST_WING_SPRING.lerp(THRUST_WING_SPRING, fly)
	var thigh_rest := lerpf(COAST_THIGH_REST, THRUST_THIGH_REST, fly)
	var shin_rest := lerpf(COAST_SHIN_REST, THRUST_SHIN_REST, fly)
	var arm_rest := lerpf(COAST_ARM_REST, THRUST_ARM_REST, fly)
	var wing_rest := lerpf(COAST_WING_REST, THRUST_WING_REST, fly)
	for j in thighs:
		var t := thigh_rest + drive * j.gain + hang + sin(_clock * 2.4 + j.phase) * bob
		_spring(j, t, push * j.gain, leg_k, delta)
	for i in shins.size():
		var s := shins[i]
		var couple := -thighs[i].vel * SHIN_COUPLING * shin_k.x * 0.1 * (1.0 - fly * 0.7)
		_spring(s, shin_rest + drive * 0.4, push * s.gain + couple, shin_k, delta)
	for j in arms:
		var t := arm_rest + drive * 0.7 + hang + sin(_clock * 2.0 + j.phase) * bob
		_spring(j, t, push * 0.8, arm_k, delta)
	for w in wings:
		var sway := sin(_clock * 1.7 + w.phase) * 0.03
		_spring(w, wing_rest + sway, push * 0.2, wing_k, delta)
		w.node.rotation.z = w.phase * w.angle * 0.5
	for f in flames:
		f.drive(thrust, delta)
	var moving := velocity.length() > 3.0
	for t in eye_trails:
		t.emitting = moving


func _spring(j: Joint, target: float, force: float, k: Vector2, delta: float) -> void:
	j.vel += (k.x * (target - j.angle) - k.y * j.vel + force) * delta
	j.angle = clampf(j.angle + j.vel * delta, -MAX_ANGLE, MAX_ANGLE)
	j.node.rotation.x = j.angle


## Kick every limb as if the body were shoved along world direction `push`.
func impulse(push: Vector3, facing: float) -> void:
	var fwd := push.x * facing
	for j: Joint in thighs + shins + arms:
		j.vel += (-fwd - push.y * 0.4) * RECOIL_KICK * j.gain + randf_range(-0.6, 0.6)


## Break into tumbling parts. The intact mech hides until reset().
func shatter(velocity: Vector3) -> void:
	var center := global_position
	for mi in _meshes(self):
		if not mi.material_override is StandardMaterial3D:
			continue
		var d := Debris.new()
		d.node = MeshInstance3D.new()
		d.node.mesh = mi.mesh
		d.mat = (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		d.mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		d.node.material_override = d.mat
		get_parent().add_child(d.node)
		d.node.global_transform = mi.global_transform
		var out := d.node.global_position - center
		out.z = 0.0
		var dir := out.normalized() if out.length() > 0.05 else Vector3.UP
		d.vel = velocity * 0.5 + dir * randf_range(5.0, 12.0) + Vector3(0, randf_range(3.0, 9.0), 0)
		d.vel.z = randf_range(-2.0, 2.0)
		d.axis = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		d.spin = randf_range(5.0, 16.0)
		d.life = DEBRIS_LIFE * randf_range(0.8, 1.2)
		debris.append(d)
	visible = false


func reset() -> void:
	visible = true
	_last_vel = Vector3.ZERO
	_acc = Vector3.ZERO
	lateral_g = 0.0
	fly = 0.0
	for j: Joint in thighs + shins + arms + wings:
		j.angle = 0.0
		j.vel = 0.0
		j.node.rotation.x = 0.0


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c as MeshInstance3D)
		out.append_array(_meshes(c))
	return out


func _process(delta: float) -> void:
	for d: Debris in debris.duplicate():
		d.life -= delta
		if d.life <= 0.0:
			d.node.queue_free()
			debris.erase(d)
			continue
		d.vel.y -= DEBRIS_GRAVITY * delta
		d.vel *= 1.0 - 0.4 * delta
		d.node.global_position += d.vel * delta
		d.node.global_basis = Basis(d.axis, d.spin * delta) * d.node.global_basis
		d.mat.albedo_color.a = clampf(d.life, 0.0, 1.0)
