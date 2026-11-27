extends GdUnitTestSuite
## The Developer console's commands (#116) work in the composed game: main.tscn
## builds DevCommands on the Events bus, so a console button changes the Run.


func test_dev_commands_work_in_the_real_game() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	var console: DevConsole = (main.get_node("Ui/UiRoot") as UiRoot).dev_console()
	var wanted: GameSettings = GameSettings.new()
	wanted.developer_mode = true
	wanted.reduced_motion = true
	Events.profile.announce_settings_change_requested(wanted)
	Events.flow.announce_start_requested()
	Events.flow.announce_play_requested()
	console.toggle()
	console.refresh()
	var shown_before: String = console.shown_text()
	console.command_button(&"score").pressed.emit()
	console.command_button(&"life").pressed.emit()
	console.refresh()
	var shown_after: String = console.shown_text()
	var defaults: GameSettings = GameSettings.new()
	defaults.reduced_motion = true
	Events.profile.announce_settings_change_requested(defaults)
	main.free()
	var _open: GdUnitAssert = assert_bool(shown_before.contains("State LEVEL_INTRO")).is_true()
	var _started: GdUnitAssert = (
		assert_bool(shown_before.contains("Score 0") and shown_before.contains("Lives 3")).is_true()
	)
	var _scored: GdUnitAssert = assert_bool(shown_after.contains("Score 1000")).is_true()
	var _life: GdUnitAssert = assert_bool(shown_after.contains("Lives 4")).is_true()
	var _marked: GdUnitAssert = assert_bool(shown_after.contains("Assisted YES")).is_true()
