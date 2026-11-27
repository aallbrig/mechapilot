class_name EventBus
extends Node
## The Game Event bus, registered as the `Events` autoload. It declares typed
## signals and holds no state. Emit only through the typed `announce_*` methods:
## they type-check every payload at compile time, which `Signal.emit()` does not.
## scripts/checks/godot-architecture rejects `Events.<signal>.emit(` elsewhere.
## Payload types live in types/, which every layer may use.

## The Game State changed. At boot `from` equals `to` (the first state entered).
signal game_state_changed(from: GameState.Phase, to: GameState.Phase)


func announce_game_state_changed(from: GameState.Phase, to: GameState.Phase) -> void:
	game_state_changed.emit(from, to)
