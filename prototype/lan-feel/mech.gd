extends Node3D
## PROTOTYPE flying mech (throwaway). Seen side-on. The body yaws to face left or
## right; legs (thigh + shin) and arms are secondary motion driven by hand-rolled
## spring-dampers on their joint angles. On death it shatters into tumbling parts.
## Joint angles are rotation.x in the body frame: positive swings a hanging limb
## forward (toward facing), negative trails it back.

# ---- tuning (rad, rad/s, per-unit gains)
const LEG_STIFFNESS := 34.0
const LEG_DAMPING := 4.0
const SHIN_STIFFNESS := 55.0
const SHIN_DAMPING := 4.5
const ARM_STIFFNESS := 48.0
const ARM_DAMPING := 4.5
## Sustained trailing per unit/s of forward speed.
const VEL_LAG := 0.045
## Legs back/down when climbing, float up/forward when diving, per unit/s.
const CLIMB_LAG := 0.035
## Angular acceleration per unit/s^2 of body acceleration (the "lag").
const ACC_LAG := 0.32
## How much the knee reacts to the thigh's angular velocity.
const SHIN_COUPLING := 0.7
const IDLE_BOB := 0.07
const MAX_ANGLE := 1.7
const RECOIL_KICK := 3.0
const DEBRIS_GRAVITY := 24.0
const DEBRIS_LIFE := 2.2


class Joint:
	var node: Node3D
	var rest := 0.0
	var angle := 0.0
	var vel := 0.0
	var stiffness := 30.0
	var damping := 4.0
	var vel_gain := 1.0
	var acc_gain := 1.0
	var phase := 0.0


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
var debris: Array[Debris] = []
var _last_vel := Vector3.ZERO
var _acc := Vector3.ZERO
var _clock := 0.0
var _mats := {}


func _ready() -> void:
	body = Node3D.new()
	body.rotation.y = -PI / 2.0
	add_child(body)
	var hull := _mat(Color(0.72, 0.78, 0.85))
	var dark := _mat(Color(0.2, 0.24, 0.3))
	var accent := _mat(Color(0.1, 0.9, 1.0), 3.0)
	var jet := _mat(Color(1, 0.5, 0.1), 4.0)
	_box(body, Vector3(1.4, 1.0, 1.0), Vector3(0, 0.0, 0), hull)
	var head := Node3D.new()
	head.position = Vector3(0, 0.7, -0.05)
	body.add_child(head)
	_box(head, Vector3(0.7, 0.45, 0.6), Vector3.ZERO, hull)
	_box(head, Vector3(0.5, 0.15, 0.1), Vector3(0, 0.02, -0.33), accent)
	_box(body, Vector3(0.6, 0.8, 0.5), Vector3(0, 0.1, 0.7), dark)
	_box(body, Vector3(0.3, 0.3, 0.2), Vector3(0, -0.15, 1.0), jet)
	for side: float in [-1.0, 1.0]:
		var thigh := _joint(Vector3(0.42 * side, -0.45, 0), LEG_STIFFNESS, LEG_DAMPING, 0.15)
		thigh.vel_gain = 1.0 + side * 0.1
		thigh.phase = side
		_box(thigh.node, Vector3(0.38, 0.8, 0.45), Vector3(0, -0.38, 0), dark)
		thighs.append(thigh)
		var shin := Joint.new()
		shin.node = Node3D.new()
		shin.node.position = Vector3(0, -0.78, 0)
		thigh.node.add_child(shin.node)
		shin.rest = -0.35
		shin.angle = shin.rest
		shin.stiffness = SHIN_STIFFNESS
		shin.damping = SHIN_DAMPING
		shin.acc_gain = 1.3
		_box(shin.node, Vector3(0.32, 0.72, 0.4), Vector3(0, -0.36, 0), hull)
		_box(shin.node, Vector3(0.45, 0.15, 0.75), Vector3(0, -0.74, -0.12), dark)
		shins.append(shin)
		var arm := _joint(Vector3(0.9 * side, 0.3, 0), ARM_STIFFNESS, ARM_DAMPING, 0.1)
		arm.vel_gain = 0.7
		arm.acc_gain = 0.8
		arm.phase = side * 2.0
		_box(arm.node, Vector3(0.35, 0.85, 0.35), Vector3(0, -0.35, 0), hull)
		arms.append(arm)
	gun_pivot = Node3D.new()
	gun_pivot.position = Vector3(0, 0.2, 0.75)
	add_child(gun_pivot)
	_box(gun_pivot, Vector3(0.3, 0.3, 1.6), Vector3(0, 0, -0.6), dark)
	_box(gun_pivot, Vector3(0.2, 0.2, 0.3), Vector3(0, 0, -1.45), accent)


func _mat(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _joint(pos: Vector3, k: float, c: float, rest: float) -> Joint:
	var j := Joint.new()
	j.node = Node3D.new()
	j.node.position = pos
	body.add_child(j.node)
	j.stiffness = k
	j.damping = c
	j.rest = rest
	j.angle = rest
	return j


## Advance the body pose and limb springs. velocity is world-space, facing is +1 or -1.
func step(delta: float, velocity: Vector3, facing: float) -> void:
	if delta <= 0.0:
		return
	_clock += delta
	var raw_acc := (velocity - _last_vel) / delta
	_last_vel = velocity
	_acc = _acc.lerp(raw_acc, 0.5)
	var yaw := -PI / 2.0 * facing
	body.rotation.y = lerp_angle(body.rotation.y, yaw, 1.0 - exp(-12.0 * delta))
	var pitch := clampf(velocity.y * 0.035 * facing, -0.45, 0.45)
	body.rotation.x = lerpf(body.rotation.x, pitch, 1.0 - exp(-8.0 * delta))
	body.position.y = sin(_clock * 2.2) * 0.06

	var fwd_vel := velocity.x * facing
	var fwd_acc := _acc.x * facing
	var drive := -fwd_vel * VEL_LAG - velocity.y * CLIMB_LAG
	var push := -fwd_acc * ACC_LAG - _acc.y * ACC_LAG * 0.4
	for j in thighs:
		var bob := sin(_clock * 2.4 + j.phase) * IDLE_BOB
		_spring(j, j.rest + drive * j.vel_gain + bob, push * j.acc_gain, delta)
	for i in shins.size():
		var s := shins[i]
		var couple := -thighs[i].vel * SHIN_COUPLING
		_spring(s, s.rest + drive * 0.4, push * s.acc_gain + couple * s.stiffness * 0.1, delta)
	for j in arms:
		var bob := sin(_clock * 2.0 + j.phase) * IDLE_BOB
		_spring(j, j.rest + drive * j.vel_gain + bob, push * j.acc_gain, delta)


func _spring(j: Joint, target: float, force: float, delta: float) -> void:
	j.vel += (j.stiffness * (target - j.angle) - j.damping * j.vel + force) * delta
	j.angle = clampf(j.angle + j.vel * delta, -MAX_ANGLE, MAX_ANGLE)
	j.node.rotation.x = j.angle


## Kick every limb as if the body were shoved along world direction `push`.
func impulse(push: Vector3, facing: float) -> void:
	var fwd := push.x * facing
	for j: Joint in thighs + shins + arms:
		j.vel += (-fwd - push.y * 0.4) * RECOIL_KICK * j.acc_gain + randf_range(-0.6, 0.6)


## Break into tumbling parts. The intact mech hides until reset().
func shatter(velocity: Vector3) -> void:
	var center := global_position
	for mi in _meshes(self):
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
	for j: Joint in thighs + shins + arms:
		j.angle = j.rest
		j.vel = 0.0
		j.node.rotation.x = j.rest


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
