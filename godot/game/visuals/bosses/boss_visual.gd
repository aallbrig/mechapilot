class_name BossVisual
extends VisualRig
## A boss's model. Besides the rig's Hull, every boss has numbered turrets
## (`Turret<i>`, each a pivot logic aims, with its own `Turret<i>Muzzle`);
## numbered weak points (`WeakPoint<i>`, where hits count and damage glows);
## and one `Phase<N>` group per phase. Boss-specific parts (rotors, launch
## bays, shield nodes, a lance) are listed in extra_markers.

@export_range(0, 9) var turret_count: int = 0
@export_range(1, 9) var weak_point_count: int = 1
## Markers this boss has beyond the hull, turrets, weak points and phases.
@export var extra_markers: Array[StringName] = []


func required_markers() -> Array[StringName]:
	var names: Array[StringName] = super()
	for i: int in range(1, turret_count + 1):
		names.append(turret_name(i))
		names.append(turret_muzzle_name(i))
	for i: int in range(1, weak_point_count + 1):
		names.append(weak_point_name(i))
	names.append_array(extra_markers)
	return names


## The i-th (1-based) turret pivot.
func turret(index: int) -> Node3D:
	return marker(turret_name(index))


## Where the i-th turret's shots leave.
func turret_muzzle(index: int) -> Node3D:
	return marker(turret_muzzle_name(index))


## The i-th (1-based) weak point.
func weak_point(index: int) -> Node3D:
	return marker(weak_point_name(index))


static func turret_name(index: int) -> StringName:
	return indexed_name("Turret", index)


static func turret_muzzle_name(index: int) -> StringName:
	return StringName("%sMuzzle" % turret_name(index))


static func weak_point_name(index: int) -> StringName:
	return indexed_name("WeakPoint", index)
