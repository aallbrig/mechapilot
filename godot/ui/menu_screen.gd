class_name MenuScreen
extends Control
## The screen for the Menu Game State. It is shown only while the game is in Menu.
## A placeholder title until the UI tickets build the real menu.


func _ready() -> void:
	visible = false
	var err: Error = Events.game_state_changed.connect(_on_game_state_changed) as Error
	if err != OK:
		push_error("MenuScreen: could not subscribe to game_state_changed: %s" % error_string(err))


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	visible = to == GameState.Phase.MENU
