class_name UiSoundPlayer
extends Node
## Plays a short synthesized blip for every UI cue (flow.ui_cue_requested), so
## every screen element has sound without shipping audio files. The audio
## pass (#26) can swap the tones for recorded ones behind the same cue.
##
## It plays on the "UI" bus when one exists (the audio pass owns the buses and
## their volumes); until then it plays on Master and applies the master and
## SFX volumes from profile.settings_changed itself.

const MIX_RATE: int = 22050
const UI_BUS: StringName = &"UI"
const FALLBACK_BUS: StringName = &"Master"
const POLYPHONY: int = 4
const SAMPLE_MAX: float = 32767.0
const ATTACK_SHARE: float = 0.08
const SILENT_DB: float = -80.0
const HISTORY: int = 64

## Tone per cue: start Hz, end Hz, seconds, loudness 0..1, square wave.
const TONES: Dictionary[UiCue.Cue, Array] = {
	UiCue.Cue.FOCUS: [880.0, 990.0, 0.04, 0.25, false],
	UiCue.Cue.CONFIRM: [660.0, 1320.0, 0.09, 0.45, true],
	UiCue.Cue.BACK: [660.0, 330.0, 0.09, 0.4, true],
	UiCue.Cue.TOGGLE: [740.0, 980.0, 0.06, 0.35, true],
	UiCue.Cue.SLIDE: [520.0, 560.0, 0.03, 0.2, false],
	UiCue.Cue.LETTER: [990.0, 1180.0, 0.05, 0.35, true],
	UiCue.Cue.TICK: [1400.0, 1400.0, 0.025, 0.25, true],
	UiCue.Cue.TALLY_DONE: [520.0, 1560.0, 0.25, 0.5, true],
	UiCue.Cue.POP: [400.0, 1200.0, 0.18, 0.5, false],
	UiCue.Cue.WARNING: [440.0, 220.0, 0.5, 0.6, true],
	UiCue.Cue.START: [330.0, 990.0, 0.3, 0.55, true],
}

var _bus: EventBus
var _players: Dictionary[UiCue.Cue, AudioStreamPlayer] = {}
var _volume_db: float = 0.0
var _played: Array[UiCue.Cue] = []


## Use `bus` instead of the Events autoload. Call before adding to the tree.
func use_bus(bus: EventBus) -> void:
	_bus = bus


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _bus == null:
		_bus = Events
	var bus_name: StringName = UI_BUS if AudioServer.get_bus_index(UI_BUS) >= 0 else FALLBACK_BUS
	for cue: UiCue.Cue in TONES:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = tone(TONES[cue])
		player.bus = bus_name
		player.max_polyphony = POLYPHONY
		add_child(player)
		_players[cue] = player
	var results: Array[int] = [
		_bus.flow.ui_cue_requested.connect(_on_ui_cue_requested),
		_bus.profile.settings_changed.connect(_on_settings_changed),
	]
	for result: int in results:
		if result != OK:
			push_error("UiSoundPlayer: could not subscribe: %s" % error_string(result))


## The cues played most recently, oldest first (for tests).
func played() -> Array[UiCue.Cue]:
	return _played.duplicate()


## The volume the cues play at, in dB.
func volume_db() -> float:
	return _volume_db


## A short tone: [start Hz, end Hz, seconds, loudness, square].
static func tone(spec: Array) -> AudioStreamWAV:
	var start_hz: float = spec[0]
	var end_hz: float = spec[1]
	var seconds: float = spec[2]
	var loudness: float = spec[3]
	var square: bool = spec[4]
	var count: int = maxi(roundi(seconds * MIX_RATE), 1)
	var data: PackedByteArray = PackedByteArray()
	var _sized: int = data.resize(count * 2)
	var phase: float = 0.0
	for i: int in count:
		var t: float = float(i) / count
		phase += TAU * lerpf(start_hz, end_hz, t) / MIX_RATE
		var wave: float = sin(phase)
		if square:
			wave = signf(wave) * 0.5
		var envelope: float = minf(t / ATTACK_SHARE, 1.0) * (1.0 - t)
		data.encode_s16(i * 2, roundi(wave * envelope * loudness * SAMPLE_MAX))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _on_ui_cue_requested(cue: UiCue.Cue) -> void:
	if not _players.has(cue):
		return
	_played.append(cue)
	if _played.size() > HISTORY:
		var _dropped: UiCue.Cue = _played.pop_front()
	var player: AudioStreamPlayer = _players[cue]
	player.volume_db = _volume_db
	player.play()


func _on_settings_changed(settings: GameSettings) -> void:
	if player_bus_is_ui():
		_volume_db = 0.0
		return
	var linear: float = settings.master_volume * settings.sfx_volume
	_volume_db = linear_to_db(linear) if linear > 0.0 else SILENT_DB


## True when the sounds play on the audio pass's UI bus.
func player_bus_is_ui() -> bool:
	return AudioServer.get_bus_index(UI_BUS) >= 0
