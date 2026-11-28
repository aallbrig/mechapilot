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
## #127: landscape, and a 390x844 phone in portrait (640 UI pixels wide).
const GAUGE_SIZES: Array[Vector2] = [UiHarness.LANDSCAPE, Vector2(640.0, 1385.0)]
## The old top-centre Boss Gauge row's height, as measured: a 26 px label (33 px
## line) over a 22 px bar.
const OLD_GAUGE_ROW_HEIGHT: float = 59.0


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


## The OFL requires each font's licence to ship with it: the Web export's
## include filter must cover both licence files (and CREDITS.md, which the
## Credits screen reads).
func test_export_includes_font_licences() -> void:
	var presets: ConfigFile = ConfigFile.new()
	var loaded: Error = presets.load("res://export_presets.cfg")
	var filter: String = presets.get_value("preset.0", "include_filter", "")
	var patterns: PackedStringArray = []
	for pattern: String in filter.split(","):
		var _added: bool = patterns.append(pattern.strip_edges())
	var uncovered: Array[String] = []
	for path: String in [
		"ui/theme/fonts/Orbitron-OFL.txt", "ui/theme/fonts/ChakraPetch-OFL.txt", "CREDITS.md"
	]:
		var covered: bool = false
		for pattern: String in patterns:
			covered = covered or path.match(pattern)
		if not covered:
			uncovered.append(path)
	var _read: GdUnitAssert = assert_int(loaded).is_equal(OK)
	var _web: GdUnitAssert = assert_str(presets.get_value("preset.0", "platform", "")).is_equal(
		"Web"
	)
	var _shipped: GdUnitAssert = assert_array(uncovered).is_empty()


func test_settings_fit_1080p_with_reset_and_back_visible() -> void:
	var hidden: Array[String] = []
	var columns: Array[int] = []
	for screen_size: Vector2 in [UiHarness.LANDSCAPE, UiHarness.PORTRAIT]:
		var h: UiHarness = UiHarness.new(screen_size)
		add_child(h.host)
		h.reach_title()
		h.ui.open(&"settings")
		await await_idle_frame()
		await await_idle_frame()
		var settings: SettingsScreen = h.screen(&"Settings") as SettingsScreen
		columns.append(settings.column_count())
		var bounds: Rect2 = Rect2(Vector2.ZERO, screen_size)
		for control: Control in settings.juiced_controls():
			if control is Button and not bounds.encloses(control.get_global_rect()):
				hidden.append("%s %s" % [screen_size, (control as Button).text])
		h.dispose()
	var _two_then_one: GdUnitAssert = assert_array(columns).is_equal([2, 1])
	var _all_visible: GdUnitAssert = assert_array(hidden).is_empty()


## The Boss Gauge (#127) sits at the bottom centre, inside the safe margin, and
## smaller than the old top-centre bar, in landscape and in phone portrait.
func test_boss_gauge_sits_at_bottom_center() -> void:
	var misplaced: Array[String] = []
	for screen_size: Vector2 in GAUGE_SIZES:
		var h: UiHarness = UiHarness.new(screen_size)
		add_child(h.host)
		var hud: Hud = await _hud_in_skirmish(h)
		var rect: Rect2 = hud.gauge_rect()
		var safe: Rect2 = Rect2(Vector2.ZERO, screen_size).grow(-UiBuild.SCREEN_MARGIN)
		if absf(rect.get_center().x - screen_size.x * 0.5) > TOLERANCE:
			misplaced.append("%s not centred: %s" % [screen_size, rect])
		if absf(rect.end.y - safe.end.y) > TOLERANCE:
			misplaced.append("%s not at the bottom: %s" % [screen_size, rect])
		if not safe.grow(TOLERANCE).encloses(rect):
			misplaced.append("%s outside the safe margin: %s" % [screen_size, rect])
		if rect.size.x >= Hud.WIDE_BAR_SIZE.x or rect.size.y >= OLD_GAUGE_ROW_HEIGHT:
			misplaced.append("%s not smaller than before: %s" % [screen_size, rect])
		h.dispose()
	var _bottom_centre: GdUnitAssert = assert_array(misplaced).is_empty()


## The Boss Gauge (#127) never overlaps the touch controls' thumb zones (where
## a resting thumb draws the move and aim sticks), the Pause button or the
## armor row, in landscape and in phone portrait.
func test_boss_gauge_clear_of_touch_controls() -> void:
	var overlaps: Array[String] = []
	for screen_size: Vector2 in GAUGE_SIZES:
		var h: UiHarness = UiHarness.new(screen_size)
		add_child(h.host)
		var hud: Hud = await _hud_in_skirmish(h)
		var touch: TouchControls = TouchControls.new()
		touch.size = screen_size
		var rect: Rect2 = hud.gauge_rect()
		var others: Dictionary[String, Rect2] = {
			"move zone": touch.move_zone_rect(),
			"aim zone": touch.aim_zone_rect(),
			"pause button": touch.pause_button_rect(),
			"armor row": hud.armor_row_rect(),
		}
		touch.free()
		for other: String in others:
			if rect.intersects(others[other]):
				overlaps.append("%s %s %s vs %s" % [screen_size, other, others[other], rect])
		h.dispose()
	var _clear: GdUnitAssert = assert_array(overlaps).is_empty()


## The moved Boss Gauge (#127) behaves as before: hidden behind the Level Intro
## card, then a fill ratio that follows boss_gauge_changed.
func test_boss_gauge_still_tracks_points() -> void:
	var seen: Array[String] = []
	for screen_size: Vector2 in GAUGE_SIZES:
		var h: UiHarness = UiHarness.new(screen_size)
		add_child(h.host)
		h.reach_title()
		h.bus.flow.announce_play_requested()
		var hud: Hud = h.screen(&"Hud") as Hud
		var during_intro: bool = hud.gauge_shown()
		h.run.advance(h.run.levels[0].intro_duration + RunHarness.STEP)
		var after_intro: bool = hud.gauge_shown()
		h.bus.run.announce_boss_gauge_changed(1000, 4000)
		var quarter: float = hud.gauge_ratio()
		h.bus.run.announce_boss_gauge_changed(3000, 4000)
		var three_quarters: float = hud.gauge_ratio()
		seen.append(
			"%s %s %s %.2f %.2f" % [screen_size, during_intro, after_intro, quarter, three_quarters]
		)
		h.dispose()
	var _tracks: GdUnitAssert = (
		assert_array(seen)
		. is_equal(
			[
				"%s false true 0.25 0.75" % GAUGE_SIZES[0],
				"%s false true 0.25 0.75" % GAUGE_SIZES[1],
			]
		)
	)


## The HUD in the first Skirmish (past the Level Intro, so the gauge shows),
## laid out.
func _hud_in_skirmish(h: UiHarness) -> Hud:
	h.reach_title()
	h.bus.flow.announce_play_requested()
	h.run.advance(h.run.levels[0].intro_duration + RunHarness.STEP)
	await await_idle_frame()
	await await_idle_frame()
	return h.screen(&"Hud") as Hud
