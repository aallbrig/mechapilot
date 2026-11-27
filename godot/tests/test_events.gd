extends GdUnitTestSuite
## The Events bus delivers typed Game Events, and the boot scene reacts to them.
## GdUnit4 asserts return the assert object; binding it to an `_`-prefixed local
## keeps return_value_discarded an error without any @warning_ignore.

const CHANNELS: Array[Script] = [
	EventBus.FlowChannel,
	EventBus.RunChannel,
	EventBus.PlayerChannel,
	EventBus.EnemyChannel,
	EventBus.BossChannel,
	EventBus.ProfileChannel,
	EventBus.DevChannel,
]

var _received: Array[Array] = []


func before_test() -> void:
	_received.clear()


func _record(from: GameState.Phase, to: GameState.Phase) -> void:
	_received.append([from, to])


func test_events_bus_delivers_typed_signal() -> void:
	var bus: EventBus = EventBus.new()
	var err: Error = bus.flow.game_state_changed.connect(_record) as Error
	bus.flow.announce_game_state_changed(GameState.Phase.TITLE, GameState.Phase.LEVEL_INTRO)
	bus.free()
	var _connected: GdUnitAssert = assert_int(err).is_equal(OK)
	var _delivered: GdUnitAssert = assert_array(_received).is_equal(
		[[GameState.Phase.TITLE, GameState.Phase.LEVEL_INTRO]]
	)


func test_events_bus_signals_are_fully_typed() -> void:
	var untyped: Array[String] = []
	var count: int = 0
	for channel: Script in CHANNELS:
		var signals: Array[Dictionary] = channel.get_script_signal_list()
		count += signals.size()
		for sig: Dictionary in signals:
			var args: Array = sig["args"]
			for arg: Dictionary in args:
				var arg_type: int = arg["type"]
				if arg_type == TYPE_NIL:
					untyped.append("%s(%s)" % [sig["name"], arg["name"]])
	var _has_signals: GdUnitAssert = assert_int(count).is_greater(0)
	var _all_typed: GdUnitAssert = assert_array(untyped).is_empty()


func test_events_every_signal_has_a_matching_announcer() -> void:
	var problems: Array[String] = []
	var root: Script = load("res://autoload/events.gd") as Script
	var root_signals: Array[Dictionary] = root.get_script_signal_list()
	for channel: Script in CHANNELS:
		var methods: Dictionary[String, int] = {}
		for method: Dictionary in channel.get_script_method_list():
			var method_args: Array = method["args"]
			var method_name: String = method["name"]
			methods[method_name] = method_args.size()
		for sig: Dictionary in channel.get_script_signal_list():
			var announcer: String = "announce_%s" % sig["name"]
			var sig_args: Array = sig["args"]
			if not methods.has(announcer) or methods[announcer] != sig_args.size():
				problems.append(announcer)
		for announcer: String in methods:
			if announcer.begins_with("announce_") and not _declares(channel, announcer):
				problems.append("stray %s" % announcer)
	var _no_root_signals: GdUnitAssert = assert_array(root_signals).is_empty()
	var _all_announced: GdUnitAssert = assert_array(problems).is_empty()


func test_events_catalog_names_are_unique_across_channels() -> void:
	var seen: Array[String] = []
	var duplicates: Array[String] = []
	for channel: Script in CHANNELS:
		for sig: Dictionary in channel.get_script_signal_list():
			var sig_name: String = sig["name"]
			if seen.has(sig_name):
				duplicates.append(sig_name)
			seen.append(sig_name)
	var _unique: GdUnitAssert = assert_array(duplicates).is_empty()


func test_main_boots_into_menu_through_events_bus() -> void:
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	var main: Node = scene.instantiate()
	add_child(main)
	var ui: UiRoot = main.get_node("Ui/UiRoot") as UiRoot
	var shown: Array[StringName] = ui.visible_screens()
	main.free()
	var _boot_shown: GdUnitAssert = assert_array(shown).is_equal([&"Boot"])


static func _declares(channel: Script, announcer: String) -> bool:
	var signal_name: String = announcer.trim_prefix("announce_")
	for sig: Dictionary in channel.get_script_signal_list():
		var declared: String = sig["name"]
		if declared == signal_name:
			return true
	return false
