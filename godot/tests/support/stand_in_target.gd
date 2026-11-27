class_name StandInTarget
extends CombatTarget
## Test support: a stand-in for the player mech. It sits where a test puts it,
## can be destroyed or made invulnerable, and records every hit it absorbs.

var at: Vector3 = Vector3.ZERO
var moving: Vector3 = Vector3.ZERO
var contact: float = 0.4
var alive: bool = true
var invulnerable: bool = false
## The first hit absorbed destroys it (Armor 0).
var fatal: bool = false
## Armor damage of every hit absorbed, in order.
var damage_taken: Array[int] = []


func _target_position() -> Vector3:
	return at


func _target_velocity() -> Vector3:
	return moving


func _target_radius() -> float:
	return contact


func _target_alive() -> bool:
	return alive


func _absorb(_source: DamageSource.Source, damage: int, _direction: Vector3) -> bool:
	if invulnerable:
		return false
	damage_taken.append(damage)
	if fatal:
		alive = false
	return true
