class_name MenuScreen
extends Control
## The placeholder screen for the Boot and Title Game States: shown only while
## the game is in one of them. The UI tickets replace it with the real Boot
## ("tap to start") and Title screens.


func _ready() -> void:
	visible = false
	var err: Error = Events.flow.game_state_changed.connect(_on_game_state_changed) as Error
	if err != OK:
		push_error("MenuScreen: could not subscribe to game_state_changed: %s" % error_string(err))


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	visible = to == GameState.Phase.BOOT or to == GameState.Phase.TITLE
