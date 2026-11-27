class_name FireLog
extends RefCounted
## Test support: counts an enemy's telegraph and shot signals against a clock
## the test advances, and how long each shot charged.

var telegraphs: Array[float] = []
var shots: Array[float] = []
var clock: float = 0.0
var charged_for: Array[float] = []
var _charge_start: float = -1.0


func on_telegraphed(_enemy: Enemy) -> void:
	telegraphs.append(clock)
	_charge_start = clock


func on_fired(_enemy: Enemy) -> void:
	shots.append(clock)
	charged_for.append(clock - _charge_start if _charge_start >= 0.0 else -1.0)
	_charge_start = -1.0
