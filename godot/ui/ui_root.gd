class_name UiRoot
extends Control
## Every screen, and which ones show. One screen (plus the HUD in play) per
## Game State, from flow.game_state_changed alone; sub-screens (Settings,
## Credits, How to Play, Intel) open on top of the current one and close with Back. It also hands
## the last-used device and the reduced-motion setting to every screen.
##
## Back, Esc and gamepad B go to the top screen's handle_cancel(); while
## Paused, the pause controls do too. In play, the pause controls pause. This
## root is the only place pause keys are read, and it decides once per event
## from the Game State the event arrived in, so one Esc can never pause and
## then resume (the HUD and the Pause screen both see the same event
## otherwise, and `get_viewport().set_input_as_handled()` is banned by
## scripts/checks/godot-safe-api). The bus is Events unless use_bus() gave
## another one before the root entered the tree (tests do).
##
## On top of every screen sits the Developer console (#116, ui/dev/), which
## shows only in Developer mode and never takes gameplay input.

## The screens (node names) shown in each Game State, bottom to top.
const SCREENS_FOR: Dictionary[GameState.Phase, Array] = {
	GameState.Phase.BOOT: [&"Boot"],
	GameState.Phase.TITLE: [&"Title"],
	GameState.Phase.LEVEL_INTRO: [&"Hud", &"LevelIntro"],
	GameState.Phase.SKIRMISH: [&"Hud"],
	GameState.Phase.BOSS_WARNING: [&"Hud", &"BossWarning"],
	GameState.Phase.BOSS_FIGHT: [&"Hud"],
	GameState.Phase.LEVEL_CLEAR: [&"LevelClear"],
	GameState.Phase.PAUSED: [&"Pause"],
	GameState.Phase.GAME_OVER: [&"GameOver"],
	GameState.Phase.VICTORY: [&"Victory"],
	GameState.Phase.SCOREBOARD: [&"Scoreboard"],
}
## Sub-screens a screen may open with navigate_requested, by target name.
const SUB_SCREENS: Dictionary[StringName, StringName] = {
	&"settings": &"Settings",
	&"credits": &"Credits",
	&"how_to_play": &"HowToPlay",
	&"intel": &"Intel",
}

var _bus: EventBus
var _screens: Dictionary[StringName, UiScreen] = {}
var _shown: Array[UiScreen] = []
var _stack: Array[UiScreen] = []
var _phase: GameState.Phase = GameState.Phase.BOOT
var _dev_console: DevConsole = DevConsole.new()


## Use `bus` instead of the Events autoload. Call before adding to the tree.
func use_bus(bus: EventBus) -> void:
	_bus = bus


func _ready() -> void:
	if _bus == null:
		_bus = Events
	for child: Node in get_children():
		if child is UiScreen:
			var screen_node: UiScreen = child as UiScreen
			_screens[screen_node.name] = screen_node
			screen_node.bind(_bus)
			_wire(screen_node.navigate_requested.connect(open))
			_wire(screen_node.back_requested.connect(close_top))
	_wire(_bus.flow.game_state_changed.connect(_on_game_state_changed))
	_wire(_bus.flow.input_device_changed.connect(_on_input_device_changed))
	_wire(_bus.profile.settings_changed.connect(_on_settings_changed))
	add_child(_dev_console)
	_dev_console.bind(_bus)


## The names of the screens shown now, bottom to top.
func visible_screens() -> Array[StringName]:
	var names: Array[StringName] = []
	for screen_node: UiScreen in _screens.values():
		if screen_node.visible:
			names.append(screen_node.name)
	return names


## The Developer console (#116).
func dev_console() -> DevConsole:
	return _dev_console


## The screen named `screen_name` (a node name such as &"Title"), or null.
func screen(screen_name: StringName) -> UiScreen:
	return _screens[screen_name] if _screens.has(screen_name) else null


## Every screen.
func screens() -> Array[UiScreen]:
	var all: Array[UiScreen] = []
	all.assign(_screens.values())
	return all


## The screen on top: the last sub-screen, or the state's top screen.
func top_screen() -> UiScreen:
	if not _stack.is_empty():
		return _stack.back()
	return null if _shown.is_empty() else _shown.back()


## Opens a sub-screen (see SUB_SCREENS) on top of the current screen.
func open(target: StringName) -> void:
	if not SUB_SCREENS.has(target):
		push_error("UiRoot: no sub-screen %s" % target)
		return
	var sub: UiScreen = screen(SUB_SCREENS[target])
	if sub == null or _stack.has(sub):
		return
	var below: UiScreen = top_screen()
	if below != null:
		below.leave()
	_stack.append(sub)
	sub.enter()


## Closes the top sub-screen and shows the one below again.
func close_top() -> void:
	if _stack.is_empty():
		return
	var top: UiScreen = _stack.pop_back()
	top.leave()
	_bus.flow.announce_ui_cue_requested(UiCue.Cue.BACK)
	var below: UiScreen = top_screen()
	if below != null:
		below.enter()


func _gui_input(event: InputEvent) -> void:
	if _wants_cancel(event) and _cancel():
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_play(_phase) and UiInput.is_pause(event):
		var hud: Hud = screen(&"Hud") as Hud
		if hud != null and hud.is_visible_in_tree():
			hud.request_pause()
		return
	if _wants_cancel(event):
		var _handled: bool = _cancel()


func _wants_cancel(event: InputEvent) -> bool:
	return (
		UiInput.is_cancel(event) or (_phase == GameState.Phase.PAUSED and UiInput.is_pause(event))
	)


func _cancel() -> bool:
	var top: UiScreen = top_screen()
	return top != null and top.is_visible_in_tree() and top.handle_cancel()


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	_phase = to
	for screen_node: UiScreen in _stack:
		screen_node.leave()
	_stack.clear()
	for screen_node: UiScreen in _shown:
		screen_node.leave()
	_shown.clear()
	var names: Array = SCREENS_FOR[to] if SCREENS_FOR.has(to) else []
	for screen_name: StringName in names:
		var screen_node: UiScreen = screen(screen_name)
		if screen_node != null:
			_shown.append(screen_node)
			screen_node.enter()


func _on_input_device_changed(device: InputDevice.Kind) -> void:
	for screen_node: UiScreen in _screens.values():
		screen_node.set_device(device)


func _on_settings_changed(settings: GameSettings) -> void:
	TweenFx.reduced_motion = settings.reduced_motion


func _wire(result: int) -> void:
	if result != OK:
		push_error("UiRoot: could not wire a signal: %s" % error_string(result))
