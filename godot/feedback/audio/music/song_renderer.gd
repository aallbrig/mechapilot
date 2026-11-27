class_name SongRenderer
extends RefCounted
## Synthesizes a Song into an AudioStreamWAV, one note at a time, so the work
## can be spread over frames (step()) or done at once (render_all()). The
## chiptune voices: a 25% pulse lead with a late vibrato, a square harmony, a
## triangle bass, a thin 12.5% pulse arpeggio, and noise-and-sine drums. A
## looping song is exactly a whole number of bars long, so its loop is seamless.

## Melodic envelope: attack, decay to the sustain level, release (s).
const ATTACK: float = 0.004
const DECAY: float = 0.09
const SUSTAIN: float = 0.7
const RELEASE: float = 0.03
const LEAD_DUTY: float = 0.25
const HARMONY_DUTY: float = 0.5
const ARP_DUTY: float = 0.125
## The lead's vibrato: when it starts (s), its rate (Hz) and depth (ratio).
const VIBRATO_DELAY: float = 0.15
const VIBRATO_RATE: float = 5.5
const VIBRATO_DEPTH: float = 0.005
## Drums: length (s), decay rate (1/s) and, for the kick, the pitch sweep (Hz).
const KICK_SECONDS: float = 0.16
const KICK_DECAY: float = 24.0
const KICK_FROM: float = 150.0
const KICK_TO: float = 45.0
const SNARE_SECONDS: float = 0.16
const SNARE_DECAY: float = 22.0
const SNARE_TONE: float = 190.0
const HAT_SECONDS: float = 0.04
const HAT_DECAY: float = 90.0
const OPEN_HAT_SECONDS: float = 0.18
const OPEN_HAT_DECAY: float = 14.0
const NOISE_LOW_PASS: float = 0.35
## The mix's gain before it is limited to full scale.
const GAIN: float = 0.85

var _song: Song
var _rate: float = float(Pcm.MIX_RATE)
var _samples: PackedFloat32Array = PackedFloat32Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _channel: int = 0
var _note: int = 0
var _stream: AudioStreamWAV = null
## Each distinct note (instrument, pitch, length) is synthesized once, then mixed.
var _waves: Dictionary[String, PackedFloat32Array] = {}


func _init(song: Song, noise_seed: int) -> void:
	_song = song
	_rng.seed = noise_seed
	var _sized: int = _samples.resize(roundi(song.seconds() * _rate))


## Render notes until `budget_usec` microseconds have passed; true once done.
func step(budget_usec: int) -> bool:
	var started: int = Time.get_ticks_usec()
	while _stream == null:
		_render_next()
		if Time.get_ticks_usec() - started >= budget_usec:
			break
	return _stream != null


func render_all() -> AudioStreamWAV:
	while _stream == null:
		_render_next()
	return _stream


## The finished stream, or null while rendering.
func stream() -> AudioStreamWAV:
	return _stream


func _render_next() -> void:
	if _channel >= _song.channels.size():
		for i: int in _samples.size():
			_samples[i] = clampf(_samples[i] * GAIN, -1.0, 1.0)
		_stream = Pcm.to_wav(_samples, _song.loops)
		return
	var channel: Song.Channel = _song.channels[_channel]
	if _note >= channel.notes.size():
		_channel += 1
		_note = 0
		return
	var note: Song.Note = channel.notes[_note]
	_note += 1
	var key: String = "%d:%d:%d" % [channel.instrument, note.pitch, note.length]
	if not _waves.has(key):
		if channel.instrument == Song.Instrument.DRUMS:
			_waves[key] = _drum_wave(note.pitch as Song.Drum)
		else:
			_waves[key] = _tone_wave(channel.instrument, note.pitch, note.length)
	_mix(_waves[key], _sample_of(note.start), channel.volume)


## Add `wave` at `volume` into the song, from sample `first` (cut at the end).
func _mix(wave: PackedFloat32Array, first: int, volume: float) -> void:
	for n: int in mini(wave.size(), _samples.size() - first):
		_samples[first + n] += wave[n] * volume


func _sample_of(at_step: int) -> int:
	return roundi(float(at_step) * _song.step_seconds() * _rate)


## One note of `instrument`: MIDI `pitch`, `steps` long, at full volume.
func _tone_wave(instrument: Song.Instrument, pitch: int, steps: int) -> PackedFloat32Array:
	var seconds: float = float(steps) * _song.step_seconds()
	var wave: PackedFloat32Array = PackedFloat32Array()
	var _sized: int = wave.resize(_sample_of(steps))
	var hz: float = Song.hz_of(pitch)
	var duty: float = _duty(instrument)
	var dt: float = 1.0 / _rate
	var phase: float = 0.0
	for n: int in wave.size():
		var t: float = float(n) * dt
		var bend: float = 1.0
		if instrument == Song.Instrument.LEAD and t > VIBRATO_DELAY:
			bend += VIBRATO_DEPTH * sin(TAU * VIBRATO_RATE * (t - VIBRATO_DELAY))
		phase += hz * bend * dt
		if phase >= 1.0:
			phase -= 1.0
		var value: float
		if instrument == Song.Instrument.BASS:
			value = 4.0 * absf(phase - 0.5) - 1.0
		else:
			value = 1.0 if phase < duty else -1.0
		wave[n] = value * _envelope(t, seconds)
	return wave


## One hit of `drum` at full volume.
func _drum_wave(drum: Song.Drum) -> PackedFloat32Array:
	var seconds: float = HAT_SECONDS
	var decay: float = HAT_DECAY
	match drum:
		Song.Drum.KICK:
			seconds = KICK_SECONDS
			decay = KICK_DECAY
		Song.Drum.SNARE:
			seconds = SNARE_SECONDS
			decay = SNARE_DECAY
		Song.Drum.OPEN_HAT:
			seconds = OPEN_HAT_SECONDS
			decay = OPEN_HAT_DECAY
		Song.Drum.HAT:
			pass
	var wave: PackedFloat32Array = PackedFloat32Array()
	var _sized: int = wave.resize(roundi(seconds * _rate))
	var dt: float = 1.0 / _rate
	var phase: float = 0.0
	var low: float = 0.0
	for n: int in wave.size():
		var t: float = float(n) * dt
		var env: float = exp(-decay * t) * minf(1.0, (seconds - t) / RELEASE)
		var white: float = _rng.randf_range(-1.0, 1.0)
		low += (white - low) * NOISE_LOW_PASS
		var value: float
		if drum == Song.Drum.KICK:
			var hz: float = KICK_TO + (KICK_FROM - KICK_TO) * exp(-decay * t)
			phase = fmod(phase + hz * dt, 1.0)
			value = sin(TAU * phase)
		elif drum == Song.Drum.SNARE:
			phase = fmod(phase + SNARE_TONE * dt, 1.0)
			value = 0.7 * low + 0.3 * sin(TAU * phase)
		else:
			value = white - low
		wave[n] = value * env
	return wave


static func _duty(instrument: Song.Instrument) -> float:
	if instrument == Song.Instrument.LEAD:
		return LEAD_DUTY
	if instrument == Song.Instrument.ARP:
		return ARP_DUTY
	return HARMONY_DUTY


static func _envelope(t: float, seconds: float) -> float:
	var level: float = SUSTAIN + (1.0 - SUSTAIN) * maxf(0.0, 1.0 - t / DECAY)
	return level * minf(1.0, t / ATTACK) * clampf((seconds - t) / RELEASE, 0.0, 1.0)
