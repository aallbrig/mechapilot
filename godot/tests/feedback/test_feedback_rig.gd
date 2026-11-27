extends GdUnitTestSuite
## The whole feedback rig on one bus (#26): the boss defeat sequence and the
## player's death, each a set of effects that only react to Game Events.

const STEP: float = 1.0 / 60.0
const STAND_IN_FRAMES: int = 2205

var _bus: EventBus
var _rig: FeedbackRig
var _trauma: Array[float] = []
var _rumbles: int = 0


func before_test() -> void:
	_trauma.clear()
	_rumbles = 0
	_bus = EventBus.new()
	_rig = FeedbackRig.new()
	add_child(_rig)
	_rig.bind(_bus)
	for value: int in SongBook.Track.values():
		var samples: PackedFloat32Array = PackedFloat32Array()
		var _sized: int = samples.resize(STAND_IN_FRAMES)
		samples.fill(0.25)
		_rig.library.provide(value as SongBook.Track, Pcm.to_wav(samples, true))
	var _a: int = _rig.camera.trauma_requested.connect(_on_trauma)
	var _b: int = _rig.rumble.rumbled.connect(_on_rumbled)
	_bus.flow.announce_start_requested()


func after_test() -> void:
	_rig.free()
	_bus.free()


func _on_trauma(amount: float) -> void:
	_trauma.append(amount)


func _on_rumbled(_weak: float, _strong: float, _seconds: float) -> void:
	_rumbles += 1


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_rig.time.advance(STEP)
		_rig.explosions.advance(STEP)
		_rig.overlay.advance(STEP)
		_rig.sfx.advance(STEP)
		_rig.music.advance(STEP)
		left -= STEP


func test_boss_defeat_sequence_chains_blasts_slows_time_and_plays_the_sting() -> void:
	_bus.flow.announce_game_state_changed(GameState.Phase.BOSS_WARNING, GameState.Phase.BOSS_FIGHT)
	_advance(MusicDirector.CROSSFADE_SECONDS)
	var _cleared: Array[SfxBank.Cue] = _rig.sfx.take_played()
	_bus.boss.announce_boss_defeated(&"albatross", Vector3(4.0, 3.0, 0.0))
	_bus.run.announce_level_cleared(LevelTally.new(1, 10, 40, 20, 5000, 10000))
	_bus.flow.announce_game_state_changed(GameState.Phase.BOSS_FIGHT, GameState.Phase.LEVEL_CLEAR)
	var slowed: float = _rig.time.time_scale()
	_advance(ExplosionPool.CHAIN_SECONDS + STEP * 2.0)
	var booms: Array[SfxBank.Cue] = _rig.sfx.take_played()
	var sting: AudioStream = _rig.library.track_stream(SongBook.Track.LEVEL_CLEAR)
	var _slow_mo: GdUnitAssert = assert_float(slowed).is_less(1.0)
	var _big_shake: GdUnitAssert = assert_array(_trauma).contains([CameraJuice.BOSS_DEFEAT_TRAUMA])
	var _rumble: GdUnitAssert = assert_int(_rumbles).is_equal(1)
	var _chain: GdUnitAssert = assert_int(booms.size()).is_equal(ExplosionPool.CHAIN_COUNT + 1)
	var _biggest_last: GdUnitAssert = assert_int(booms.back()).is_equal(SfxBank.Cue.BIG_EXPLOSION)
	var _sting: GdUnitAssert = assert_bool(_rig.music.players()[2].playing).is_true()
	var _sting_stream: GdUnitAssert = assert_object(_rig.music.players()[2].stream).is_same(sting)
	_advance(TimeScaleDirector.BOSS_SLOWMO_SECONDS)
	var _time_back: GdUnitAssert = assert_float(_rig.time.time_scale()).is_equal(1.0)


func test_player_destroyed_slows_time_shakes_hard_and_desaturates() -> void:
	_bus.flow.announce_game_state_changed(GameState.Phase.LEVEL_INTRO, GameState.Phase.SKIRMISH)
	_bus.player.announce_player_destroyed(Vector3.ZERO, DestroyCause.Cause.SHOT)
	var slowed: float = _rig.time.time_scale()
	_advance(TimeScaleDirector.DEATH_SLOWMO_SECONDS + STEP)
	var _slow_mo: GdUnitAssert = assert_float(slowed).is_less(1.0)
	var _big_shake: GdUnitAssert = assert_array(_trauma).contains([CameraJuice.DEATH_TRAUMA])
	var _grey: GdUnitAssert = assert_float(_rig.overlay.desaturation()).is_equal(1.0)
	var _restored: GdUnitAssert = assert_float(_rig.time.time_scale()).is_equal(1.0)
	var _blast: GdUnitAssert = assert_int(_rig.explosions.active_count()).is_equal(1)
