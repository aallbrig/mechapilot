extends GdUnitTestSuite
## The game guide (#75): How to Play with the current device's glyphs, the
## first-flight tutorial prompts on the HUD, and the Intel codex.

var _h: UiHarness


func before_test() -> void:
	_h = UiHarness.new()
	add_child(_h.host)


func after_test() -> void:
	_h.dispose()


func _button(screen_name: StringName, text: String) -> Button:
	for control: Control in _h.screen(screen_name).juiced_controls():
		if control is Button and (control as Button).text == text:
			return control as Button
	return null


func test_how_to_play_shows_current_device_glyphs() -> void:
	_h.reach_title()
	_h.ui.open(&"how_to_play")
	var guide: HowToPlayScreen = _h.screen(&"HowToPlay") as HowToPlayScreen
	var seen: Array[String] = [guide.controls_text()]
	for device: InputDevice.Kind in [InputDevice.Kind.GAMEPAD, InputDevice.Kind.TOUCH]:
		_h.bus.flow.announce_input_device_changed(device)
		seen.append(guide.controls_text())
	guide.turn(1)
	var aiming_touch: String = guide.controls_text()
	_h.bus.flow.announce_input_device_changed(InputDevice.Kind.KEYBOARD_MOUSE)
	var aiming_mouse: String = guide.controls_text()
	var _glyphs: GdUnitAssert = assert_array(seen).is_equal(
		["[WASD] move", "[Left stick] move", "[Left thumb] move"]
	)
	var _page: GdUnitAssert = assert_str(guide.page_title()).is_equal("AIMING AND GRAVITY SHOTS")
	var _touch: GdUnitAssert = assert_str(aiming_touch).contains("[Tap right]")
	var _mouse: GdUnitAssert = assert_str(aiming_mouse).is_equal("[Mouse] aim [Click] fire")


func test_how_to_play_has_a_page_per_topic() -> void:
	_h.reach_title()
	_h.ui.open(&"how_to_play")
	var guide: HowToPlayScreen = _h.screen(&"HowToPlay") as HowToPlayScreen
	var titles: Array[String] = []
	for i: int in GuidePages.count():
		titles.append(guide.page_title())
		guide.turn(1)
	var _six: GdUnitAssert = (
		assert_array(titles)
		. is_equal(
			[
				"MOVING",
				"AIMING AND GRAVITY SHOTS",
				"ARMOR AND REPAIR KITS",
				"LIVES AND THE BONUS LIFE",
				"THE BOSS GAUGE AND BOSSES",
				"COMBOS",
			]
		)
	)
	var _wraps: GdUnitAssert = assert_int(guide.page()).is_equal(0)


func test_how_to_play_reachable_from_title_and_pause() -> void:
	_h.reach_title()
	_button(&"Title", "HOW TO PLAY").pressed.emit()
	var from_title: Array[StringName] = _h.ui.visible_screens()
	_h.ui.close_top()
	var back_on_title: Array[StringName] = _h.ui.visible_screens()
	_h.bus.flow.announce_play_requested()
	_h.bus.flow.announce_pause_requested()
	_button(&"Pause", "HOW TO PLAY").pressed.emit()
	var from_pause: Array[StringName] = _h.ui.visible_screens()
	_h.ui.close_top()
	var _title: GdUnitAssert = assert_array(from_title).is_equal([&"HowToPlay"])
	var _back: GdUnitAssert = assert_array(back_on_title).is_equal([&"Title"])
	var _pause: GdUnitAssert = assert_array(from_pause).is_equal([&"HowToPlay"])
	var _resume: GdUnitAssert = assert_array(_h.ui.visible_screens()).is_equal([&"Pause"])


func test_tutorial_prompt_shows_on_hud_with_device_glyphs() -> void:
	_h.reach_title()
	_h.bus.flow.announce_play_requested()
	var hud: Hud = _h.screen(&"Hud") as Hud
	_h.bus.run.announce_tutorial_prompt_shown(TutorialPrompt.Id.MOVE)
	var keyboard: String = hud.tutorial_text()
	_h.bus.flow.announce_input_device_changed(InputDevice.Kind.GAMEPAD)
	var gamepad: String = hud.tutorial_text()
	_h.bus.run.announce_tutorial_prompt_dismissed(TutorialPrompt.Id.MOVE, true)
	var _keys: GdUnitAssert = assert_str(keyboard).is_equal("[WASD] move")
	var _pad: GdUnitAssert = assert_str(gamepad).is_equal("[Left stick] move")
	var _gone: GdUnitAssert = assert_str(hud.tutorial_text()).is_empty()


func test_intel_entry_unlocks_on_first_encounter() -> void:
	var catalog: Array[IntelEntry] = IntelCodex.entries_for(_h.run.levels)
	var store: MemoryDocumentStore = MemoryDocumentStore.new()
	var codex: IntelCodex = IntelCodex.new(
		_h.bus, store, IntelCodex.catalog(_h.run.levels), catalog
	)
	codex.restore()
	_h.reach_title()
	_h.ui.open(&"intel")
	var intel: IntelScreen = _h.screen(&"Intel") as IntelScreen
	intel.select(&"heavy")
	var locked: PackedStringArray = intel.lines()
	var silhouette: bool = intel.preview_locked()
	_h.bus.flow.announce_game_state_changed(GameState.Phase.TITLE, GameState.Phase.SKIRMISH)
	_h.bus.enemy.announce_enemy_spawned(1, EnemyKind.Kind.HEAVY, Vector3.ZERO)
	_h.bus.flow.announce_game_state_changed(GameState.Phase.SKIRMISH, GameState.Phase.TITLE)
	_h.ui.open(&"intel")
	intel.select(&"heavy")
	var unlocked: PackedStringArray = intel.lines()
	var reloaded: IntelCodex = IntelCodex.new(
		_h.bus, store, IntelCodex.catalog(_h.run.levels), catalog
	)
	reloaded.restore()
	intel.select(&"heavy")
	var after_reload: PackedStringArray = intel.lines()
	var _count: GdUnitAssert = assert_int(intel.entry_count()).is_equal(catalog.size())
	var _hidden: GdUnitAssert = assert_array(locked).is_equal(
		["???", IntelScreen.LOCKED_DESCRIPTION, "??? HP   ??? PTS"]
	)
	var _dark: GdUnitAssert = assert_bool(silhouette).is_true()
	var _known: GdUnitAssert = assert_str(unlocked[0]).is_equal("HEAVY")
	var _stats: GdUnitAssert = assert_str(unlocked[2]).is_equal("4 HP   300 PTS")
	var _lit: GdUnitAssert = assert_bool(intel.preview_locked()).is_false()
	var _persisted: GdUnitAssert = assert_array(after_reload).is_equal(unlocked)


func test_intel_lists_every_enemy_and_boss() -> void:
	var catalog: Array[IntelEntry] = IntelCodex.entries_for(_h.run.levels)
	var bosses: int = 0
	var missing: Array[String] = []
	for entry: IntelEntry in catalog:
		bosses += 1 if entry.boss else 0
		if entry.description.is_empty() or entry.hit_points <= 0 or entry.points <= 0:
			missing.append(str(entry.id))
	var _all: GdUnitAssert = assert_int(catalog.size()).is_equal(
		EnemyKind.IDS.size() + RunRules.LEVEL_COUNT
	)
	var _six_bosses: GdUnitAssert = assert_int(bosses).is_equal(RunRules.LEVEL_COUNT)
	var _complete: GdUnitAssert = assert_array(missing).is_empty()


## Every laid-out control under `root` (what a ScrollContainer holds scrolls).
func _laid_out(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in root.get_children():
		if child is Control:
			found.append(child as Control)
		if not child is ScrollContainer:
			found.append_array(_laid_out(child))
	return found


func _outside(screen_node: Control, bounds: Rect2, where: String) -> Array[String]:
	var out: Array[String] = []
	for control: Control in _laid_out(screen_node):
		var rect: Rect2 = control.get_global_rect()
		if (
			control.is_visible_in_tree()
			and control.size != Vector2.ZERO
			and not bounds.encloses(rect)
		):
			out.append("%s %s %s" % [where, control.name, rect])
	return out


func test_guide_screens_fit_phone_portrait_to_4k() -> void:
	var overflow: Array[String] = []
	for screen_size: Vector2 in [UiHarness.PORTRAIT, UiHarness.LANDSCAPE, Vector2(853.0, 640.0)]:
		var h: UiHarness = UiHarness.new(screen_size)
		add_child(h.host)
		h.boot()
		var empty: Array[StringName] = []
		var codex: IntelCodex = IntelCodex.new(
			h.bus, MemoryDocumentStore.new(), empty, IntelCodex.entries_for(h.run.levels)
		)
		codex.restore()
		h.bus.flow.announce_start_requested()
		var bounds: Rect2 = Rect2(Vector2.ZERO, screen_size).grow(1.0)
		h.ui.open(&"how_to_play")
		var guide: HowToPlayScreen = h.screen(&"HowToPlay") as HowToPlayScreen
		for page: int in GuidePages.count():
			await await_idle_frame()
			await await_idle_frame()
			overflow.append_array(_outside(guide, bounds, "%s guide %d" % [screen_size, page]))
			guide.turn(1)
		h.ui.close_top()
		h.ui.open(&"intel")
		var intel: IntelScreen = h.screen(&"Intel") as IntelScreen
		for entry: int in intel.entry_count():
			await await_idle_frame()
			overflow.append_array(_outside(intel, bounds, "%s intel %d" % [screen_size, entry]))
			intel.choose(1)
		h.ui.close_top()
		h.bus.flow.announce_play_requested()
		h.bus.run.announce_tutorial_prompt_shown(TutorialPrompt.Id.SHOTS_DROP)
		await await_idle_frame()
		await await_idle_frame()
		overflow.append_array(_outside(h.screen(&"Hud"), bounds, "%s hud" % screen_size))
		h.dispose()
	var _fits: GdUnitAssert = assert_array(overflow).is_empty()
