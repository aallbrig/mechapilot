extends GdUnitTestSuite
## The Events bus delivers typed Game Events, and the boot scene reacts to them.
## GdUnit4 asserts return the assert object; binding it to an `_`-prefixed local
## keeps return_value_discarded an error without any @warning_ignore.

var _received: Array[Array] = []


func before_test() -> void:
	_received.clear()


func _record(from: GameState.Phase, to: GameState.Phase) -> void:
	_received.append([from, to])


func test_events_bus_delivers_typed_signal() -> void:
	var bus: EventBus = EventBus.new()
	var err: Error = bus.game_state_changed.connect(_record) as Error
	bus.announce_game_state_changed(GameState.Phase.MENU, GameState.Phase.GAMEPLAY)
	bus.free()
	var _connected: GdUnitAssert = assert_int(err).is_equal(OK)
	var _delivered: GdUnitAssert = assert_array(_received).is_equal(
		[[GameState.Phase.MENU, GameState.Phase.GAMEPLAY]]
	)


func test_events_bus_signals_are_fully_typed() -> void:
	var script: Script = load("res://autoload/events.gd") as Script
	var signals: Array[Dictionary] = script.get_script_signal_list()
	var untyped: Array[String] = []
	for sig: Dictionary in signals:
		var args: Array = sig["args"]
		for arg: Dictionary in args:
			var arg_type: int = arg["type"]
			if arg_type == TYPE_NIL:
				untyped.append("%s(%s)" % [sig["name"], arg["name"]])
	var _has_signals: GdUnitAssert = assert_int(signals.size()).is_greater(0)
	var _all_typed: GdUnitAssert = assert_array(untyped).is_empty()


func test_main_boots_into_menu_through_events_bus() -> void:
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	var main: Node = scene.instantiate()
	add_child(main)
	var menu: MenuScreen = main.get_node("MenuScreen") as MenuScreen
	var shown: bool = menu.visible
	main.free()
	var _menu_shown: GdUnitAssert = assert_bool(shown).is_true()
