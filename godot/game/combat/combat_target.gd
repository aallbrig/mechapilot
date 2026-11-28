class_name CombatTarget
extends RefCounted
## What enemies and bosses chase, aim at and hit: the player mech, seen through
## a narrow seam so enemy logic never reaches into the mech's nodes. Hits are
## distance checks on the XY play plane, so a target is a point with a contact
## radius.
##
## strike() is the one way to damage the target. It maps the source to its
## Armor damage (RunRules.damage_for), lets the concrete target absorb the hit
## (the mech's own invulnerability window may refuse it), and only then reports
## the hit to the Run ledger as `Events.player.player_hit`.
##
## Subclasses override the _target_* and _absorb methods.

var _events: EventBus


func _init(events: EventBus) -> void:
	_events = events


## Where the target is on the play plane (z = 0).
func position() -> Vector3:
	var at: Vector3 = _target_position()
	return Vector3(at.x, at.y, 0.0)


## How fast it moves (units/s), for leading shots.
func velocity() -> Vector3:
	return _target_velocity()


## Contact radius (units).
func radius() -> float:
	return _target_radius()


## False while destroyed (between a lost life and the respawn).
func is_alive() -> bool:
	return _target_alive()


## Hit the target with `source`. `attack_damage` is the boss attack's own
## damage (ignored for other sources). `direction` is the way the hit travels,
## for knockback. Returns true when the hit landed and was reported.
func strike(source: DamageSource.Source, attack_damage: int, direction: Vector3) -> bool:
	if not is_alive():
		return false
	if not _absorb(source, RunRules.damage_for(source, attack_damage), direction):
		return false
	_events.player.announce_player_hit(source, position(), attack_damage)
	return true


func _target_position() -> Vector3:
	return Vector3.ZERO


func _target_velocity() -> Vector3:
	return Vector3.ZERO


func _target_radius() -> float:
	return 0.0


func _target_alive() -> bool:
	return false


## Take `damage` from `source` along `direction`; false when the target
## refuses the hit.
func _absorb(_source: DamageSource.Source, _damage: int, _direction: Vector3) -> bool:
	return false
