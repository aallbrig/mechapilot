extends Node
## The composition root: the only script that knows the concrete classes. It
## wires the screens to the Events bus and announces the first Game State.
## The boot marker lets the web smoke test see the bus round trip in the browser.

const BOOT_OK_MARKER: String = "mechapilot: boot ok"

@onready var _menu_screen: MenuScreen = $MenuScreen


func _ready() -> void:
	Events.announce_game_state_changed(GameState.Phase.MENU, GameState.Phase.MENU)
	if _menu_screen.visible:
		print(BOOT_OK_MARKER)
	else:
		push_error("mechapilot: the Menu screen did not receive game_state_changed")
