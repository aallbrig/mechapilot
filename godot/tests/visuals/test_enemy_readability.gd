extends GdUnitTestSuite
## Every enemy stands out against every Level's sky (#135), measured from real
## rendered frames: ReadabilityCapture renders each enemy kind and the player
## mech in front of each Level's sky with the game's renderer, lighting, fog,
## glow and gameplay camera, at three heights on a phone's portrait screen, and
## these tests measure those frames (ReadabilityFrames). The frames must be the
## current visuals' (ReadabilityFingerprint): after a change to a model, a
## material, a sky or the camera, run `task godot:capture:readability` and
## commit the new captures.

## WCAG's minimum contrast for large graphical objects.
const MIN_CONTRAST: float = 3.0
## The player and an enemy differ by this much hue, or this much luminance.
const MIN_HUE_GAP: float = 60.0
const MIN_PLAYER_CONTRAST: float = 3.0


func test_every_enemy_reads_against_every_level_sky() -> void:
	var frames: ReadabilityFrames = ReadabilityFrames.committed()
	var _current: GdUnitAssert = assert_array(_capture_problems(frames)).is_empty()
	var _readable: GdUnitAssert = (
		assert_array(_low_contrast(frames, ReadabilityFrames.Vision.NORMAL)).is_empty()
	)


func test_enemy_contrast_survives_colour_blind_simulation() -> void:
	var frames: ReadabilityFrames = ReadabilityFrames.committed()
	var _current: GdUnitAssert = assert_array(_capture_problems(frames)).is_empty()
	var _deuteranopia: GdUnitAssert = (
		assert_array(_low_contrast(frames, ReadabilityFrames.Vision.DEUTERANOPIA)).is_empty()
	)
	var _protanopia: GdUnitAssert = (
		assert_array(_low_contrast(frames, ReadabilityFrames.Vision.PROTANOPIA)).is_empty()
	)


func test_player_and_enemies_stay_distinct() -> void:
	var frames: ReadabilityFrames = ReadabilityFrames.committed()
	var _current: GdUnitAssert = assert_array(_capture_problems(frames)).is_empty()
	# Compared spot by spot: the player and an enemy at the same height on
	# screen are in front of the same sky, as they are in play.
	var alike: Array[String] = []
	var pairs: int = 0
	for level: LevelDefinition in _levels():
		for player: ReadabilityFrames.Sample in frames.of_level(
			level.number, ReadabilityFrames.PLAYER
		):
			var player_hue: float = ReadabilityFrames.dominant_hue(player.silhouette)
			var player_luminance: float = ReadabilityFrames.mean_luminance(player.silhouette)
			for enemy: ReadabilityFrames.Sample in frames.of_level(level.number):
				if enemy.is_player() or enemy.spot != player.spot:
					continue
				pairs += 1
				var enemy_hue: float = ReadabilityFrames.dominant_hue(enemy.silhouette)
				var hue_gap: float = -1.0
				if player_hue >= 0.0 and enemy_hue >= 0.0:
					hue_gap = ReadabilityFrames.hue_distance(player_hue, enemy_hue)
				var ratio: float = ReadabilityFrames.contrast_ratio(
					player_luminance, ReadabilityFrames.mean_luminance(enemy.silhouette)
				)
				if hue_gap < MIN_HUE_GAP and ratio < MIN_PLAYER_CONTRAST:
					alike.append(
						(
							"%s: player hue %.0f, enemy hue %.0f (gap %.0f), luminance %.2f:1"
							% [enemy.label(), player_hue, enemy_hue, hue_gap, ratio]
						)
					)
	var _all_pairs: GdUnitAssert = assert_int(pairs).is_equal(
		6 * EnemyKind.IDS.size() * ReadabilityCapture.SPOTS.size()
	)
	var _distinct: GdUnitAssert = assert_array(alike).is_empty()


func test_enemies_wear_the_hostile_material_matched_to_the_followed_sky() -> void:
	# The captures only vouch for play if the game wires the same look: every
	# enemy (and only enemies) wears the shared hostile material, a flash
	# restores it, and the sky being followed sets its gradient and accent.
	var wrong: Array[String] = []
	var hostile: ShaderMaterial = VisualPiece.HOSTILE_MATERIAL
	for sky_id: StringName in SkyLibrary.ids():
		var sky: SkyEnvironment = SkyLibrary.instantiate(sky_id)
		add_child(sky)
		sky.follow(Vector3.ZERO)
		if not sky.hostiles_match():
			wrong.append("%s: following it does not match the hostiles" % sky_id)
		for param: StringName in SkyEnvironment.GRADIENT_PARAMS:
			var want: Variant = sky.sky_material().get_shader_parameter(param)
			var have: Variant = hostile.get_shader_parameter(param)
			if want != have:
				wrong.append("%s: hostile %s is %s, sky has %s" % [sky_id, param, have, want])
		if hostile.get_shader_parameter(&"hostile_accent") != sky.hostile_accent:
			wrong.append("%s: hostile accent not the sky's" % sky_id)
		if hostile.get_shader_parameter(&"dark_above") != sky.hostile_dark_above:
			wrong.append("%s: dark_above not the sky's" % sky_id)
		sky.free()
	for enemy_id: StringName in EnemyKind.IDS:
		var enemy: EnemyVisual = VisualLibrary.enemy(enemy_id)
		add_child(enemy)
		enemy.set_flash(true)
		enemy.set_flash(false)
		for piece: VisualPiece in enemy.pieces():
			if piece.material_override != hostile:
				wrong.append("%s: %s is not hostile after a flash" % [enemy_id, piece.name])
		enemy.free()
	var mech: PlayerMechVisual = VisualLibrary.player_mech()
	add_child(mech)
	for piece: VisualPiece in mech.pieces():
		if piece.material_override != VisualPiece.HULL_MATERIAL:
			wrong.append("player %s does not wear the hull material" % piece.name)
	mech.free()
	var _wired: GdUnitAssert = assert_array(wrong).is_empty()


func test_readability_measures_contrast_hue_and_colour_blindness() -> void:
	# The measures on known colours, so a broken formula cannot pass the tests above.
	var white: float = ReadabilityFrames.luminance(Color.WHITE)
	var black: float = ReadabilityFrames.luminance(Color.BLACK)
	var _range: GdUnitAssert = (
		assert_float(ReadabilityFrames.contrast_ratio(white, black)).is_equal_approx(21.0, 0.001)
	)
	var grey: float = ReadabilityFrames.luminance(Color8(118, 118, 118))
	# WCAG: #767676 on white is 4.54:1.
	var _grey: GdUnitAssert = (
		assert_float(ReadabilityFrames.contrast_ratio(white, grey)).is_equal_approx(4.54, 0.01)
	)
	# Red and green of equal luminance for most viewers collapse for dichromats.
	var red: Color = Color(1.0, 0.0, 0.0)
	var protan_red: float = ReadabilityFrames.luminance(red, ReadabilityFrames.Vision.PROTANOPIA)
	var _darker: GdUnitAssert = assert_float(protan_red).is_less(ReadabilityFrames.luminance(red))
	var hues: PackedColorArray = PackedColorArray(
		[Color(1.0, 0.1, 0.1), Color(1.0, 0.1, 0.1), Color.WHITE]
	)
	var _red: GdUnitAssert = assert_float(ReadabilityFrames.dominant_hue(hues)).is_less(5.0)
	var greys: PackedColorArray = PackedColorArray([Color.GRAY, Color.WHITE])
	var _none: GdUnitAssert = assert_float(ReadabilityFrames.dominant_hue(greys)).is_equal(-1.0)
	var _wrap: GdUnitAssert = (
		assert_float(ReadabilityFrames.hue_distance(350.0, 20.0)).is_equal_approx(30.0, 0.001)
	)
	var pixels: PackedColorArray = PackedColorArray([Color8(1, 2, 3), Color8(250, 128, 0)])
	var _round_trip: GdUnitAssert = (
		assert_array(ReadabilityFrames.decode(ReadabilityFrames.encode(pixels))).is_equal(pixels)
	)


## Why the committed captures cannot vouch for the current game: missing,
## unreadable, stale (made from other render inputs) or incomplete.
func _capture_problems(frames: ReadabilityFrames) -> Array[String]:
	var problems: Array[String] = []
	problems.append_array(frames.errors)
	var current: String = ReadabilityFingerprint.compute()
	if frames.fingerprint != current:
		problems.append(
			(
				(
					"captures are stale (made from %s, the visuals are now %s): "
					+ "run task godot:capture:readability"
				)
				% [frames.fingerprint.left(12), current.left(12)]
			)
		)
	for level: LevelDefinition in _levels():
		for subject: StringName in ReadabilityCapture.subjects():
			var spots: Array[int] = []
			for sample: ReadabilityFrames.Sample in frames.of_level(level.number, subject):
				if sample.theme != level.sky_theme:
					problems.append(
						"%s: Level %d's sky is %s" % [sample.label(), level.number, level.sky_theme]
					)
				spots.append(sample.spot)
			spots.sort()
			var want: Array[int] = []
			for spot: int in ReadabilityCapture.SPOTS.size():
				want.append(spot)
			if spots != want:
				problems.append(
					(
						"level %d %s: captured at spots %s, want %s"
						% [level.number, subject, spots, want]
					)
				)
	return problems


## Every enemy sample under `vision` with less than MIN_CONTRAST against its sky.
func _low_contrast(frames: ReadabilityFrames, vision: ReadabilityFrames.Vision) -> Array[String]:
	var low: Array[String] = []
	var enemies: int = 0
	for sample: ReadabilityFrames.Sample in frames.samples:
		if sample.is_player():
			continue
		enemies += 1
		var ratio: float = sample.contrast(vision)
		if ratio < MIN_CONTRAST:
			low.append(
				"%s: %.2f:1 (%s)" % [sample.label(), ratio, ReadabilityFrames.Vision.keys()[vision]]
			)
	if enemies == 0:
		low.append("no enemy samples")
	return low


func _levels() -> Array[LevelDefinition]:
	var errors: Array[String] = []
	var levels: Array[LevelDefinition] = LevelLibrary.all_levels(errors)
	var _loaded: GdUnitAssert = assert_array(errors).is_empty()
	var _six: GdUnitAssert = assert_int(levels.size()).is_equal(6)
	return levels
