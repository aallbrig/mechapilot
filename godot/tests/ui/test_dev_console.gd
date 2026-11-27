extends GdUnitTestSuite
## The Developer console (#116): the Developer mode setting, how the console
## opens (and that nothing opens it while Developer mode is off), what it
## shows, and that it never takes gameplay touches outside its own buttons.


func _turn_developer_mode(h: UiHarness, on: bool) -> void:
	var wanted: GameSettings = h.settings.current()
	wanted.developer_mode = on
	h.bus.profile.announce_settings_change_requested(wanted)


func test_developer_mode_setting_persists_and_defaults_off() -> void:
	var bus: EventBus = EventBus.new()
	var store: MemoryDocumentStore = MemoryDocumentStore.new()
	var first: Settings = Settings.new(bus, store)
	first.restore()
	var default_off: bool = first.current().developer_mode
	var wanted: GameSettings = first.current()
	wanted.developer_mode = true
	bus.profile.announce_settings_change_requested(wanted)
	var document: Dictionary = store.read_document()
	var stored: bool = document.has("developer_mode") and document["developer_mode"] is bool
	stored = stored and document["developer_mode"]
	bus.free()
	var later_bus: EventBus = EventBus.new()
	var later: Settings = Settings.new(later_bus, store)
	later.restore()
	var restored: bool = later.current().developer_mode
	later_bus.free()
	var toggles_found: Array[String] = []
	for screen_size: Vector2 in [UiHarness.LANDSCAPE, UiHarness.PORTRAIT]:
		var h: UiHarness = UiHarness.new(screen_size)
		add_child(h.host)
		h.reach_title()
		h.ui.open(&"settings")
		await await_idle_frame()
		var screen: SettingsScreen = h.screen(&"Settings") as SettingsScreen
		var toggle: CheckButton = screen.controls()[&"developer_mode"] as CheckButton
		var bounds: Rect2 = Rect2(Vector2.ZERO, screen_size)
		if toggle.is_visible_in_tree() and bounds.encloses(toggle.get_global_rect()):
			toggles_found.append(toggle.text)
		toggle.button_pressed = true
		var turned_on: bool = h.settings.current().developer_mode
		if turned_on:
			toggles_found.append("on")
		h.dispose()
	var _off: GdUnitAssert = assert_bool(default_off).is_false()
	var _saved: GdUnitAssert = assert_bool(stored).is_true()
	var _persisted: GdUnitAssert = assert_bool(restored).is_true()
	var _shown: GdUnitAssert = assert_array(toggles_found).is_equal(
		["Developer mode", "on", "Developer mode", "on"]
	)


func _key(code: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	return key


func _select_button() -> InputEventJoypadButton:
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_BACK
	pad.pressed = true
	return pad


## A left click (or, with `device` DEVICE_ID_EMULATION, the click Godot makes
## from a tap) pressed and released at `at`, pushed through `viewport`.
func _click(viewport: SubViewport, at: Vector2, device: int = 0) -> void:
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		click.device = device
		viewport.push_input(click)


## A finger down and up at `at`, as the browser reports it, pushed through
## `viewport`. With `emulate`, each is followed by the mouse event Godot
## emulates from it (emulate_mouse_from_touch, on by default).
func _tap(viewport: SubViewport, at: Vector2, finger: int = 0, emulate: bool = false) -> void:
	for pressed: bool in [true, false]:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.index = finger
		touch.pressed = pressed
		touch.position = at
		viewport.push_input(touch)
		if emulate:
			var click: InputEventMouseButton = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.position = at
			click.global_position = at
			click.device = InputEvent.DEVICE_ID_EMULATION
			viewport.push_input(click)


## The UI harness inside its own SubViewport, so real events can be pushed
## through the GUI (hit testing, mouse filters) as the engine does.
func _in_viewport(h: UiHarness) -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(h.host.size)
	# The harness host stands for the CanvasLayer the UI sits on in the game:
	# it must let the pointer through like everything else that is not a control.
	h.host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(h.host)
	add_child(viewport)
	return viewport


func _close(console: DevConsole) -> void:
	if console.is_open():
		console.toggle()


func test_console_unreachable_when_developer_mode_off() -> void:
	var h: UiHarness = UiHarness.new()
	var viewport: SubViewport = _in_viewport(h)
	h.reach_title()
	await await_idle_frame()
	var console: DevConsole = h.ui.dev_console()
	var button: Button = console.dev_button()
	var button_shown: bool = button.is_visible_in_tree()
	console._input(_key(KEY_QUOTELEFT))
	console._input(_select_button())
	_click(viewport, button.get_global_rect().get_center())
	_click(viewport, button.get_global_rect().get_center(), InputEvent.DEVICE_ID_EMULATION)
	button.pressed.emit()
	console.toggle()
	var opened_while_off: bool = console.is_open()
	_turn_developer_mode(h, true)
	console.toggle()
	var opened_on: bool = console.is_open()
	_turn_developer_mode(h, false)
	var closed_by_off: bool = not console.is_open()
	var hidden_again: bool = not button.is_visible_in_tree()
	h.dispose()
	viewport.free()
	var _no_button: GdUnitAssert = assert_bool(button_shown).is_false()
	var _never: GdUnitAssert = assert_bool(opened_while_off).is_false()
	var _on: GdUnitAssert = assert_bool(opened_on).is_true()
	var _closed: GdUnitAssert = assert_bool(closed_by_off).is_true()
	var _hidden: GdUnitAssert = assert_bool(hidden_again).is_true()


func test_console_opens_from_every_device() -> void:
	var h: UiHarness = UiHarness.new()
	var viewport: SubViewport = _in_viewport(h)
	h.reach_title()
	_turn_developer_mode(h, true)
	await await_idle_frame()
	var console: DevConsole = h.ui.dev_console()
	var centre: Vector2 = console.dev_button().get_global_rect().get_center()
	var opened: Array[bool] = []
	# A tap, as Godot delivers it: each finger event followed by the mouse
	# event it emulates from it.
	_tap(viewport, centre, 0, true)
	opened.append(console.is_open())
	_close(console)
	_click(viewport, centre)
	opened.append(console.is_open())
	_close(console)
	console._input(_key(KEY_QUOTELEFT))
	opened.append(console.is_open())
	console._input(_key(KEY_QUOTELEFT))
	var closed_by_key: bool = not console.is_open()
	console._input(_select_button())
	opened.append(console.is_open())
	console._input(_select_button())
	var closed_by_pad: bool = not console.is_open()
	h.dispose()
	viewport.free()
	var _every: GdUnitAssert = assert_array(opened).is_equal([true, true, true, true])
	var _key_closes: GdUnitAssert = assert_bool(closed_by_key).is_true()
	var _pad_closes: GdUnitAssert = assert_bool(closed_by_pad).is_true()


func test_console_shows_live_state_and_event_log() -> void:
	InputBindings.install()
	var h: UiHarness = UiHarness.new()
	add_child(h.host)
	h.reach_title()
	_turn_developer_mode(h, true)
	var console: DevConsole = h.ui.dev_console()
	console.toggle()
	console.step(0.5)
	h.run.reach_skirmish()
	var _points: int = h.run.kill(EnemyKind.Kind.FIGHTER)
	h.bus.player.announce_player_hit(DamageSource.Source.ENEMY_BULLET, Vector3.ZERO, 0)
	h.bus.flow.announce_input_device_changed(InputDevice.Kind.TOUCH)
	console._input(_key(KEY_SPACE))
	var finger: InputEventScreenTouch = InputEventScreenTouch.new()
	finger.index = 3
	finger.pressed = true
	finger.position = Vector2(40.0, 400.0)
	console._input(finger)
	console.refresh()
	var shown: String = console.shown_text()
	var last_event: String = console.event_log().back()
	var stamped: bool = last_event.begins_with("  0.50")
	h.dispose()
	var expected: Array[String] = [
		"FPS",
		"SKIRMISH",
		"Level 1",
		"Score 100",
		"Armor 90/100",
		"Lives 3",
		"Combo x1",
		"Gauge 100/",
		"Device TOUCH",
		"#3 move stick",
		"fire",
		"run.kill_scored",
		"player.armor_changed",
		"Godot ",
	]
	var missing: Array[String] = []
	for each: String in expected:
		if not shown.contains(each):
			missing.append(each)
	var _all_shown: GdUnitAssert = assert_array(missing).is_empty()
	var _timestamped: GdUnitAssert = assert_bool(stamped).is_true()


func test_console_does_not_block_gameplay_touches() -> void:
	var h: UiHarness = UiHarness.new()
	var viewport: SubViewport = _in_viewport(h)
	var probe: TouchProbe = TouchProbe.new()
	viewport.add_child(probe)
	h.reach_title()
	_turn_developer_mode(h, true)
	h.run.reach_skirmish()
	var console: DevConsole = h.ui.dev_console()
	console.toggle()
	await await_idle_frame()
	var panel: Rect2 = console.panel().get_global_rect()
	var log_label: Control = console.event_log_label()
	var button: Button = console.command_button(&"score")
	var outside: Vector2 = Vector2(h.host.size.x * 0.9, h.host.size.y * 0.5)
	_tap(viewport, log_label.get_global_rect().get_center(), 0)
	_tap(viewport, outside, 1)
	_tap(viewport, button.get_global_rect().get_center(), 2)
	var blocking: Array[String] = []
	for control: Control in console.all_controls():
		if not control is BaseButton and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			blocking.append(str(control.name))
	var open_over_play: bool = console.is_open() and panel.has_area()
	var fingers: Array[int] = probe.fingers.duplicate()
	h.dispose()
	viewport.free()
	var _open: GdUnitAssert = assert_bool(open_over_play).is_true()
	var _passed_through: GdUnitAssert = assert_array(fingers).is_equal([0, 0, 1, 1])
	var _only_buttons: GdUnitAssert = assert_array(blocking).is_empty()


func test_dev_console_has_no_free_text_evaluation() -> void:
	var sources: Array[String] = [
		_source(FileAccess.open("res://ui/dev/dev_console.gd", FileAccess.READ)),
		_source(FileAccess.open("res://ui/dev/dev_telemetry.gd", FileAccess.READ)),
		_source(FileAccess.open("res://core/dev_commands.gd", FileAccess.READ)),
		_source(FileAccess.open("res://types/dev_command.gd", FileAccess.READ)),
	]
	var found: Array[String] = []
	for source: String in sources:
		for banned: String in ["Expression", "str_to_var", "LineEdit", "TextEdit", "callv"]:
			if source.contains(banned):
				found.append(banned)
	var _read: GdUnitAssert = assert_int(sources.filter(_is_empty).size()).is_equal(0)
	var _none: GdUnitAssert = assert_array(found).is_empty()


func _source(file: FileAccess) -> String:
	return "" if file == null else file.get_as_text()


func _is_empty(source: String) -> bool:
	return source.is_empty()
