class_name PlayerTarget
extends CombatTarget
## The player mech as enemies and bosses see it (the CombatTarget seam): where
## it is, how fast it flies, its contact radius and whether it is in play.
##
## A strike reaches the mech through PlayerMech.take_hit(), which refuses it
## while the mech's invulnerability window is open. The window is the
## RunLedger's: once a hit is reported as `player_hit`, the ledger announces
## invulnerability_started and PlayerBusLink opens it on the mech within the
## same call. So contact that repeats every frame (an enemy or a boss hull, a
## lance charge) lands once per window, and CombatTarget.strike() stays the one
## place `player_hit` is announced.

var _mech: PlayerMech


func _init(events: EventBus, mech: PlayerMech) -> void:
	super(events)
	_mech = mech


func _target_position() -> Vector3:
	return _mech.global_position if _mech.is_inside_tree() else _mech.position


func _target_velocity() -> Vector3:
	return _mech.velocity


func _target_radius() -> float:
	return _mech.contact_radius()


func _target_alive() -> bool:
	return _mech.is_alive()


func _absorb(source: DamageSource.Source, damage: int, direction: Vector3) -> bool:
	return _mech.take_hit(source, direction, damage)
