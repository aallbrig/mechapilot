extends GdUnitTestSuite
## Layout (#24, #73 quality bar): every screen fits from a 360 px phone in
## portrait to 4K, and text stays at least 14 px on the phone.
##
## project.godot scales the UI so the window's shorter side is 640 UI pixels
## (canvas_items stretch, expand aspect), so every window maps to a UI rect
## that is 640 high in landscape or 640 wide in portrait.

const SIZES: Array[Vector2] = [
	UiHarness.PORTRAIT,
	UiHarness.LANDSCAPE,
	Vector2(640.0, 1422.0),
	Vector2(1493.0, 640.0),
	Vector2(853.0, 640.0),
]
const BASE_SIDE: int = 640
const PHONE_WIDTH: float = 360.0
const MIN_PHONE_PX: float = 14.0
const MIN_UI_FONT: int = 26
const TOLERANCE: float = 1.0


func _controls(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in root.get_children():
		if child is Control:
			found.append(child as Control)
		# What a scroll container holds may extend past the screen: it scrolls.
		if not child is ScrollContainer:
			found.append_array(_controls(child))
	return found


func _overflow(h: UiHarness, where: String) -> Array[String]:
	var bounds: Rect2 = Rect2(Vector2.ZERO, h.host.size).grow(TOLERANCE)
	var out: Array[String] = []
	for screen_node: UiScreen in h.ui.screens():
		if not screen_node.visible:
			continue
		for control: Control in _controls(screen_node):
			if not control.is_visible_in_tree() or control.size == Vector2.ZERO:
				continue
			var rect: Rect2 = control.get_global_rect()
			if not bounds.encloses(rect):
				out.append("%s %s/%s %s" % [where, screen_node.name, control.name, rect])
	return out


func _fill(h: UiHarness) -> void:
	for i: int in 10:
		var _rank: int = h.scoreboard.submit(ScoreEntry.new("WWW", 999_999_000 + i, 6, 5999.0))
	h.bus.run.announce_level_intro_started(
		6, "Edge of Orbit", "Survive the mothership's three phases and bring it down.", 2.5
	)
	h.bus.boss.announce_boss_warning_started("Crimson Lancer", 3.0)
	h.bus.run.announce_level_cleared(LevelTally.new(5, 999, 1000, 870, 5000, 10000))


func test_screens_fit_phone_portrait_to_4k() -> void:
	var overflow: Array[String] = []
	for screen_size: Vector2 in SIZES:
		var h: UiHarness = UiHarness.new(screen_size)
		add_child(h.host)
		h.boot()
		_fill(h)
		var previous: GameState.Phase = GameState.Phase.BOOT
		for phase: int in GameState.Phase.size():
			h.bus.flow.announce_game_state_changed(previous, phase as GameState.Phase)
			if phase == GameState.Phase.GAME_OVER:
				h.bus.run.announce_run_ended(RunSummary.new(999_999_999, 6, 5999.0, 9999, false))
				h.bus.profile.announce_scoreboard_qualified(0)
			previous = phase as GameState.Phase
			await await_idle_frame()
			await await_idle_frame()
			overflow.append_array(
				_overflow(h, "%s %s" % [screen_size, GameState.Phase.keys()[phase]])
			)
		h.bus.flow.announce_game_state_changed(previous, GameState.Phase.TITLE)
		for target: StringName in [&"settings", &"credits"]:
			h.ui.open(target)
			await await_idle_frame()
			await await_idle_frame()
			overflow.append_array(_overflow(h, "%s %s" % [screen_size, target]))
			h.ui.close_top()
		h.dispose()
	var _fits: GdUnitAssert = assert_array(overflow).is_empty()


func test_ui_text_stays_readable_at_phone_scale() -> void:
	var base_width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var base_height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	var mode: String = ProjectSettings.get_setting("display/window/stretch/mode")
	var aspect: String = ProjectSettings.get_setting("display/window/stretch/aspect")
	var phone_scale: float = PHONE_WIDTH / mini(base_width, base_height)
	var h: UiHarness = UiHarness.new(UiHarness.PORTRAIT)
	add_child(h.host)
	h.boot()
	var small: Array[String] = []
	for screen_node: UiScreen in h.ui.screens():
		for control: Control in _controls(screen_node):
			if control is Label or control is Button:
				var font_size: int = control.get_theme_font_size(&"font_size")
				if font_size < MIN_UI_FONT:
					small.append("%s/%s: %d" % [screen_node.name, control.name, font_size])
	h.dispose()
	var _base: GdUnitAssert = assert_int(mini(base_width, base_height)).is_equal(BASE_SIDE)
	var _mode: GdUnitAssert = assert_str(mode).is_equal("canvas_items")
	var _aspect: GdUnitAssert = assert_str(aspect).is_equal("expand")
	var _readable: GdUnitAssert = assert_float(MIN_UI_FONT * phone_scale).is_greater_equal(
		MIN_PHONE_PX
	)
	var _all_big: GdUnitAssert = assert_array(small).is_empty()


func test_theme_uses_bundled_ofl_fonts() -> void:
	var theme: Theme = load("res://ui/theme/theme.tres") as Theme
	var body: Font = theme.default_font
	var title: Font = theme.get_font(&"font", &"TitleLabel")
	var a: FileAccess = FileAccess.open("res://ui/theme/fonts/Orbitron-OFL.txt", FileAccess.READ)
	var b: FileAccess = FileAccess.open("res://ui/theme/fonts/ChakraPetch-OFL.txt", FileAccess.READ)
	var root: UiRoot = (load("res://ui/ui_root.tscn") as PackedScene).instantiate() as UiRoot
	var root_theme: Theme = root.theme
	root.free()
	var _body: GdUnitAssert = assert_str(body.resource_path).is_equal(
		"res://ui/theme/fonts/ChakraPetch-SemiBold.ttf"
	)
	var _title: GdUnitAssert = (
		assert_str((title as FontVariation).base_font.resource_path)
		. is_equal("res://ui/theme/fonts/Orbitron-Variable.ttf")
	)
	var _ofl: GdUnitAssert = assert_str(a.get_as_text()).contains("SIL Open Font License")
	var _ofl_body: GdUnitAssert = assert_str(b.get_as_text()).contains("SIL Open Font License")
	var _one_theme: GdUnitAssert = assert_str(root_theme.resource_path).is_equal(
		"res://ui/theme/theme.tres"
	)
