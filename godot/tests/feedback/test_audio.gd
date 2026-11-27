extends GdUnitTestSuite
## Audio (#26, #73): the four buses and their Settings volumes, the unlock gate
## that keeps every sound silent until the first user gesture, the sound
## effects, the low-Armor warning and the boss siren.

const STEP: float = 1.0 / 60.0
const STAND_IN_FRAMES: int = 2205

var _bus: EventBus
var _rig: FeedbackRig


func before_test() -> void:
	_bus = EventBus.new()
	_rig = FeedbackRig.new()
	add_child(_rig)
	_rig.bind(_bus)
	for value: int in SongBook.Track.values():
		_rig.library.provide(value as SongBook.Track, _tone())


func after_test() -> void:
	_rig.free()
	_bus.free()


## A short looping stand-in for a song (the songs themselves: test_music.gd).
static func _tone() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var _sized: int = samples.resize(STAND_IN_FRAMES)
	samples.fill(0.25)
	return Pcm.to_wav(samples, true)


func _press_key() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	_rig.unlock.handle_input(key)


func _volumes(master: float, music: float, sfx: float) -> GameSettings:
	var settings: GameSettings = GameSettings.new()
	settings.master_volume = master
	settings.music_volume = music
	settings.sfx_volume = sfx
	return settings


func _advance_sfx(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_rig.sfx.advance(STEP)
		left -= STEP


func test_bus_layout_has_master_music_sfx_and_ui() -> void:
	var names: Array[StringName] = []
	for i: int in AudioServer.bus_count:
		names.append(AudioServer.get_bus_name(i))
	var _four: GdUnitAssert = assert_array(names).contains_exactly(
		[AudioBuses.MASTER, AudioBuses.MUSIC, AudioBuses.SFX, AudioBuses.UI]
	)
	for bus_name: StringName in [AudioBuses.MUSIC, AudioBuses.SFX, AudioBuses.UI]:
		var index: int = AudioServer.get_bus_index(bus_name)
		var _sends: GdUnitAssert = assert_str(AudioServer.get_bus_send(index)).is_equal(
			AudioBuses.MASTER
		)


func test_bus_volumes_follow_settings() -> void:
	_bus.profile.announce_settings_changed(_volumes(0.5, 0.25, 1.0))
	var master: float = AudioBuses.volume_of(AudioBuses.MASTER)
	var music: float = AudioBuses.volume_of(AudioBuses.MUSIC)
	var sfx: float = AudioBuses.volume_of(AudioBuses.SFX)
	var ui: float = AudioBuses.volume_of(AudioBuses.UI)
	_bus.profile.announce_settings_changed(_volumes(1.0, 0.0, 0.6))
	var muted_music: float = AudioBuses.volume_of(AudioBuses.MUSIC)
	var music_index: int = AudioServer.get_bus_index(AudioBuses.MUSIC)
	var muted: bool = AudioServer.is_bus_mute(music_index)
	var ui_after: float = AudioBuses.volume_of(AudioBuses.UI)
	_bus.profile.announce_settings_changed(_volumes(1.0, 1.0, 1.0))
	var _master: GdUnitAssert = assert_float(master).is_equal_approx(0.5, 0.001)
	var _music: GdUnitAssert = assert_float(music).is_equal_approx(0.25, 0.001)
	var _sfx: GdUnitAssert = assert_float(sfx).is_equal_approx(1.0, 0.001)
	var _ui: GdUnitAssert = assert_float(ui).is_equal_approx(1.0, 0.001)
	var _zero: GdUnitAssert = assert_float(muted_music).is_equal(0.0)
	var _mutes: GdUnitAssert = assert_bool(muted).is_true()
	var _ui_follows_sfx: GdUnitAssert = assert_float(ui_after).is_equal_approx(0.6, 0.001)


func test_nothing_plays_before_audio_unlock() -> void:
	_bus.flow.announce_game_state_changed(GameState.Phase.BOOT, GameState.Phase.TITLE)
	_bus.flow.announce_game_state_changed(GameState.Phase.TITLE, GameState.Phase.SKIRMISH)
	_bus.player.announce_player_fired(Vector3.ZERO, Vector3.RIGHT)
	_bus.enemy.announce_enemy_destroyed(
		1, EnemyKind.Kind.FIGHTER, Vector3.ZERO, DestroyCause.Cause.SHOT
	)
	_bus.run.announce_kill_scored(100, 1, Vector3.ZERO)
	_bus.player.announce_armor_changed(20, 100, -30)
	_bus.boss.announce_boss_warning_started("Albatross", 3.0)
	_advance_sfx(2.0)
	_rig.explosions.advance(1.0)
	var locked_count: int = _rig.playing_count()
	var silent_cues: Array[SfxBank.Cue] = _rig.sfx.take_played()
	_press_key()
	_bus.player.announce_player_fired(Vector3.ZERO, Vector3.RIGHT)
	var _silent: GdUnitAssert = assert_int(locked_count).is_equal(0)
	var _nothing_queued: GdUnitAssert = assert_array(silent_cues).is_empty()
	var _music_starts: GdUnitAssert = assert_int(_rig.music.current_track()).is_equal(
		SongBook.Track.BOSS
	)
	var _sounds_now: GdUnitAssert = assert_int(_rig.playing_count()).is_greater_equal(2)


func test_audio_unlocks_on_the_first_gesture_only() -> void:
	var gate: AudioUnlock = _rig.unlock
	gate.assume_web(true)
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	gate.handle_input(pad)
	var after_pad_on_web: bool = gate.is_unlocked()
	var release: InputEventKey = InputEventKey.new()
	release.pressed = false
	gate.handle_input(release)
	var after_release: bool = gate.is_unlocked()
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	gate.handle_input(touch)
	var _pad_is_no_gesture_on_web: GdUnitAssert = assert_bool(after_pad_on_web).is_false()
	var _release_is_no_gesture: GdUnitAssert = assert_bool(after_release).is_false()
	var _touch_unlocks: GdUnitAssert = assert_bool(gate.is_unlocked()).is_true()
	var _pad_counts_off_web: GdUnitAssert = (
		assert_bool(AudioUnlock.is_gesture(pad, false)).is_true()
	)


func test_boot_start_request_unlocks_audio() -> void:
	_bus.flow.announce_start_requested()
	var _open: GdUnitAssert = assert_bool(_rig.unlock.is_unlocked()).is_true()


func test_every_action_has_a_sound() -> void:
	_press_key()
	_bus.player.announce_player_fired(Vector3.ZERO, Vector3.RIGHT)
	_bus.enemy.announce_enemy_hit(1, Vector3.ZERO)
	_bus.enemy.announce_enemy_destroyed(
		1, EnemyKind.Kind.FIGHTER, Vector3.ZERO, DestroyCause.Cause.SHOT
	)
	_bus.run.announce_kill_scored(100, 1, Vector3.ZERO)
	_bus.player.announce_armor_changed(90, 100, -10)
	_bus.player.announce_repair_collected(Vector3.ZERO)
	_bus.player.announce_bonus_life_awarded(4)
	_bus.boss.announce_boss_hit(3, Vector3.ZERO)
	_bus.boss.announce_boss_phase_changed(1, 2)
	_bus.run.announce_level_intro_started(1, "Dawn Patrol", "Fill the Boss Gauge", 2.5)
	_bus.flow.announce_ui_cue_requested(UiCue.Cue.BACK)
	_bus.flow.announce_ui_cue_requested(UiCue.Cue.CONFIRM)
	_bus.player.announce_player_destroyed(Vector3.ZERO, DestroyCause.Cause.SHOT)
	var _all: GdUnitAssert = (
		assert_array(_rig.sfx.take_played())
		. contains_exactly_in_any_order(
			[
				SfxBank.Cue.SHOT,
				SfxBank.Cue.ENEMY_HIT,
				SfxBank.Cue.EXPLOSION,
				SfxBank.Cue.COMBO,
				SfxBank.Cue.PLAYER_HIT,
				SfxBank.Cue.REPAIR,
				SfxBank.Cue.ONE_UP,
				SfxBank.Cue.BOSS_HIT,
				SfxBank.Cue.BOSS_PHASE,
				SfxBank.Cue.LEVEL_START,
				SfxBank.Cue.UI_BACK,
				SfxBank.Cue.UI_CONFIRM,
				SfxBank.Cue.PLAYER_DESTROYED,
				SfxBank.Cue.BIG_EXPLOSION,
			]
		)
	)


func test_low_armor_warning_beeps_until_repaired() -> void:
	_press_key()
	_bus.flow.announce_game_state_changed(GameState.Phase.LEVEL_INTRO, GameState.Phase.SKIRMISH)
	_bus.player.announce_armor_changed(50, 100, -10)
	_advance_sfx(2.0)
	var healthy: Array[SfxBank.Cue] = _rig.sfx.take_played()
	_bus.player.announce_armor_changed(25, 100, -25)
	_advance_sfx(SfxDirector.LOW_ARMOR_INTERVAL * 2.5)
	var low: Array[SfxBank.Cue] = _rig.sfx.take_played()
	_bus.player.announce_armor_changed(55, 100, 30)
	_advance_sfx(2.0)
	var repaired: Array[SfxBank.Cue] = _rig.sfx.take_played()
	var _no_beeps: GdUnitAssert = assert_array(healthy).not_contains([SfxBank.Cue.LOW_ARMOR])
	var _three_beeps: GdUnitAssert = assert_int(low.count(SfxBank.Cue.LOW_ARMOR)).is_equal(3)
	var _stops: GdUnitAssert = assert_array(repaired).is_empty()


func test_low_armor_warning_rests_while_paused() -> void:
	_press_key()
	_bus.flow.announce_game_state_changed(GameState.Phase.LEVEL_INTRO, GameState.Phase.SKIRMISH)
	_bus.player.announce_armor_changed(20, 100, -30)
	_bus.flow.announce_game_state_changed(GameState.Phase.SKIRMISH, GameState.Phase.PAUSED)
	var _taken: Array[SfxBank.Cue] = _rig.sfx.take_played()
	_advance_sfx(2.0)
	var _quiet: GdUnitAssert = assert_array(_rig.sfx.take_played()).is_empty()
	var _armed: GdUnitAssert = assert_bool(_rig.sfx.low_armor_warning()).is_true()


func test_boss_warning_sounds_the_siren_throughout() -> void:
	_press_key()
	_bus.flow.announce_game_state_changed(GameState.Phase.SKIRMISH, GameState.Phase.BOSS_WARNING)
	_bus.boss.announce_boss_warning_started("Albatross", 3.0)
	_advance_sfx(4.0)
	var sirens: int = _rig.sfx.take_played().count(SfxBank.Cue.SIREN)
	var _three: GdUnitAssert = assert_int(sirens).is_equal(3)


func test_sfx_bank_renders_every_cue_audibly_and_within_range() -> void:
	var streams: Dictionary[SfxBank.Cue, AudioStreamWAV] = SfxBank.render_all()
	var again: Dictionary[SfxBank.Cue, AudioStreamWAV] = SfxBank.render_all()
	for value: int in SfxBank.Cue.values():
		var cue: SfxBank.Cue = value as SfxBank.Cue
		var samples: PackedFloat32Array = Pcm.samples_of(streams[cue])
		var peak: float = Pcm.peak(samples)
		var _audible: GdUnitAssert = assert_float(peak).is_greater(0.02)
		var _in_range: GdUnitAssert = assert_float(peak).is_less_equal(1.0)
		var _short: GdUnitAssert = assert_float(streams[cue].get_length()).is_less(2.0)
		var _repeatable: GdUnitAssert = assert_bool(streams[cue].data == again[cue].data).is_true()


func test_every_ui_cue_plays_on_the_ui_bus() -> void:
	_press_key()
	var _cleared: Array[StringName] = _rig.sfx.take_played_buses()
	for value: int in UiCue.Cue.values():
		_bus.flow.announce_ui_cue_requested(value as UiCue.Cue)
	var ui_buses: Array[StringName] = _rig.sfx.take_played_buses()
	_bus.player.announce_player_fired(Vector3.ZERO, Vector3.RIGHT)
	var shot_buses: Array[StringName] = _rig.sfx.take_played_buses()
	var _one_each: GdUnitAssert = assert_int(ui_buses.size()).is_equal(UiCue.Cue.size())
	for bus_name: StringName in ui_buses:
		var _ui_bus: GdUnitAssert = assert_str(bus_name).is_equal(AudioBuses.UI)
	var _shot_on_sfx: GdUnitAssert = assert_array(shot_buses).contains_exactly([AudioBuses.SFX])


func test_boot_start_cue_unlocks_audio_and_sounds() -> void:
	_bus.flow.announce_ui_cue_requested(UiCue.Cue.START)
	var _open: GdUnitAssert = assert_bool(_rig.unlock.is_unlocked()).is_true()
	var _sounded: GdUnitAssert = assert_array(_rig.sfx.take_played()).contains_exactly(
		[SfxBank.Cue.UI_START]
	)


func test_web_gamepad_start_does_not_unlock_audio() -> void:
	var gate: AudioUnlock = _rig.unlock
	gate.assume_web(true)
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	gate.handle_input(pad)
	_bus.flow.announce_ui_cue_requested(UiCue.Cue.START)
	_bus.flow.announce_start_requested()
	var after_pad_start: bool = gate.is_unlocked()
	var silent: Array[SfxBank.Cue] = _rig.sfx.take_played()
	_press_key()
	var _pending: GdUnitAssert = assert_bool(after_pad_start).is_false()
	var _no_start_sound: GdUnitAssert = assert_array(silent).is_empty()
	var _next_key_unlocks: GdUnitAssert = assert_bool(gate.is_unlocked()).is_true()
