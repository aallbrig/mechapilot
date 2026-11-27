class_name DataReader
extends RefCounted
## Typed, validating reads from JSON-shaped data (Level files and stored
## documents). Every read of a missing or mistyped field records an error and
## returns the given fallback, so a caller reads all its fields and then checks
## is_ok() once. JSON numbers arrive as floats; integer reads reject fractions.

var _errors: Array[String] = []


## True when no read failed.
func is_ok() -> bool:
	return _errors.is_empty()


## Every failed read, as "<path>: <problem>".
func errors() -> Array[String]:
	return _errors.duplicate()


## Records a failure found by the caller (for cross-field rules).
func fail(path: String, problem: String) -> void:
	_errors.append("%s: %s" % [path, problem])


## A Dictionary field.
func object(data: Dictionary, key: String, path: String) -> Dictionary:
	if not data.has(key) or not data[key] is Dictionary:
		fail(_join(path, key), "missing or not an object")
		return {}
	var value: Dictionary = data[key]
	return value


## An Array field.
func list(data: Dictionary, key: String, path: String) -> Array:
	if not data.has(key) or not data[key] is Array:
		fail(_join(path, key), "missing or not an array")
		return []
	var value: Array = data[key]
	return value


## A String field.
func text(data: Dictionary, key: String, path: String) -> String:
	if not data.has(key) or not data[key] is String:
		fail(_join(path, key), "missing or not a string")
		return ""
	var value: String = data[key]
	return value


## A boolean field.
func flag(data: Dictionary, key: String, path: String, fallback: bool) -> bool:
	if not data.has(key) or not data[key] is bool:
		fail(_join(path, key), "missing or not a boolean")
		return fallback
	var value: bool = data[key]
	return value


## A number field within [minimum, maximum].
func number(data: Dictionary, key: String, path: String, minimum: float, maximum: float) -> float:
	if not data.has(key) or not (data[key] is float or data[key] is int):
		fail(_join(path, key), "missing or not a number")
		return minimum
	var value: float = data[key]
	if value < minimum or value > maximum:
		fail(_join(path, key), "%s is outside [%s, %s]" % [value, minimum, maximum])
		return clampf(value, minimum, maximum)
	return value


## A whole-number field within [minimum, maximum].
func integer(data: Dictionary, key: String, path: String, minimum: int, maximum: int) -> int:
	var value: float = number(data, key, path, minimum, maximum)
	if value != floorf(value):
		fail(_join(path, key), "%s is not a whole number" % value)
	return floori(value)


## An element of a list, which must be a Dictionary.
func element(items: Array, index: int, path: String) -> Dictionary:
	if index < 0 or index >= items.size() or not items[index] is Dictionary:
		fail("%s[%d]" % [path, index], "missing or not an object")
		return {}
	var value: Dictionary = items[index]
	return value


static func _join(path: String, key: String) -> String:
	if path.is_empty():
		return key
	return "%s.%s" % [path, key]
