class_name TickClock
extends Node
## Test support: announces every physics tick and counts the game time it
## covered, so a suite can wait on the running game (`await clock.ticked`)
## without reaching for the scene tree.

## One physics tick passed.
signal ticked

## Game seconds counted so far.
var elapsed: float = 0.0


func _physics_process(delta: float) -> void:
	elapsed += delta
	ticked.emit()
