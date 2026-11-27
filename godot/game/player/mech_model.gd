class_name MechModel
extends Node3D
## The player mech's look: an original flight-type design from the LAN prototype.
## A slim humanoid with two swept binder wings that carry the main thrusters, a
## beaked, crested head with three red eyes, rounded shoulders, tapered legs on
## thruster feet and a long arm cannon. Seen side-on, the body yaws to face left
## or right. Built from primitive meshes, so it can be swapped for a modelled
## scene later (#27) as long as it keeps these joints and mounts.
##
## Mounts for feedback/ (flames, eye trails) are plain Node3Ds: each nozzle's
## exhaust points along its local +Y.

const COL_WHITE: Color = Color(0.92, 0.92, 0.88)
const COL_GREY: Color = Color(0.55, 0.58, 0.63)
const COL_FRAME: Color = Color(0.12, 0.16, 0.36)
const COL_RED: Color = Color(0.85, 0.1, 0.12)
const COL_EYE: Color = Color(1.0, 0.08, 0.05)
const EYE_GLOW: float = 7.0
## Muzzle of the arm cannon in gun_pivot space.
const MUZZLE: Vector3 = Vector3(0.0, 0.0, -2.1)
## Exhaust directions (in the joint's frame) for the wing and foot thrusters.
const WING_EXHAUST: Vector3 = Vector3(0.0, -0.35, 1.0)
const FOOT_EXHAUST: Vector3 = Vector3(0.0, -1.0, 0.3)
## Flame sizes: the wing thrusters are the main engines.
const WING_FLAME_SIZE: float = 1.0
const FOOT_FLAME_SIZE: float = 0.5
## Binder wing segments, root to tip: (length, chord, sweep back).
const WING_SEGMENTS: Array[Vector3] = [
	Vector3(0.75, 0.85, 0.0), Vector3(0.65, 0.6, 0.14), Vector3(0.55, 0.36, 0.28)
]
## The eyes, in head space: two side by side and one above, between them.
const EYE_POSITIONS: Array[Vector3] = [
	Vector3(0.09, 0.04, -0.19), Vector3(-0.09, 0.04, -0.19), Vector3(0.0, 0.11, -0.2)
]
const SIDES: Array[float] = [-1.0, 1.0]
## Joint phases for the idle bob, so limbs don't swing in lockstep.
const ARM_PHASE: float = 2.0
## Left and right legs respond slightly differently.
const LEG_GAIN_SPREAD: float = 0.08
const SHIN_GAIN: float = 1.3
## Facing yaw: the model's forward (-Z) turns to +X or -X.
const FACE_YAW: float = PI / 2.0

var body: Node3D = Node3D.new()
var head: Node3D = Node3D.new()
var gun_pivot: Node3D = Node3D.new()
var thighs: Array[Node3D] = []
var shins: Array[Node3D] = []
var arms: Array[Node3D] = []
var wings: Array[Node3D] = []
var wing_tips: Array[Node3D] = []
## Wing thrusters (main engines) and foot thrusters.
var main_nozzles: Array[Node3D] = []
var foot_nozzles: Array[Node3D] = []
var eyes: Array[Node3D] = []
## Per-joint animation hints, parallel to thighs, shins, arms and wings.
var thigh_phases: Array[float] = []
var thigh_gains: Array[float] = []
var arm_phases: Array[float] = []
var wing_sides: Array[float] = []

var _meshes: Array[MeshInstance3D] = []
var _flash_material: StandardMaterial3D = StandardMaterial3D.new()
var _flashing: bool = false


func _init() -> void:
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.albedo_color = Color.WHITE
	body.rotation.y = -FACE_YAW
	add_child(body)
	var white: StandardMaterial3D = _mat(COL_WHITE)
	var grey: StandardMaterial3D = _mat(COL_GREY)
	var frame: StandardMaterial3D = _mat(COL_FRAME)
	var red: StandardMaterial3D = _mat(COL_RED)
	_box(body, Vector3(0.62, 0.45, 0.5), Vector3(0.0, 0.25, 0.0), white)
	_box(body, Vector3(0.22, 0.1, 0.05), Vector3(0.0, 0.3, -0.26), red)
	_box(body, Vector3(0.36, 0.32, 0.38), Vector3(0.0, -0.1, 0.0), frame)
	_box(body, Vector3(0.5, 0.16, 0.44), Vector3(0.0, -0.32, 0.0), grey)
	_box(body, Vector3(0.42, 0.45, 0.3), Vector3(0.0, 0.2, 0.36), frame)
	_build_head(white, red)
	for side: float in SIDES:
		_build_shoulder(side, white, grey, frame)
		_build_leg(side, white, grey, frame, red)
		_build_wing(side, white, grey, frame, red)
	_build_cannon(white, grey, frame, red)


## World position of the cannon's muzzle.
func muzzle_position() -> Vector3:
	return gun_pivot.global_transform * MUZZLE


func wing_tip_positions() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var _sized: int = out.resize(wing_tips.size())
	for i: int in wing_tips.size():
		out[i] = wing_tips[i].global_position
	return out


## Every mesh part, for the hit flash and the death ragdoll.
func meshes() -> Array[MeshInstance3D]:
	return _meshes


## Draw every part white (the hit flash) or normally.
func set_flash(on: bool) -> void:
	if on == _flashing:
		return
	_flashing = on
	for mi: MeshInstance3D in _meshes:
		mi.material_overlay = _flash_material if on else null


func is_flashing() -> bool:
	return _flashing


## The yaw that faces +X (facing 1) or -X (facing -1).
static func yaw_for(facing: float) -> float:
	return -FACE_YAW * facing


func _build_head(white: StandardMaterial3D, red: StandardMaterial3D) -> void:
	head.position = Vector3(0.0, 0.62, -0.02)
	body.add_child(head)
	_box(head, Vector3(0.3, 0.26, 0.34), Vector3.ZERO, white)
	var beak: MeshInstance3D = _new_cyl(head, 0.0, 0.42, Vector3(0.0, -0.03, -0.36), white, 0.13, 4)
	beak.rotation.x = -PI / 2.0
	var crest: MeshInstance3D = _new_box(
		head, Vector3(0.03, 0.34, 0.3), Vector3(0.0, 0.25, 0.06), red
	)
	crest.rotation.x = 0.55
	var eye_mat: StandardMaterial3D = _mat(COL_EYE, EYE_GLOW)
	for at: Vector3 in EYE_POSITIONS:
		eyes.append(_new_box(head, Vector3(0.07, 0.06, 0.06), at, eye_mat))


func _build_shoulder(
	side: float, white: StandardMaterial3D, grey: StandardMaterial3D, frame: StandardMaterial3D
) -> void:
	var pad: MeshInstance3D = _new_sphere(body, 0.24, Vector3(0.45 * side, 0.38, 0.0), white)
	pad.scale = Vector3(1.0, 0.85, 1.15)
	var arm: Node3D = _joint(body, Vector3(0.45 * side, 0.3, 0.0))
	_box(arm, Vector3(0.13, 0.38, 0.13), Vector3(0.0, -0.22, 0.0), frame)
	_box(arm, Vector3(0.17, 0.36, 0.2), Vector3(0.0, -0.55, 0.0), white)
	_box(arm, Vector3(0.12, 0.12, 0.12), Vector3(0.0, -0.78, 0.0), grey)
	arms.append(arm)
	arm_phases.append(side * ARM_PHASE)


func _build_leg(
	side: float,
	white: StandardMaterial3D,
	grey: StandardMaterial3D,
	frame: StandardMaterial3D,
	red: StandardMaterial3D
) -> void:
	var thigh: Node3D = _joint(body, Vector3(0.15 * side, -0.38, 0.0))
	_box(thigh, Vector3(0.16, 0.5, 0.2), Vector3(0.0, -0.25, 0.0), frame)
	_box(thigh, Vector3(0.2, 0.32, 0.24), Vector3(0.0, -0.2, -0.03), white)
	thighs.append(thigh)
	thigh_phases.append(side)
	thigh_gains.append(1.0 + side * LEG_GAIN_SPREAD)
	var shin: Node3D = _joint(thigh, Vector3(0.0, -0.52, 0.0))
	_box(shin, Vector3(0.12, 0.1, 0.1), Vector3(0.0, 0.0, -0.12), red)
	_cyl(shin, 0.13, 0.62, Vector3(0.0, -0.32, 0.0), white, 0.08)
	_box(shin, Vector3(0.2, 0.2, 0.42), Vector3(0.0, -0.68, -0.04), grey)
	_box(shin, Vector3(0.16, 0.08, 0.16), Vector3(0.0, -0.79, 0.06), frame)
	foot_nozzles.append(_nozzle(shin, Vector3(0.0, -0.83, 0.06), FOOT_EXHAUST))
	shins.append(shin)


## A swept, flat binder wing with its main thruster pod built into the root.
func _build_wing(
	side: float,
	white: StandardMaterial3D,
	grey: StandardMaterial3D,
	frame: StandardMaterial3D,
	red: StandardMaterial3D
) -> void:
	var wing: Node3D = _joint(body, Vector3(0.22 * side, 0.35, 0.4))
	wings.append(wing)
	wing_sides.append(side)
	var plate: Node3D = Node3D.new()
	plate.rotation = Vector3(0.75, 0.0, -0.25 * side)
	wing.add_child(plate)
	var y: float = 0.0
	for seg: Vector3 in WING_SEGMENTS:
		var mid: Vector3 = Vector3(0.0, y + seg.x * 0.5, seg.z)
		_box(plate, Vector3(0.05, seg.x, seg.y), mid, grey)
		_box(plate, Vector3(0.07, seg.x, 0.1), mid + Vector3(0.0, 0.0, -seg.y * 0.5), white)
		_box(plate, Vector3(0.06, seg.x * 0.9, 0.12), mid + Vector3(0.0, 0.0, seg.y * 0.45), frame)
		y += seg.x
	_box(plate, Vector3(0.08, 0.14, 0.3), Vector3(0.0, y, 0.24), red)
	var tip: Node3D = Node3D.new()
	tip.position = Vector3(0.0, y + 0.05, 0.3)
	plate.add_child(tip)
	wing_tips.append(tip)
	var dir: Vector3 = WING_EXHAUST.normalized()
	var pod: MeshInstance3D = _new_cyl(wing, 0.14, 0.75, Vector3(0.0, -0.05, 0.25), white, 0.17)
	pod.basis = Basis(Quaternion(Vector3.UP, dir))
	main_nozzles.append(_nozzle(wing, Vector3(0.0, -0.05, 0.25) + dir * 0.38, dir))


func _build_cannon(
	white: StandardMaterial3D,
	grey: StandardMaterial3D,
	frame: StandardMaterial3D,
	red: StandardMaterial3D
) -> void:
	gun_pivot.position = Vector3(0.0, 0.28, 0.5)
	add_child(gun_pivot)
	_box(gun_pivot, Vector3(0.2, 0.22, 0.8), Vector3(0.0, 0.0, -0.2), white)
	_box(gun_pivot, Vector3(0.14, 0.1, 0.5), Vector3(0.0, 0.13, -0.3), frame)
	var barrel: MeshInstance3D = _new_cyl(gun_pivot, 0.05, 1.5, Vector3(0.0, 0.0, -1.25), grey)
	barrel.rotation.x = PI / 2.0
	_box(gun_pivot, Vector3(0.13, 0.13, 0.1), Vector3(0.0, 0.0, -2.0), red)


func _joint(parent: Node3D, at: Vector3) -> Node3D:
	var j: Node3D = Node3D.new()
	j.position = at
	parent.add_child(j)
	return j


func _nozzle(parent: Node3D, at: Vector3, exhaust: Vector3) -> Node3D:
	var n: Node3D = Node3D.new()
	n.position = at
	n.basis = Basis(Quaternion(Vector3.UP, exhaust.normalized()))
	parent.add_child(n)
	return n


func _mat(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var _part: MeshInstance3D = _new_box(parent, size, at, mat)


func _new_box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	return _mesh(parent, bm, at, mat)


func _cyl(
	parent: Node3D, top: float, height: float, at: Vector3, mat: Material, bottom: float = -1.0
) -> void:
	var _part: MeshInstance3D = _new_cyl(parent, top, height, at, mat, bottom)


func _new_cyl(
	parent: Node3D,
	top: float,
	height: float,
	at: Vector3,
	mat: Material,
	bottom: float = -1.0,
	segments: int = 12
) -> MeshInstance3D:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = top if bottom < 0.0 else bottom
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	return _mesh(parent, cm, at, mat)


func _new_sphere(parent: Node3D, radius: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	return _mesh(parent, sm, at, mat)


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	_meshes.append(mi)
	return mi
