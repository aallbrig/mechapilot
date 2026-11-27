extends GdUnitTestSuite
## Every UI cue has a sound (#73: every UI element has sound), and the master
## and SFX volumes apply until the audio pass adds a UI bus.

var _bus: EventBus
var _player: UiSoundPlayer


func before_test() -> void:
	_bus = EventBus.new()
	_player = UiSoundPlayer.new()
	_player.use_bus(_bus)
	add_child(_player)


func after_test() -> void:
	_player.free()
	_bus.free()


func test_every_ui_cue_plays_a_sound() -> void:
	var silent: Array[String] = []
	for cue: int in UiCue.Cue.size():
		_bus.flow.announce_ui_cue_requested(cue as UiCue.Cue)
		if not UiSoundPlayer.TONES.has(cue as UiCue.Cue):
			silent.append(UiCue.Cue.keys()[cue])
	var tone: AudioStreamWAV = UiSoundPlayer.tone(UiSoundPlayer.TONES[UiCue.Cue.CONFIRM])
	var _all: GdUnitAssert = assert_array(silent).is_empty()
	var _played: GdUnitAssert = assert_int(_player.played().size()).is_equal(UiCue.Cue.size())
	var _audible: GdUnitAssert = assert_int(tone.data.size()).is_greater(0)


func test_ui_sound_volume_follows_settings() -> void:
	var muted: GameSettings = GameSettings.new()
	muted.sfx_volume = 0.0
	_bus.profile.announce_settings_changed(muted)
	_bus.flow.announce_ui_cue_requested(UiCue.Cue.CONFIRM)
	var muted_db: float = _player.volume_db()
	_bus.profile.announce_settings_changed(GameSettings.new())
	_bus.flow.announce_ui_cue_requested(UiCue.Cue.CONFIRM)
	var default_db: float = _player.volume_db()
	var expected: float = linear_to_db(GameSettings.DEFAULT_VOLUME * GameSettings.DEFAULT_VOLUME)
	var _muted: GdUnitAssert = assert_float(muted_db).is_less_equal(UiSoundPlayer.SILENT_DB)
	var _default: GdUnitAssert = assert_float(default_db).is_equal_approx(expected, 0.01)
