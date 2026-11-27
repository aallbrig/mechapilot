extends GdUnitTestSuite
## The camera's share of the juice (#26): shot kicks, shake that grows with the
## Combo, big shakes for deaths and boss kills, and the settings that turn
## camera motion and hit-stop off.

var _bus: EventBus
var _camera: CameraJuice
var _time: TimeScaleDirector
var _trauma: Array[float] = []
var _kicks: Array[Vector3] = []
var _punches: Array[float] = []


func before_test() -> void:
	_trauma.clear()
	_kicks.clear()
	_punches.clear()
	_bus = EventBus.new()
	_camera = CameraJuice.new()
	add_child(_camera)
	_camera.bind(_bus)
	_time = TimeScaleDirector.new()
	add_child(_time)
	_time.bind(_bus)
	var _a: int = _camera.trauma_requested.connect(_on_trauma)
	var _b: int = _camera.kick_requested.connect(_on_kick)
	var _c: int = _camera.fov_punch_requested.connect(_on_punch)


func after_test() -> void:
	_time.free()
	_camera.free()
	_bus.free()


func _on_trauma(amount: float) -> void:
	_trauma.append(amount)


func _on_kick(offset: Vector3) -> void:
	_kicks.append(offset)


func _on_punch(degrees: float) -> void:
	_punches.append(degrees)


func _settings(shake: bool, reduced_motion: bool) -> GameSettings:
	var settings: GameSettings = GameSettings.new()
	settings.screen_shake = shake
	settings.reduced_motion = reduced_motion
	return settings


func _kill_at(multiplier: int) -> float:
	_trauma.clear()
	_bus.run.announce_kill_scored(100 * multiplier, multiplier, Vector3.ZERO)
	return _trauma[0] if _trauma.size() == 1 else -1.0


func test_shake_scales_with_the_combo() -> void:
	var single: float = _kill_at(1)
	var double: float = _kill_at(2)
	var quad: float = _kill_at(4)
	var full: float = _kill_at(8)
	var _shakes: GdUnitAssert = assert_float(single).is_greater(0.0)
	var _grows: GdUnitAssert = assert_float(double).is_greater(single)
	var _grows_more: GdUnitAssert = assert_float(quad).is_greater(double)
	var _top: GdUnitAssert = assert_float(full).is_greater(quad)
	var _capped: GdUnitAssert = assert_float(full).is_less_equal(CameraJuice.KILL_TRAUMA_MAX)
	var _death_is_bigger: GdUnitAssert = assert_float(CameraJuice.DEATH_TRAUMA).is_greater(full)


func test_reduced_motion_disables_shake_and_hitstop() -> void:
	_bus.profile.announce_settings_changed(_settings(true, true))
	_bus.player.announce_player_fired(Vector3.ZERO, Vector3.RIGHT)
	_bus.enemy.announce_enemy_destroyed(
		1, EnemyKind.Kind.FIGHTER, Vector3.ZERO, DestroyCause.Cause.SHOT
	)
	_bus.run.announce_kill_scored(800, 8, Vector3.ZERO)
	_bus.player.announce_armor_changed(70, 100, -30)
	_bus.player.announce_player_destroyed(Vector3.ZERO, DestroyCause.Cause.SHOT)
	_bus.boss.announce_boss_defeated(&"albatross", Vector3.ZERO)
	var _no_shake: GdUnitAssert = assert_array(_trauma).is_empty()
	var _no_kick: GdUnitAssert = assert_array(_kicks).is_empty()
	var _no_punch: GdUnitAssert = assert_array(_punches).is_empty()
	var _no_hitstop: GdUnitAssert = assert_float(_time.time_scale()).is_not_equal(
		TimeScaleDirector.HITSTOP_SCALE
	)


func test_reduced_motion_cancels_a_running_hitstop() -> void:
	_bus.enemy.announce_enemy_destroyed(
		1, EnemyKind.Kind.FIGHTER, Vector3.ZERO, DestroyCause.Cause.SHOT
	)
	var frozen: float = _time.time_scale()
	_bus.profile.announce_settings_changed(_settings(true, true))
	var _frozen: GdUnitAssert = assert_float(frozen).is_equal(TimeScaleDirector.HITSTOP_SCALE)
	var _released: GdUnitAssert = assert_float(_time.time_scale()).is_equal(1.0)


func test_shake_toggle_turns_off_camera_motion_but_keeps_hitstop() -> void:
	_bus.profile.announce_settings_changed(_settings(false, false))
	_bus.player.announce_player_fired(Vector3.ZERO, Vector3.RIGHT)
	_bus.run.announce_kill_scored(100, 1, Vector3.ZERO)
	_bus.enemy.announce_enemy_destroyed(
		1, EnemyKind.Kind.FIGHTER, Vector3.ZERO, DestroyCause.Cause.SHOT
	)
	var _no_shake: GdUnitAssert = assert_array(_trauma).is_empty()
	var _no_kick: GdUnitAssert = assert_array(_kicks).is_empty()
	var _hitstop: GdUnitAssert = assert_float(_time.time_scale()).is_equal(
		TimeScaleDirector.HITSTOP_SCALE
	)


func test_shot_kicks_the_camera_against_the_aim() -> void:
	_bus.player.announce_player_fired(Vector3.ZERO, Vector3.RIGHT)
	var _one_kick: GdUnitAssert = assert_array(_kicks).has_size(1)
	var _backwards: GdUnitAssert = assert_float(_kicks[0].x).is_less(0.0)
	var _small: GdUnitAssert = assert_float(_kicks[0].length()).is_equal_approx(
		CameraJuice.SHOT_KICK, 0.0001
	)


func test_hits_deaths_and_boss_kills_shake_and_punch() -> void:
	_bus.player.announce_armor_changed(100, 100, 30)
	var healed: int = _trauma.size()
	_bus.player.announce_armor_changed(70, 100, -30)
	_bus.player.announce_player_destroyed(Vector3.ZERO, DestroyCause.Cause.SHOT)
	_bus.boss.announce_boss_defeated(&"albatross", Vector3.ZERO)
	var _repair_is_calm: GdUnitAssert = assert_int(healed).is_equal(0)
	var _three: GdUnitAssert = assert_array(_trauma).contains_exactly(
		[CameraJuice.HIT_TRAUMA, CameraJuice.DEATH_TRAUMA, CameraJuice.BOSS_DEFEAT_TRAUMA]
	)
	var _punched: GdUnitAssert = assert_array(_punches).has_size(3)
