class_name SynthVoice
extends RefCounted
## One layer of a sound effect, ported from the LAN prototype's voice mixer: a
## square wave sweeping from `freq_start` to `freq_end` plus low-passed noise,
## under a decaying envelope (or a flat one, for sirens). Built with tone() and
## the chainable with_*() and after() calls.

## Seconds from the start of the sound to this layer's start, and its length.
var delay: float = 0.0
var duration: float = 0.1
## The square wave's pitch sweep (Hz, exponential).
var freq_start: float = 440.0
var freq_end: float = 440.0
## Mix of the square wave and the noise (0..1 each), and the layer's volume.
var square: float = 1.0
var noise: float = 0.0
var volume: float = 0.2
## The noise's low-pass coefficient (0..1; lower is darker).
var cutoff: float = 0.5
## The square wave's duty cycle (0..1).
var duty: float = 0.5
## A flat envelope (attack and release only) instead of the decay.
var flat: bool = false


## A square tone of `seconds`, sweeping `from_hz` to `to_hz`, at `level`.
static func tone(seconds: float, from_hz: float, to_hz: float, level: float) -> SynthVoice:
	var voice: SynthVoice = SynthVoice.new()
	voice.duration = seconds
	voice.freq_start = from_hz
	voice.freq_end = to_hz
	voice.volume = level
	return voice


## Mix in `square_mix` of the square and `noise_mix` of noise low-passed at `low_pass`.
func with_noise(square_mix: float, noise_mix: float, low_pass: float) -> SynthVoice:
	square = square_mix
	noise = noise_mix
	cutoff = low_pass
	return self


func with_duty(cycle: float) -> SynthVoice:
	duty = cycle
	return self


func held() -> SynthVoice:
	flat = true
	return self


func after(seconds: float) -> SynthVoice:
	delay = seconds
	return self


func end_time() -> float:
	return delay + duration
