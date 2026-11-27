extends GdUnitTestSuite
## Music (#26, #73): our own chiptune title, level and boss loops and the two
## stings, rendered at startup, and the director that picks and crossfades
## them with the Game State (the boss loop on the Boss Warning).

const STEP: float = 1.0 / 60.0
const STAND_IN_FRAMES: int = 2205
## Rendering every song must stay well inside this on a CI runner (ms). A
## desktop takes a few hundred; the web build renders in the background.
const RENDER_BUDGET_MS: int = 4000

var _bus: EventBus
var _library: MusicLibrary
var _music: MusicDirector


func before_test() -> void:
	_bus = EventBus.new()
	_library = MusicLibrary.new()
	add_child(_library)
	_music = MusicDirector.new()
	add_child(_music)
	_music.bind(_bus, _library)


func after_test() -> void:
	_music.free()
	_library.free()
	_bus.free()


func _stand_ins() -> void:
	for value: int in SongBook.Track.values():
		var samples: PackedFloat32Array = PackedFloat32Array()
		var _sized: int = samples.resize(STAND_IN_FRAMES)
		samples.fill(0.25)
		_library.provide(value as SongBook.Track, Pcm.to_wav(samples, true))


func _advance(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_music.advance(STEP)
		left -= STEP


func _state(from: GameState.Phase, to: GameState.Phase) -> void:
	_bus.flow.announce_game_state_changed(from, to)


func _playing() -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	for player: AudioStreamPlayer in _music.players():
		if player.playing:
			streams.append(player.stream)
	return streams


func test_every_song_parses_and_renders_a_seamless_loop() -> void:
	var started: int = Time.get_ticks_msec()
	for value: int in SongBook.Track.values():
		var track: SongBook.Track = value as SongBook.Track
		var errors: Array[String] = []
		var song: Song = SongBook.song(track, errors)
		var wav: AudioStreamWAV = SongRenderer.new(song, track).render_all()
		var samples: PackedFloat32Array = Pcm.samples_of(wav)
		var bars: float = float(song.steps) / float(Song.STEPS_PER_BAR)
		var _clean: GdUnitAssert = assert_array(errors).is_empty()
		var _whole_bars: GdUnitAssert = assert_float(bars).is_equal(floorf(bars))
		var _exact_length: GdUnitAssert = assert_int(samples.size()).is_equal(
			roundi(song.seconds() * Pcm.MIX_RATE)
		)
		var _audible: GdUnitAssert = assert_float(Pcm.peak(samples)).is_greater(0.2)
		var _in_range: GdUnitAssert = assert_float(Pcm.peak(samples)).is_less_equal(1.0)
		var looping: bool = wav.loop_mode == AudioStreamWAV.LOOP_FORWARD
		var _loops_as_asked: GdUnitAssert = assert_bool(looping).is_equal(song.loops)
		if song.loops:
			var _whole_loop: GdUnitAssert = assert_int(wav.loop_end).is_equal(samples.size())
	var elapsed: int = Time.get_ticks_msec() - started
	var _fast_enough: GdUnitAssert = assert_int(elapsed).is_less(RENDER_BUDGET_MS)


func test_loops_are_long_enough_not_to_drone() -> void:
	for track: SongBook.Track in [SongBook.Track.TITLE, SongBook.Track.LEVEL, SongBook.Track.BOSS]:
		var errors: Array[String] = []
		var song: Song = SongBook.song(track, errors)
		var _bars: GdUnitAssert = assert_int(song.steps).is_greater_equal(8 * Song.STEPS_PER_BAR)
		var _loops: GdUnitAssert = assert_bool(song.loops).is_true()
		var _four_parts: GdUnitAssert = assert_int(song.channels.size()).is_equal(4)


func test_bad_song_data_is_reported() -> void:
	var errors: Array[String] = []
	var song: Song = Song.new("Broken", 120.0, 1, true)
	song.add_melodic(Song.Instrument.LEAD, 0.2, "- H9 C4 . . . . . . . . . . . .", errors)
	song.add_drums(0.3, "k x . . . . . . . . . . . . . .", errors)
	var _three: GdUnitAssert = assert_array(errors).has_size(4)
	var _midi: GdUnitAssert = assert_int(Song.midi_of("A4")).is_equal(69)
	var _sharp: GdUnitAssert = assert_int(Song.midi_of("C#5")).is_equal(73)
	var _flat: GdUnitAssert = assert_int(Song.midi_of("Bb3")).is_equal(58)


func test_the_library_renders_title_first_in_small_slices() -> void:
	var arrived: Array[SongBook.Track] = []
	var record: Callable = func(track: SongBook.Track) -> void: arrived.append(track)
	var _a: int = _library.track_ready.connect(record)
	_library.render_for(0)
	var after_one_slice: int = arrived.size()
	_library.render_all()
	var _sliced: GdUnitAssert = assert_int(after_one_slice).is_equal(0)
	var _order: GdUnitAssert = assert_array(arrived).contains_exactly(MusicLibrary.ORDER)
	var _done: GdUnitAssert = assert_bool(_library.is_done()).is_true()


func test_music_crossfades_on_boss_warning() -> void:
	_stand_ins()
	_music.unlock()
	_state(GameState.Phase.LEVEL_INTRO, GameState.Phase.SKIRMISH)
	_advance(1.0)
	var level: AudioStream = _library.track_stream(SongBook.Track.LEVEL)
	var boss: AudioStream = _library.track_stream(SongBook.Track.BOSS)
	var before_warning: Array[AudioStream] = _playing()
	_bus.boss.announce_boss_warning_started("Albatross", 3.0)
	_state(GameState.Phase.SKIRMISH, GameState.Phase.BOSS_WARNING)
	_advance(MusicDirector.CROSSFADE_SECONDS * 0.5)
	var midway: Array[AudioStream] = _playing()
	var rising: float = _music.live_gain()
	var falling: float = _music.fading_gain()
	_advance(MusicDirector.CROSSFADE_SECONDS * 0.5 + STEP * 2.0)
	var _level_loop: GdUnitAssert = assert_array(before_warning).contains_exactly([level])
	var _both_midway: GdUnitAssert = assert_array(midway).contains_exactly_in_any_order(
		[level, boss]
	)
	var _rising: GdUnitAssert = assert_float(rising).is_between(0.3, 0.7)
	var _falling: GdUnitAssert = assert_float(falling).is_between(0.3, 0.7)
	var _boss_only: GdUnitAssert = assert_array(_playing()).contains_exactly([boss])
	var _full: GdUnitAssert = assert_float(_music.live_gain()).is_equal(1.0)
	var _track: GdUnitAssert = assert_int(_music.current_track()).is_equal(SongBook.Track.BOSS)


func test_title_and_level_loops_follow_the_game_state() -> void:
	_stand_ins()
	_music.unlock()
	_state(GameState.Phase.BOOT, GameState.Phase.TITLE)
	var on_title: int = _music.current_track()
	_state(GameState.Phase.TITLE, GameState.Phase.LEVEL_INTRO)
	var in_play: int = _music.current_track()
	_state(GameState.Phase.LEVEL_INTRO, GameState.Phase.PAUSED)
	var paused: int = _music.current_track()
	_state(GameState.Phase.PAUSED, GameState.Phase.TITLE)
	var back_on_title: int = _music.current_track()
	_state(GameState.Phase.TITLE, GameState.Phase.LEVEL_INTRO)
	_state(GameState.Phase.LEVEL_INTRO, GameState.Phase.GAME_OVER)
	_state(GameState.Phase.GAME_OVER, GameState.Phase.SCOREBOARD)
	var on_scoreboard: int = _music.current_track()
	var _title_again: GdUnitAssert = assert_int(back_on_title).is_equal(SongBook.Track.TITLE)
	var _scoreboard: GdUnitAssert = assert_int(on_scoreboard).is_equal(SongBook.Track.TITLE)
	var _title: GdUnitAssert = assert_int(on_title).is_equal(SongBook.Track.TITLE)
	var _level: GdUnitAssert = assert_int(in_play).is_equal(SongBook.Track.LEVEL)
	var _pause_keeps_it: GdUnitAssert = assert_int(paused).is_equal(SongBook.Track.LEVEL)


func test_level_clear_fades_the_loop_and_plays_the_sting() -> void:
	_stand_ins()
	_music.unlock()
	_state(GameState.Phase.BOSS_WARNING, GameState.Phase.BOSS_FIGHT)
	_advance(MusicDirector.CROSSFADE_SECONDS + STEP)
	_bus.run.announce_level_cleared(LevelTally.new(1, 10, 40, 20, 5000, 10000))
	_state(GameState.Phase.BOSS_FIGHT, GameState.Phase.LEVEL_CLEAR)
	_advance(MusicDirector.FADE_SECONDS + STEP * 2.0)
	var sting: AudioStream = _library.track_stream(SongBook.Track.LEVEL_CLEAR)
	var _sting_only: GdUnitAssert = assert_array(_playing()).contains_exactly([sting])
	var _no_loop: GdUnitAssert = assert_int(_music.current_track()).is_equal(MusicDirector.NONE)


func test_game_over_plays_its_sting() -> void:
	_stand_ins()
	_music.unlock()
	_state(GameState.Phase.LEVEL_INTRO, GameState.Phase.SKIRMISH)
	_state(GameState.Phase.SKIRMISH, GameState.Phase.GAME_OVER)
	_advance(MusicDirector.FADE_SECONDS + STEP * 2.0)
	var sting: AudioStream = _library.track_stream(SongBook.Track.GAME_OVER)
	var _sting_only: GdUnitAssert = assert_array(_playing()).contains_exactly([sting])


func test_music_waits_for_the_unlock_and_its_render() -> void:
	_state(GameState.Phase.BOOT, GameState.Phase.TITLE)
	var locked: Array[AudioStream] = _playing()
	_music.unlock()
	var unrendered: Array[AudioStream] = _playing()
	_library.render_for(MusicLibrary.FRAME_BUDGET_USEC * 1000)
	var _silent_locked: GdUnitAssert = assert_array(locked).is_empty()
	var _silent_unrendered: GdUnitAssert = assert_array(unrendered).is_empty()
	var _title_starts: GdUnitAssert = assert_array(_playing()).contains_exactly(
		[_library.track_stream(SongBook.Track.TITLE)]
	)
