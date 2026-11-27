extends GdUnitTestSuite
## The title screen respects the player (#27): the logo follows the
## reduced-motion setting, and the title flight never lets coordinates grow
## without bound, while re-origining stays invisible.

const LOGO: PackedScene = preload("res://ui/title/title_logo.tscn")
const BACKDROP: PackedScene = preload("res://game/visuals/title_backdrop.tscn")
## Simulated title time: long enough to re-origin many times.
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


func test_title_flight_reorigins_so_coordinates_stay_bounded() -> void:
	var backdrop: TitleBackdrop = BACKDROP.instantiate() as TitleBackdrop
	add_child(backdrop)
	var farthest: float = 0.0
	for _step: int in LONG_RUN_SECONDS:
		backdrop._process(STEP_SECONDS)
		farthest = maxf(farthest, absf(backdrop.camera_position().x))
	var sky: SkyEnvironment = backdrop.get_node(^"Sky") as SkyEnvironment
	var travelled: float = sky.world_offset().x + backdrop.camera_position().x
	backdrop.free()
	var bound: float = TitleBackdrop.REORIGIN_DISTANCE + TitleBackdrop.CRUISE_SPEED * STEP_SECONDS
	var _bounded: GdUnitAssert = assert_float(farthest).is_less_equal(bound)
	# The flight really travelled the whole way; the origin just moved with it.
	var _travelled: GdUnitAssert = assert_float(travelled).is_equal_approx(
		TitleBackdrop.CRUISE_SPEED * LONG_RUN_SECONDS * STEP_SECONDS, 0.01
	)


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
