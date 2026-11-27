extends GdUnitTestSuite
## The six level skies (#27, #73): each Level data sky id maps to a complete
## environment, the storm's weather works, and cloud layers wrap around the
## player however far it flies.

## The sky themes of the six levels, in level order (#73's level table).
const SKY_IDS: Array[StringName] = [
	&"dawn", &"storm", &"sunset", &"night", &"stratosphere", &"orbit"
]
const MIN_CLOUD_LAYERS: int = 3
## A focus far from the origin, on both axes, to prove the wrap holds anywhere.
const FAR_FOCUS: Vector2 = Vector2(12345.0, -6789.0)
const WRAP_EPSILON: float = 0.001


func test_every_level_sky_id_maps_to_an_environment() -> void:
	var broken: Array[String] = []
	for sky_id: StringName in SkyLibrary.ids():
		var sky: SkyEnvironment = SkyLibrary.instantiate(sky_id)
		add_child(sky)
		broken.append_array(_environment_problems(sky_id, sky))
		sky.free()
	# Every Level, read through core/'s LevelDefinition, gets its own theme's sky.
	var errors: Array[String] = []
	var levels: Array[LevelDefinition] = LevelLibrary.all_levels(errors)
	var level_themes: Array[StringName] = []
	for level: LevelDefinition in levels:
		level_themes.append(level.sky_theme)
		var sky: SkyEnvironment = SkyLibrary.for_level(level)
		if sky == null or sky.sky_id != level.sky_theme:
			broken.append("level %d: no sky for theme %s" % [level.number, level.sky_theme])
		if sky != null:
			sky.free()
	var _ids: GdUnitAssert = assert_array(SkyLibrary.ids()).is_equal(SKY_IDS)
	var _themes: GdUnitAssert = assert_array(LevelDefinition.SKY_THEMES).is_equal(SKY_IDS)
	var _levels_load: GdUnitAssert = assert_array(errors).is_empty()
	var _one_per_level: GdUnitAssert = assert_array(level_themes).is_equal(SKY_IDS)
	var _complete: GdUnitAssert = assert_array(broken).is_empty()


func test_unknown_sky_id_has_no_environment() -> void:
	var _known: GdUnitAssert = assert_bool(SkyLibrary.has_sky(&"dawn")).is_true()
	var _unknown: GdUnitAssert = assert_bool(SkyLibrary.has_sky(&"mars")).is_false()


func test_storm_flashes_lightning_and_rains() -> void:
	var storm: SkyEnvironment = SkyLibrary.instantiate(&"storm")
	add_child(storm)
	var calm_energy: float = storm.sun().light_energy
	var strikes: Array[float] = []
	var err: Error = storm.lightning_struck.connect(strikes.append) as Error
	storm.strike(1.0)
	var lit_energy: float = storm.sun().light_energy
	var flash_value: Variant = storm.sky_material().get_shader_parameter(SkyEnvironment.FLASH_PARAM)
	var flash: float = flash_value if flash_value is float else -1.0
	storm._process(10.0)
	var faded: float = storm.flash_amount()
	var has_rain: bool = storm.get_node_or_null(^"Weather/Rain") != null
	storm.free()
	var dawn: SkyEnvironment = SkyLibrary.instantiate(&"dawn")
	add_child(dawn)
	var dawn_storms: bool = dawn.has_lightning() or dawn.get_node_or_null(^"Weather") != null
	dawn.free()
	var _connected: GdUnitAssert = assert_int(err).is_equal(OK)
	var _struck: GdUnitAssert = assert_array(strikes).is_not_empty()
	var _brighter: GdUnitAssert = assert_float(lit_energy).is_greater(calm_energy)
	var _sky_flash: GdUnitAssert = assert_float(flash).is_equal_approx(1.0, 0.001)
	var _fades: GdUnitAssert = assert_float(faded).is_less(1.0)
	var _rain: GdUnitAssert = assert_bool(has_rain).is_true()
	var _dawn_calm: GdUnitAssert = assert_bool(dawn_storms).is_false()


func test_clouds_wrap_around_player() -> void:
	var sky: SkyEnvironment = SkyLibrary.instantiate(&"dawn")
	add_child(sky)
	var outside: Array[String] = []
	var layers: Array[CloudLayer] = sky.cloud_layers()
	var starts: Array[PackedVector2Array] = []
	for layer: CloudLayer in layers:
		starts.append(layer.puff_positions())
	# Fly far away: every puff must be inside the layer's window around the player.
	sky.follow(Vector3(FAR_FOCUS.x, FAR_FOCUS.y, 0.0))
	for layer: CloudLayer in layers:
		outside.append_array(_outside_window(layer, FAR_FOCUS))
	# A short hop: puffs either stay put or jump by exactly one window span.
	var hop: Vector2 = FAR_FOCUS + Vector2(3.0, -2.0)
	var bad_jumps: Array[String] = []
	for layer: CloudLayer in layers:
		var start_at: PackedVector2Array = layer.puff_positions()
		layer.follow(hop)
		var end_at: PackedVector2Array = layer.puff_positions()
		for i: int in start_at.size():
			var moved: Vector2 = end_at[i] - start_at[i]
			if not (_is_wrap_step(moved.x, layer.span.x) and _is_wrap_step(moved.y, layer.span.y)):
				bad_jumps.append("%s puff %d moved %s" % [layer.name, i, moved])
		outside.append_array(_outside_window(layer, hop))
	# Coming home restores the original sky: the wrap is stateless.
	sky.follow(Vector3.ZERO)
	var restored: bool = true
	for i: int in layers.size():
		restored = restored and _same_positions(layers[i].puff_positions(), starts[i])
	sky.free()
	var _layers: GdUnitAssert = assert_int(layers.size()).is_greater_equal(MIN_CLOUD_LAYERS)
	var _inside: GdUnitAssert = assert_array(outside).is_empty()
	var _steps: GdUnitAssert = assert_array(bad_jumps).is_empty()
	var _home: GdUnitAssert = assert_bool(restored).is_true()


func test_clouds_drift_with_the_wind_and_stay_wrapped() -> void:
	var layer: CloudLayer = CloudLayer.new()
	layer.count = 8
	layer.span = Vector2(40.0, 20.0)
	layer.wind = Vector2(-5.0, 1.0)
	add_child(layer)
	var start_at: PackedVector2Array = layer.puff_positions()
	for _step: int in 100:
		layer._process(0.5)
	var end_at: PackedVector2Array = layer.puff_positions()
	var outside: Array[String] = _outside_window(layer, Vector2.ZERO)
	layer.free()
	var _moved: GdUnitAssert = assert_bool(_same_positions(start_at, end_at)).is_false()
	var _inside: GdUnitAssert = assert_array(outside).is_empty()


func test_cloud_wrap_point_handles_any_distance() -> void:
	var window: Vector2 = Vector2(10.0, 4.0)
	var near: Vector2 = CloudLayer.wrap_point(Vector2(2.0, 1.0), Vector2.ZERO, window)
	var far: Vector2 = CloudLayer.wrap_point(Vector2(2.0, 1.0), Vector2(1e5 + 0.25, -3e4), window)
	var _unchanged: GdUnitAssert = assert_vector(near).is_equal_approx(
		Vector2(2.0, 1.0), Vector2.ONE * WRAP_EPSILON
	)
	var _x: GdUnitAssert = assert_float(absf(far.x - (1e5 + 0.25))).is_less_equal(window.x * 0.5)
	var _y: GdUnitAssert = assert_float(absf(far.y + 3e4)).is_less_equal(window.y * 0.5)


func _environment_problems(sky_id: StringName, sky: SkyEnvironment) -> Array[String]:
	var problems: Array[String] = []
	if sky == null:
		return ["%s: no scene" % sky_id]
	if sky.sky_id != sky_id:
		problems.append("%s: scene answers to %s" % [sky_id, sky.sky_id])
	var env: Environment = sky.environment()
	if env == null or env.background_mode != Environment.BG_SKY:
		problems.append("%s: background is not its sky shader" % sky_id)
	var material: ShaderMaterial = sky.sky_material()
	var shader_path: String = material.shader.resource_path if material != null else ""
	if shader_path != "res://game/visuals/sky/themes/%s.gdshader" % sky_id:
		problems.append("%s: sky shader is %s" % [sky_id, shader_path])
	if sky.sun() == null or sky.sun().shadow_enabled:
		problems.append("%s: needs a shadowless sun" % sky_id)
	if sky.cloud_layers().size() < MIN_CLOUD_LAYERS:
		problems.append("%s: %d cloud layers" % [sky_id, sky.cloud_layers().size()])
	return problems


func _outside_window(layer: CloudLayer, focus: Vector2) -> Array[String]:
	var out: Array[String] = []
	for at: Vector2 in layer.puff_positions():
		var offset: Vector2 = (at - focus).abs()
		var half: Vector2 = layer.span * 0.5 + Vector2.ONE * WRAP_EPSILON
		if offset.x > half.x or offset.y > half.y:
			out.append("%s puff at %s, focus %s" % [layer.name, at, focus])
	return out


func _is_wrap_step(moved: float, span: float) -> bool:
	return absf(moved) < WRAP_EPSILON or absf(absf(moved) - span) < WRAP_EPSILON * 100.0


func _same_positions(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if not a[i].is_equal_approx(b[i]):
			return false
	return true
