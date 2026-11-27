class_name Pcm
extends RefCounted
## Turns synthesized samples into a playable AudioStreamWAV (16-bit mono), so
## every sound and song is made in memory at startup and no audio file ships.

## The mix rate of every synthesized sound (Hz).
const MIX_RATE: int = 22050
const FULL_SCALE: float = 32767.0


## A 16-bit mono stream of `samples` (each clamped to -1..1). A looping stream
## loops over all of it, so its length must be a whole number of bars.
static func to_wav(samples: PackedFloat32Array, loops: bool) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	var _sized: int = data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, roundi(clampf(samples[i], -1.0, 1.0) * FULL_SCALE))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	if loops:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## The largest absolute sample in `samples`.
static func peak(samples: PackedFloat32Array) -> float:
	var top: float = 0.0
	for s: float in samples:
		top = maxf(top, absf(s))
	return top


## The 16-bit samples of `wav` back as floats (-1..1), for tests and checks.
static func samples_of(wav: AudioStreamWAV) -> PackedFloat32Array:
	var data: PackedByteArray = wav.data
	var out: PackedFloat32Array = PackedFloat32Array()
	var _sized: int = out.resize(data.size() >> 1)
	for i: int in out.size():
		out[i] = float(data.decode_s16(i * 2)) / FULL_SCALE
	return out
