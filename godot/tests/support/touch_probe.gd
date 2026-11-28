class_name TouchProbe
extends Node
## Test support: stands in for the gameplay touch controls, which read screen
## touches in _unhandled_input (after the GUI). It records the finger index of
## every touch that reached it, presses and releases alike.

var fingers: Array[int] = []


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		fingers.append((event as InputEventScreenTouch).index)
