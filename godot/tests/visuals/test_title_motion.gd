extends GdUnitTestSuite
## The title (#27): the logo follows the reduced-motion setting, the attract
## dogfight is the one title view (built from the game's own sky and models)
## and never lets coordinates grow without bound, and moving a sky's origin
## stays invisible.

const LOGO: PackedScene = preload("res://ui/title/title_logo.tscn")
## Frames to run while Boot hides the Title, and how long the Title's intro
## takes to settle.
const BOOT_FRAMES: int = 30
const INTRO_SETTLE_MS: int = 1200
## Simulated title time: long enough to show nothing drifts.
const LONG_RUN_SECONDS: int = 2000
const STEP_SECONDS: float = 1.0


func test_title_logo_follows_the_reduced_motion_setting() -> void:
	var logo: TitleLogo = LOGO.instantiate() as TitleLogo
	add_child(logo)
	var settings: GameSettings = GameSettings.new()
	settings.reduced_motion = true
	Events.profile.announce_settings_changed(settings)
	var reduced: bool = logo.reduced_motion
	logo.play_intro()
	var lettering: Control = logo.get_node(^"Lettering") as Control
	var title: Label = logo.get_node(^"Lettering/Title") as Label
	var settled: bool = lettering.scale == Vector2.ONE
	var shine: ShaderMaterial = title.material as ShaderMaterial
	var shine_value: Variant = shine.get_shader_parameter(&"shine_amount")
	var shine_off: bool = shine_value is float and shine_value == 0.0
	settings.reduced_motion = false
	Events.profile.announce_settings_changed(settings)
	var restored: bool = not logo.reduced_motion
	logo.free()
	var _reduced: GdUnitAssert = assert_bool(reduced).is_true()
	var _no_slam: GdUnitAssert = assert_bool(settled).is_true()
	var _no_shine: GdUnitAssert = assert_bool(shine_off).is_true()
	var _follows_back: GdUnitAssert = assert_bool(restored).is_true()


func test_title_logo_lettering_stays_inside_its_box_after_boot() -> void:
	var stray: Array[String] = []
	for screen_size: Vector2 in [UiHarness.LANDSCAPE, UiHarness.PORTRAIT]:
		# Motion on: the logo floats every frame, also while hidden behind Boot,
		# when its box is still 0x0.
		var h: UiHarness = UiHarness.new(screen_size, false)
		add_child(h.host)
		h.boot()
		for _frame: int in BOOT_FRAMES:
			await await_idle_frame()
		h.bus.flow.announce_start_requested()
		await await_millis(INTRO_SETTLE_MS)
		var title: TitleScreen = h.screen(&"Title") as TitleScreen
		var logo: TitleLogo = title.logo()
		var lettering: Control = logo.get_node(^"Lettering") as Control
		var letters: Rect2 = lettering.get_global_rect()
		var box: Rect2 = logo.get_global_rect().grow(TitleLogo.FLOAT_AMPLITUDE + 1.0)
		var play: Rect2 = title.default_focus().get_global_rect()
		if not box.encloses(letters):
			stray.append("%s: lettering %s outside its box %s" % [screen_size, letters, box])
		if letters.end.y > play.position.y:
			stray.append("%s: lettering %s overlaps PLAY %s" % [screen_size, letters, play])
		h.dispose()
	var _inside: GdUnitAssert = assert_array(stray).is_empty()


func test_attract_flight_stays_bounded() -> void:
	var attract: AttractDogfight = AttractDogfight.new()
	add_child(attract)
	var farthest: float = 0.0
	for _step: int in LONG_RUN_SECONDS:
		attract.step(STEP_SECONDS)
		farthest = maxf(farthest, attract.mech().position.length())
		for enemy: EnemyVisual in attract.enemies():
			farthest = maxf(farthest, enemy.position.length())
	attract.free()
	# The dogfight orbits the origin, so however long the Title runs, nothing
	# drifts away from it (coordinates stay small; no re-origin is needed).
	var bound: float = AttractDogfight.ORBIT_RADIUS + absf(AttractDogfight.ENEMY_DEPTH)
	var _bounded: GdUnitAssert = assert_float(farthest).is_less_equal(bound)


func test_attract_owns_the_title_view_and_hands_it_back() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	var attract: AttractDogfight = main.get_node(^"Attract") as AttractDogfight
	# One title view, made of the game's own sky and models.
	var looks: bool = (
		attract.sky().sky_id == &"dawn"
		and attract.view_environment() == attract.sky().environment()
		and attract.mech() is PlayerMechVisual
		and attract.enemies().size() == AttractDogfight.ENEMY_IDS.size()
	)
	# Its camera renders only the attract layer: the resting flight stage
	# (default layer 1) never shows behind the Title.
	var own_layer: bool = attract.view_layers() == 1 << (AttractDogfight.VISUAL_LAYER - 1)
	var title_view: bool = attract.is_active() and attract.has_view()
	Events.flow.announce_game_state_changed(GameState.Phase.TITLE, GameState.Phase.LEVEL_INTRO)
	var stage: FlightStage = main.get_node(^"FlightStage") as FlightStage
	var handed_back: bool = (
		not attract.is_active() and not attract.has_view() and stage.camera_rig().camera().current
	)
	Events.flow.announce_game_state_changed(GameState.Phase.GAME_OVER, GameState.Phase.TITLE)
	var back_to_title: bool = attract.is_active() and attract.has_view()
	main.free()
	var _looks: GdUnitAssert = assert_bool(looks).is_true()
	var _own_layer: GdUnitAssert = assert_bool(own_layer).is_true()
	var _title: GdUnitAssert = assert_bool(title_view).is_true()
	var _handed_back: GdUnitAssert = assert_bool(handed_back).is_true()
	var _back: GdUnitAssert = assert_bool(back_to_title).is_true()


func test_sky_shift_origin_is_seamless() -> void:
	var sky: SkyEnvironment = SkyLibrary.instantiate(&"dawn")
	add_child(sky)
	var focus: Vector3 = Vector3(1234.5, -321.0, 0.0)
	var shift: Vector3 = Vector3(1000.0, 0.0, 0.0)
	sky.follow(focus)
	var layers: Array[CloudLayer] = sky.cloud_layers()
	var start_at: Array[PackedVector2Array] = []
	for layer: CloudLayer in layers:
		start_at.append(layer.puff_positions())
	sky.shift_origin(shift)
	sky.follow(focus - shift)
	var jumped: Array[String] = []
	for i: int in layers.size():
		var now: PackedVector2Array = layers[i].puff_positions()
		for j: int in now.size():
			var expected: Vector2 = start_at[i][j] - Vector2(shift.x, shift.y)
			if not now[j].is_equal_approx(expected):
				jumped.append("%s puff %d: %s, expected %s" % [layers[i].name, j, now[j], expected])
	var offset_value: Variant = sky.sky_material().get_shader_parameter(
		SkyEnvironment.WORLD_OFFSET_PARAM
	)
	var offset_set: bool = offset_value is Vector2 and offset_value == Vector2(shift.x, shift.y)
	sky.free()
	var _seamless: GdUnitAssert = assert_array(jumped).is_empty()
	var _parallax_kept: GdUnitAssert = assert_bool(offset_set).is_true()
