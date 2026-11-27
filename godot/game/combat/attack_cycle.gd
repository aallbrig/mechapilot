class_name AttackCycle
extends RefCounted
## The rhythm of one attack: cool down, telegraph (a flash or charge glow), then
## fire (#73: every attack is telegraphed). The telegraph never lasts less than
## RunRules.MIN_TELEGRAPH, whatever the data says, and a shot never fires
## without the full telegraph before it: if the attack is held (no target, out
## of range, entering), a charge in progress is cancelled and starts over.
##
## tick() reports at most one step per call, so a caller can react to the
## charge starting and to the shot separately.

enum Step { NONE, TELEGRAPH, FIRE }

## Seconds from one shot to the next (cooldown plus telegraph).
var interval: float = 0.0
## Seconds of charge glow before each shot.
var telegraph: float = 0.0

var _cooldown: float = 0.0
var _charge_left: float = -1.0


## `first_delay` is the cooldown before the first telegraph.
func _init(interval_seconds: float, telegraph_seconds: float, first_delay: float) -> void:
	telegraph = maxf(telegraph_seconds, RunRules.MIN_TELEGRAPH)
	interval = maxf(interval_seconds, telegraph)
	_cooldown = maxf(first_delay, 0.0)


## Advance by `delta` seconds. `ready` is false while the attack must hold.
func tick(delta: float, ready: bool) -> Step:
	if not ready:
		if is_telegraphing():
			_charge_left = -1.0
			_cooldown = 0.0
		return Step.NONE
	if is_telegraphing():
		_charge_left -= delta
		if _charge_left <= 0.0:
			_charge_left = -1.0
			_cooldown = interval - telegraph
			return Step.FIRE
		return Step.NONE
	_cooldown -= delta
	if _cooldown <= 0.0:
		_charge_left = telegraph
		return Step.TELEGRAPH
	return Step.NONE


## True while the charge glow shows.
func is_telegraphing() -> bool:
	return _charge_left >= 0.0


## The charge so far, 0 (just started or idle) to 1 (about to fire).
func charge() -> float:
	if not is_telegraphing():
		return 0.0
	return clampf(1.0 - _charge_left / telegraph, 0.0, 1.0)


## Change the rhythm (a new phase or a new aggression), keeping the clock.
func retime(interval_seconds: float) -> void:
	interval = maxf(interval_seconds, telegraph)
	_cooldown = minf(_cooldown, interval - telegraph)
