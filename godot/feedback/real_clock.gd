class_name RealClock
extends RefCounted
## Real (wall-clock) time for the feedback that must not freeze in hit-stop or
## slur in slow-mo. A frame's `_process` delta is scaled by the time scale that
## held when the frame began, so `delta / Engine.time_scale` is wrong on the
## frame the scale changes (a kill landing in `_physics_process` would clear its
## own hit-stop at once). This clock reads Time.get_ticks_usec() instead.

## A step is never taken as longer than this (s), e.g. after a stall.
const MAX_STEP: float = 0.1
const USEC: float = 1000000.0

var _last: int = -1


## Real seconds since the previous step() or mark() (0 on the first call).
func step() -> float:
	var now: int = Time.get_ticks_usec()
	if _last < 0:
		_last = now
		return 0.0
	var seconds: float = float(now - _last) / USEC
	_last = now
	return clampf(seconds, 0.0, MAX_STEP)


## Count from now: the next step() covers only the time after this call, so an
## effect started mid-frame keeps its full length.
func mark() -> void:
	_last = Time.get_ticks_usec()
