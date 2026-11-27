class_name SfxSynth
extends RefCounted
## Renders a sound effect from its SynthVoice layers into an AudioStreamWAV.
## The noise comes from a seeded generator, so a sound renders the same way
## every time.

## Attack and release ramps (s), so no layer clicks at its edges.
const ATTACK: float = 0.002
const RELEASE: float = 0.01
## The whole sound's gain before it is limited to full scale.
const GAIN: float = 0.9


## Render `voices` mixed together, the noise seeded with `noise_seed`.
static func render(voices: Array[SynthVoice], noise_seed: int) -> AudioStreamWAV:
	var rate: float = float(Pcm.MIX_RATE)
	var length: float = 0.0
	for voice: SynthVoice in voices:
		length = maxf(length, voice.end_time())
	var samples: PackedFloat32Array = PackedFloat32Array()
	var _sized: int = samples.resize(ceili(length * rate) + 1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = noise_seed
	for voice: SynthVoice in voices:
		_mix(samples, voice, rng, rate)
	for i: int in samples.size():
		samples[i] = clampf(samples[i] * GAIN, -1.0, 1.0)
	return Pcm.to_wav(samples, false)


static func _mix(
	samples: PackedFloat32Array, voice: SynthVoice, rng: RandomNumberGenerator, rate: float
) -> void:
	var first: int = floori(voice.delay * rate)
	var count: int = floori(voice.duration * rate)
	var dt: float = 1.0 / rate
	var ratio: float = voice.freq_end / maxf(voice.freq_start, 1.0)
	var phase: float = 0.0
	var low: float = 0.0
	for n: int in count:
		var index: int = first + n
		if index >= samples.size():
			return
		var t: float = float(n) * dt
		var k: float = t / voice.duration
		var env: float = 1.0 if voice.flat else (1.0 - k) * (1.0 - k)
		env *= minf(1.0, t / ATTACK) * minf(1.0, (voice.duration - t) / RELEASE)
		var freq: float = voice.freq_start * pow(ratio, k)
		phase = fmod(phase + freq * dt, 1.0)
		var wave: float = 1.0 if phase < voice.duty else -1.0
		low += (rng.randf_range(-1.0, 1.0) - low) * voice.cutoff
		samples[index] += (wave * voice.square + low * voice.noise) * env * voice.volume
