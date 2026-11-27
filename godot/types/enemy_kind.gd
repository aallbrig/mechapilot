class_name EnemyKind
extends RefCounted
## The enemy roster of #73. Level data and Intel name kinds by their id.

enum Kind { FIGHTER, HEAVY, INTERCEPTOR, DRONE, BOMBER, ENEMY_MECH }

const IDS: Array[StringName] = [
	&"fighter", &"heavy", &"interceptor", &"drone", &"bomber", &"enemy_mech"
]


## The data id of a kind, as used in Level data and Intel.
static func id_of(kind: Kind) -> StringName:
	return IDS[kind]


## True when `id` names a kind.
static func is_id(id: StringName) -> bool:
	return IDS.has(id)


## The kind named by `id`. Check is_id() first: an unknown id is a programming
## error, pushes an error and returns FIGHTER.
static func from_id(id: StringName) -> Kind:
	var index: int = IDS.find(id)
	if index < 0:
		push_error("EnemyKind: unknown id %s" % id)
		return Kind.FIGHTER
	return index as Kind
