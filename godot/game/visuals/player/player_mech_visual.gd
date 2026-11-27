class_name PlayerMechVisual
extends VisualRig
## The player's flight mech: an original design with swept binder wings carrying
## the main thrusters, a beaked crested head with three red eyes, rounded
## shoulders, an arm cannon and thruster feet (the LAN prototype is the reference).
## Logic drives the named pivots; their rest pose is all zero rotations except
## Body, which yaws -PI/2 so the mech faces +X. As in the prototype, a limb's
## rotation.x swings it (positive forward, negative trailing back) and the wing
## pivots also roll on rotation.z. GunPivot sits outside Body so the cannon can
## aim freely; its Muzzle is on the barrel's -Z axis. Like every marker, the
## thruster nozzles point their local -Z along the exhaust.

## Side indices for the paired limbs (the mech's own left and right).
const LEFT: int = 0
const RIGHT: int = 1
const BODY: StringName = &"Body"
const HEAD: StringName = &"Head"
const GUN_PIVOT: StringName = &"GunPivot"
const MUZZLE: StringName = &"Muzzle"
const ARMS: Array[StringName] = [&"ArmL", &"ArmR"]
const THIGHS: Array[StringName] = [&"ThighL", &"ThighR"]
const SHINS: Array[StringName] = [&"ShinL", &"ShinR"]
const WINGS: Array[StringName] = [&"WingL", &"WingR"]
const WING_NOZZLES: Array[StringName] = [&"WingNozzleL", &"WingNozzleR"]
const FOOT_NOZZLES: Array[StringName] = [&"FootNozzleL", &"FootNozzleR"]
const WING_TIPS: Array[StringName] = [&"WingTipL", &"WingTipR"]
const EYES: Array[StringName] = [&"EyeL", &"EyeR", &"EyeC"]


## Every pivot and marker of the mech frame (shared by the Crimson Lancer).
static func frame_markers() -> Array[StringName]:
	var names: Array[StringName] = [BODY, HEAD, GUN_PIVOT, MUZZLE]
	for family: Array[StringName] in [ARMS, THIGHS, SHINS, WINGS, WING_NOZZLES, FOOT_NOZZLES]:
		names.append_array(family)
	names.append_array(WING_TIPS)
	names.append_array(EYES)
	return names


func required_markers() -> Array[StringName]:
	var names: Array[StringName] = super()
	names.append_array(frame_markers())
	return names


func body() -> Node3D:
	return marker(BODY)


func head() -> Node3D:
	return marker(HEAD)


func gun_pivot() -> Node3D:
	return marker(GUN_PIVOT)


func muzzle() -> Node3D:
	return marker(MUZZLE)


func arm(side: int) -> Node3D:
	return marker(ARMS[side])


func thigh(side: int) -> Node3D:
	return marker(THIGHS[side])


func shin(side: int) -> Node3D:
	return marker(SHINS[side])


func wing(side: int) -> Node3D:
	return marker(WINGS[side])


func wing_nozzle(side: int) -> Node3D:
	return marker(WING_NOZZLES[side])


func foot_nozzle(side: int) -> Node3D:
	return marker(FOOT_NOZZLES[side])


func wing_tip(side: int) -> Node3D:
	return marker(WING_TIPS[side])


func eyes() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for eye: StringName in EYES:
		out.append(marker(eye))
	return out
