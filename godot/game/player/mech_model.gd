class_name MechModel
extends Node3D
## The player mech's look: the merged flight-mech model from the visual pass
## (VisualLibrary.player_mech, #27), a port of the LAN prototype's design. A slim
## humanoid with two swept binder wings that carry the main thrusters, a beaked,
## crested head with three red eyes, rounded shoulders, tapered legs on thruster
## feet and a long arm cannon. Seen side-on, the body yaws to face left or right.
## Each piece is baked into one mesh, so the mech costs one draw per piece.
##
## It hands logic and feedback/ the model's joints and mounts under the names
## the animator was built on. Mounts for feedback/ (flames, eye trails) are
## plain Node3Ds: each nozzle's exhaust points along its local +Y (the model's
## markers point theirs along -Z, so each nozzle gets a +Y mount).

## Flame sizes: the wing thrusters are the main engines.
const WING_FLAME_SIZE: float = 1.0
const FOOT_FLAME_SIZE: float = 0.5
const SIDES: Array[float] = [-1.0, 1.0]
## Joint phases for the idle bob, so limbs don't swing in lockstep.
const ARM_PHASE: float = 2.0
## Left and right legs respond slightly differently.
const LEG_GAIN_SPREAD: float = 0.08
const SHIN_GAIN: float = 1.3
## Facing yaw: the model's forward (-Z) turns to +X or -X.
const FACE_YAW: float = PI / 2.0
## Turns a mount's +Y onto a marker's -Z (the exhaust direction).
const EXHAUST_MOUNT: Basis = Basis(Vector3.RIGHT, -PI / 2.0)

var body: Node3D
var head: Node3D
var gun_pivot: Node3D
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

var _visual: PlayerMechVisual = VisualLibrary.player_mech()
var _flashing: bool = false


func _init() -> void:
	add_child(_visual)
	body = _visual.body()
	head = _visual.head()
	gun_pivot = _visual.gun_pivot()
	for side_index: int in SIDES.size():
		var side: float = SIDES[side_index]
		arms.append(_visual.arm(side_index))
		arm_phases.append(side * ARM_PHASE)
		thighs.append(_visual.thigh(side_index))
		thigh_phases.append(side)
		thigh_gains.append(1.0 + side * LEG_GAIN_SPREAD)
		shins.append(_visual.shin(side_index))
		wings.append(_visual.wing(side_index))
		wing_sides.append(side)
		wing_tips.append(_visual.wing_tip(side_index))
		main_nozzles.append(_mount(_visual.wing_nozzle(side_index)))
		foot_nozzles.append(_mount(_visual.foot_nozzle(side_index)))
	eyes.assign(_visual.eyes())


## The merged model shown (VisualLibrary's player mech).
func visual() -> PlayerMechVisual:
	return _visual


## World position of the cannon's muzzle.
func muzzle_position() -> Vector3:
	return _visual.muzzle().global_position


func wing_tip_positions() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var _sized: int = out.resize(wing_tips.size())
	for i: int in wing_tips.size():
		out[i] = wing_tips[i].global_position
	return out


## Every baked piece, for the death ragdoll.
func meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	out.assign(_visual.pieces())
	return out


## Draw every piece white (the hit flash) or normally.
func set_flash(on: bool) -> void:
	if on == _flashing:
		return
	_flashing = on
	_visual.set_flash(on)


func is_flashing() -> bool:
	return _flashing


## The yaw that faces +X (facing 1) or -X (facing -1).
static func yaw_for(facing: float) -> float:
	return -FACE_YAW * facing


## A feedback mount on `marker` whose +Y is the marker's exhaust (-Z).
static func _mount(marker: Node3D) -> Node3D:
	var mount: Node3D = Node3D.new()
	mount.basis = EXHAUST_MOUNT
	marker.add_child(mount)
	return mount
