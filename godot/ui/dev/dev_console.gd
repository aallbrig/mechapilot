class_name DevConsole
extends Control
## The Developer console (#116): a see-through overlay that shows what the game
## receives and what state it is in, with a fixed list of command buttons.
##
## - Reachable only while Developer mode is on (Settings): then a small DEV
##   button shows in the bottom-right corner (touch and mouse), and backquote
##   or gamepad Select (Back) opens and closes the console. With Developer
##   mode off nothing opens it, and turning it off closes it.
## - It never takes gameplay input: every part of it except its buttons
##   ignores the pointer, so a touch anywhere else reaches the touch controls,
##   and its buttons never take keyboard or gamepad focus.
## - Commands are announced as intents (dev.dev_command_requested) and carried
##   out by core/DevCommands through the rules. "Debug draw" (the FPS badge
##   and the engine's collision shapes) and "Copy diagnostics" are local.
##   There is no free-text command or evaluation.
##
## UiRoot builds it on top of every screen and binds it to the bus.

const TOGGLE_KEY: Key = KEY_QUOTELEFT
const TOGGLE_PAD_BUTTON: JoyButton = JOY_BUTTON_BACK
## How often the open console redraws its text, in seconds.
const REFRESH_INTERVAL: float = 0.1
## How long "COPIED" shows on the copy button.
const COPIED_TIME: float = 1.2
const DEV_BUTTON_SIZE: Vector2 = Vector2(112.0, 52.0)
const DEV_BUTTON_MARGIN: float = 16.0
const COMMAND_SIZE: Vector2 = Vector2(168.0, 46.0)
const COMMAND_COLUMNS: int = 3
const WIDE_COMMAND_COLUMNS: int = 2
const PANEL_MARGIN: float = 12.0
const COMMAND_GAP: int = 8
## Landscape: the panel takes this share of the width from the left edge.
## Portrait: this share of the height from the top.
const LANDSCAPE_SHARE: float = 0.8
const PORTRAIT_SHARE: float = 0.66
const TEXT_SIZE: int = 19
const SECTION_SIZE: int = 18
const HEADER_SIZE: int = 30
const BUTTON_TEXT_SIZE: int = 18
const SLIDE_OFFSET: Vector2 = Vector2(-48.0, 0.0)
const OPEN_PUNCH: float = 0.25
const PANEL_FILL: Color = Color(0.02, 0.04, 0.12, 0.62)
const PANEL_EDGE: Color = Color(0.2, 0.8, 1.0, 0.7)
const ACCENT: Color = Color(1.0, 0.85, 0.2, 1.0)
const HOT: Color = Color(1.0, 0.35, 0.3, 1.0)
const DIM: Color = Color(0.8, 0.9, 1.0, 0.85)
const CORNER: int = 10
const EDGE: int = 2
const DEV_BUTTON_FILL: Color = Color(0.1, 0.06, 0.0, 0.7)
## The command buttons: id, label, and the rule command they request (-1: local).
const COMMANDS: Array[Array] = [
	[&"invulnerable", "INVULN", DevCommand.Command.TOGGLE_INVULNERABILITY],
	[&"score", "+1,000 SCORE", DevCommand.Command.ADD_SCORE],
	[&"boss", "SUMMON BOSS", DevCommand.Command.FILL_BOSS_GAUGE],
	[&"skip", "SKIP LEVEL", DevCommand.Command.SKIP_LEVEL],
	[&"purge", "KILL ALL", DevCommand.Command.KILL_ALL_ENEMIES],
	[&"armor", "REPAIR", DevCommand.Command.RESTORE_ARMOR],
	[&"life", "+1 LIFE", DevCommand.Command.ADD_LIFE],
	[&"debug_draw", "DEBUG DRAW", -1],
	[&"copy", "COPY DIAG", -1],
]
const DEBUG_DRAW: StringName = &"debug_draw"
const COPY: StringName = &"copy"
const INVULNERABLE: StringName = &"invulnerable"

var _bus: EventBus
var _telemetry: DevTelemetry
var _enabled: bool = false
var _open: bool = false
var _debug_draw: bool = false
var _invulnerable: bool = false
var _since_refresh: float = 0.0
var _copied_left: float = 0.0
var _fps: float = 0.0
var _dev_button: Button
var _panel: PanelContainer
var _layout: BoxContainer
var _grid: GridContainer
var _status: Label
var _state: Label
var _touches: Label
var _inputs: Label
var _events_label: Label
var _build: Label
var _fps_badge: Label
var _commands: Dictionary[StringName, Button] = {}
var _juices: Array[ControlJuice] = []


func _init() -> void:
	name = "DevConsole"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_build_panel()
	_build_fps_badge()
	# Last, so it draws (and takes taps) above the open panel.
	_build_dev_button()
	_ignore_pointer(self)


## Connects the console to `bus`. Called once by UiRoot.
func bind(bus: EventBus) -> void:
	_bus = bus
	_telemetry = DevTelemetry.new(bus)
	var subscribed: Array[int] = [
		bus.profile.settings_changed.connect(_on_settings_changed),
		bus.dev.dev_status_changed.connect(_on_dev_status_changed),
	]
	if subscribed.count(OK) != subscribed.size():
		push_error("DevConsole: could not subscribe")
	for control: Button in _all_buttons():
		var juice: ControlJuice = ControlJuice.attach(control)
		if juice.cued.connect(_cue) != OK:
			push_error("DevConsole: could not hear the juice of %s" % control.name)
		_juices.append(juice)
	_show_state()


## True while the console panel is open.
func is_open() -> bool:
	return _open


## True while Developer mode is on (the console can be opened).
func is_enabled() -> bool:
	return _enabled


## Opens or closes the console. Does nothing while Developer mode is off.
func toggle() -> void:
	if not _enabled:
		return
	_set_open(not _open)


## The DEV button (shown only in Developer mode).
func dev_button() -> Button:
	return _dev_button


## The console panel.
func panel() -> PanelContainer:
	return _panel


## The label that shows the bus announcements.
func event_log_label() -> Label:
	return _events_label


## The command button `id` (see COMMANDS), or null.
func command_button(id: StringName) -> Button:
	return _commands[id] if _commands.has(id) else null


## Every control the console built, buttons included.
func all_controls() -> Array[Control]:
	var found: Array[Control] = []
	_collect(self, found)
	return found


## The latest bus announcements, oldest first.
func event_log() -> Array[String]:
	return _telemetry.event_log() if _telemetry != null else []


## Every line of text the console shows now.
func shown_text() -> String:
	return "\n".join(
		[_status.text, _state.text, _touches.text, _inputs.text, _events_label.text, _build.text]
	)


## Moves the console's clock on by `delta` seconds (the engine calls this
## every frame through _process, paused or not).
func step(delta: float) -> void:
	if _telemetry == null:
		return
	_telemetry.advance(delta)
	if _copied_left > 0.0:
		_copied_left -= delta
		if _copied_left <= 0.0:
			_commands[COPY].text = _label_of(COPY)
	_since_refresh += delta
	if _since_refresh >= REFRESH_INTERVAL:
		_since_refresh = 0.0
		refresh()


## Redraws the console's text from the telemetry.
func refresh() -> void:
	if _telemetry == null:
		return
	_fps = Engine.get_frames_per_second()
	_fps_badge.text = "FPS %d" % roundi(_fps)
	if not _open:
		return
	_state.text = "   ".join(_telemetry.state_lines(_fps))
	var touches: Array[String] = _telemetry.touch_lines()
	_touches.text = "Touches: " + ("none" if touches.is_empty() else "   ".join(touches))
	_inputs.text = "\n".join(_telemetry.input_log())
	_events_label.text = "\n".join(_telemetry.event_log())
	var in_play: bool = GameState.is_play(_telemetry.phase())
	for entry: Array in COMMANDS:
		var id: StringName = entry[0]
		var command: int = entry[2]
		var needs_play: bool = command >= 0 and id != INVULNERABLE
		_commands[id].disabled = needs_play and not in_play


## The build: version (or "dev"), engine, platform and build type.
static func build_text() -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	var engine: Dictionary = Engine.get_version_info()
	return (
		"Build %s  |  Godot %s  |  %s  |  %s"
		% [
			version if not version.is_empty() else "dev",
			engine["string"],
			"web" if OS.has_feature("web") else OS.get_name().to_lower(),
			"debug" if OS.is_debug_build() else "release",
		]
	)


func _process(delta: float) -> void:
	step(delta)


func _input(event: InputEvent) -> void:
	if not _enabled or _telemetry == null:
		return
	_telemetry.note_input(event, size, _on_button(event))
	if _is_toggle(event):
		toggle()


func _is_toggle(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return (
			key.pressed
			and not key.echo
			and (key.keycode == TOGGLE_KEY or key.physical_keycode == TOGGLE_KEY)
		)
	if event is InputEventJoypadButton:
		var pad: InputEventJoypadButton = event as InputEventJoypadButton
		return pad.pressed and pad.button_index == TOGGLE_PAD_BUTTON
	return false


## True when a touch lands on one of the console's visible buttons.
func _on_button(event: InputEvent) -> bool:
	if not event is InputEventScreenTouch:
		return false
	var at: Vector2 = (event as InputEventScreenTouch).position
	for button: Button in _all_buttons():
		if button.is_visible_in_tree() and button.get_global_rect().has_point(at):
			return true
	return false


func _set_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	_panel.visible = open
	_dev_button.button_pressed = open
	if open:
		_fit()
		refresh()
		TweenFx.slide_in(_panel, SLIDE_OFFSET)
	TweenFx.punch(_dev_button, OPEN_PUNCH)
	_cue(UiCue.Cue.CONFIRM if open else UiCue.Cue.BACK)


func _on_settings_changed(settings: GameSettings) -> void:
	_enabled = settings.developer_mode
	if not _enabled:
		_set_open(false)
		_set_debug_draw(false)
	_dev_button.visible = _enabled


func _on_dev_status_changed(invulnerable: bool, _dev_assisted: bool) -> void:
	_invulnerable = invulnerable
	_show_state()


func _on_command_pressed(id: StringName, command: int) -> void:
	if not _enabled or _bus == null:
		return
	if command >= 0:
		_bus.dev.announce_dev_command_requested(command as DevCommand.Command)
	elif id == DEBUG_DRAW:
		_set_debug_draw(not _debug_draw)
	elif id == COPY:
		DisplayServer.clipboard_set(_telemetry.snapshot(_fps, build_text()))
		_commands[COPY].text = "COPIED"
		_copied_left = COPIED_TIME
	refresh()


func _set_debug_draw(on: bool) -> void:
	_debug_draw = on
	_fps_badge.visible = on
	if is_inside_tree():
		get_tree().debug_collisions_hint = on
	_show_state()


func _show_state() -> void:
	if _commands.is_empty():
		return
	_commands[INVULNERABLE].button_pressed = _invulnerable
	_commands[INVULNERABLE].text = "INVULN: %s" % ("ON" if _invulnerable else "OFF")
	_commands[DEBUG_DRAW].button_pressed = _debug_draw
	_commands[DEBUG_DRAW].text = "DEBUG DRAW: %s" % ("ON" if _debug_draw else "OFF")
	_status.text = "INVULNERABLE" if _invulnerable else ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _panel != null:
		_fit()


## Landscape: the panel down the left side, info and commands side by side
## (two command columns). Portrait: across the top, stacked (three columns).
func _fit() -> void:
	var wide: bool = size.x > size.y
	_layout.vertical = not wide
	_grid.columns = WIDE_COMMAND_COLUMNS if wide else COMMAND_COLUMNS
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = LANDSCAPE_SHARE if wide else 1.0
	_panel.anchor_bottom = 1.0 if wide else PORTRAIT_SHARE
	_panel.offset_left = PANEL_MARGIN
	_panel.offset_top = PANEL_MARGIN
	_panel.offset_right = -PANEL_MARGIN
	_panel.offset_bottom = -PANEL_MARGIN


func _build_dev_button() -> void:
	_dev_button = Button.new()
	_dev_button.name = "DevButton"
	_dev_button.text = "DEV"
	_dev_button.toggle_mode = true
	_dev_button.focus_mode = Control.FOCUS_NONE
	_dev_button.tooltip_text = "Developer console"
	_dev_button.custom_minimum_size = DEV_BUTTON_SIZE
	_dev_button.size = DEV_BUTTON_SIZE
	_dev_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dev_button.offset_left = -DEV_BUTTON_SIZE.x - DEV_BUTTON_MARGIN
	_dev_button.offset_right = -DEV_BUTTON_MARGIN
	_dev_button.offset_top = -DEV_BUTTON_SIZE.y - DEV_BUTTON_MARGIN
	_dev_button.offset_bottom = -DEV_BUTTON_MARGIN
	_dev_button.add_theme_font_size_override(&"font_size", BUTTON_TEXT_SIZE)
	_dev_button.add_theme_color_override(&"font_color", ACCENT)
	_dev_button.add_theme_stylebox_override(&"normal", _box(DEV_BUTTON_FILL, ACCENT))
	_dev_button.visible = false
	if _dev_button.pressed.connect(toggle) != OK:
		push_error("DevConsole: could not wire the DEV button")
	add_child(_dev_button)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.add_theme_stylebox_override(&"panel", _box(PANEL_FILL, PANEL_EDGE))
	_panel.visible = false
	add_child(_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, int(PANEL_MARGIN))
	_panel.add_child(margin)
	_layout = BoxContainer.new()
	_layout.add_theme_constant_override(&"separation", UiBuild.GAP)
	margin.add_child(_layout)
	var info: VBoxContainer = UiBuild.column(4)
	info.alignment = BoxContainer.ALIGNMENT_BEGIN
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_child(info)
	var header: HBoxContainer = UiBuild.row(UiBuild.GAP)
	header.alignment = BoxContainer.ALIGNMENT_BEGIN
	info.add_child(header)
	var title: Label = UiBuild.label("DEV CONSOLE", &"HeaderLabel")
	title.add_theme_font_size_override(&"font_size", HEADER_SIZE)
	header.add_child(title)
	_status = _text_label(HOT)
	header.add_child(_status)
	_state = _text_label(Color.WHITE)
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_state)
	_touches = _text_label(DIM)
	_touches.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_touches)
	info.add_child(_section("INPUT"))
	_inputs = _text_label(DIM)
	info.add_child(_inputs)
	info.add_child(_section("EVENTS"))
	_events_label = _text_label(DIM)
	_events_label.name = "EventLog"
	_events_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_events_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_events_label.clip_text = true
	info.add_child(_events_label)
	_build = _text_label(DIM)
	_build.text = build_text()
	_build.add_theme_font_size_override(&"font_size", SECTION_SIZE)
	info.add_child(_build)
	_grid = GridContainer.new()
	_grid.columns = COMMAND_COLUMNS
	_grid.add_theme_constant_override(&"h_separation", COMMAND_GAP)
	_grid.add_theme_constant_override(&"v_separation", COMMAND_GAP)
	_grid.size_flags_vertical = Control.SIZE_SHRINK_END
	_layout.add_child(_grid)
	for entry: Array in COMMANDS:
		var id: StringName = entry[0]
		var command: int = entry[2]
		var button: Button = Button.new()
		button.name = String(id)
		button.text = entry[1]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = COMMAND_SIZE
		button.toggle_mode = id == INVULNERABLE or id == DEBUG_DRAW
		button.add_theme_font_size_override(&"font_size", BUTTON_TEXT_SIZE)
		if button.pressed.connect(_on_command_pressed.bind(id, command)) != OK:
			push_error("DevConsole: could not wire %s" % id)
		_grid.add_child(button)
		_commands[id] = button
	_show_state()


func _build_fps_badge() -> void:
	_fps_badge = _text_label(ACCENT)
	_fps_badge.name = "FpsBadge"
	_fps_badge.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_fps_badge.offset_top = PANEL_MARGIN
	_fps_badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fps_badge.add_theme_font_size_override(&"font_size", HEADER_SIZE)
	_fps_badge.visible = false
	add_child(_fps_badge)


func _section(text: String) -> Label:
	var made: Label = UiBuild.label(text, &"HintLabel")
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	made.add_theme_font_size_override(&"font_size", SECTION_SIZE)
	made.add_theme_color_override(&"font_color", ACCENT)
	return made


func _text_label(color: Color) -> Label:
	var made: Label = UiBuild.label("", &"BodyLabel")
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	made.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	made.add_theme_font_size_override(&"font_size", TEXT_SIZE)
	made.add_theme_color_override(&"font_color", color)
	return made


func _label_of(id: StringName) -> String:
	for entry: Array in COMMANDS:
		if entry[0] == id:
			return entry[1]
	return ""


func _all_buttons() -> Array[Button]:
	var buttons: Array[Button] = [_dev_button]
	buttons.append_array(_commands.values())
	return buttons


func _cue(cue: UiCue.Cue) -> void:
	if _bus != null:
		_bus.flow.announce_ui_cue_requested(cue)


## Everything but the buttons lets the pointer through to the game.
static func _ignore_pointer(root: Node) -> void:
	for child: Node in root.get_children():
		if child is Control and not child is BaseButton:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_pointer(child)


static func _collect(root: Node, found: Array[Control]) -> void:
	for child: Node in root.get_children():
		if child is Control:
			found.append(child as Control)
		_collect(child, found)


static func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(EDGE)
	box.set_corner_radius_all(CORNER)
	box.content_margin_left = PANEL_MARGIN
	box.content_margin_right = PANEL_MARGIN
	box.content_margin_top = PANEL_MARGIN * 0.5
	box.content_margin_bottom = PANEL_MARGIN * 0.5
	return box
