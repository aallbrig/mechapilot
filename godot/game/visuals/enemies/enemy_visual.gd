class_name EnemyVisual
extends VisualRig
## A regular enemy's model (Fighter, Heavy, Interceptor, Drone, Bomber, Enemy
## Mech), in the shared hostile material. Besides the rig's Hull, every enemy
## has a Muzzle (where its attack leaves, and where its 0.4 s telegraph glow
## shows) and an Exhaust. Extra markers, such as the Bomber's BombBay, are
## listed in extra_markers.

const MUZZLE: StringName = &"Muzzle"
const EXHAUST: StringName = &"Exhaust"

## Markers this enemy has beyond Hull, Muzzle and Exhaust (e.g. BombBay).
@export var extra_markers: Array[StringName] = []


func required_markers() -> Array[StringName]:
	var names: Array[StringName] = super()
	names.append_array([MUZZLE, EXHAUST])
	names.append_array(extra_markers)
	return names


## Every enemy wears the shared hostile material, recoloured against the
## Level's sky so it always reads (#135).
func piece_material() -> ShaderMaterial:
	return VisualPiece.HOSTILE_MATERIAL


func muzzle() -> Node3D:
	return marker(MUZZLE)


func exhaust() -> Node3D:
	return marker(EXHAUST)
