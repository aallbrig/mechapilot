class_name SfxBank
extends RefCounted
## Every sound effect of the game as synth data (#26, #73: SFX for every
## action), tuned from the LAN prototype's sfx.gd. Each cue is a list of
## SynthVoice layers, rendered once into an AudioStreamWAV by render_all().
## All of it is original work made for this repository (CC0, godot/CREDITS.md).

enum Cue {
	SHOT,
	ENEMY_HIT,
	EXPLOSION,
	BIG_EXPLOSION,
	COMBO,
	PLAYER_HIT,
	LOW_ARMOR,
	REPAIR,
	ONE_UP,
	PLAYER_DESTROYED,
	SIREN,
	BOSS_HIT,
	BOSS_PHASE,
	LEVEL_START,
	UI_MOVE,
	UI_CONFIRM,
	UI_BACK,
	UI_TOGGLE,
	UI_SLIDE,
	UI_LETTER,
	UI_TICK,
	UI_TALLY,
	UI_POP,
	UI_WARNING,
	UI_START,
}

## The cue of each screen sound, indexed by UiCue.Cue. These cues play on the UI
## bus; every other cue plays on the SFX bus.
const FOR_UI: Array[Cue] = [
	Cue.UI_MOVE,
	Cue.UI_CONFIRM,
	Cue.UI_BACK,
	Cue.UI_TOGGLE,
	Cue.UI_SLIDE,
	Cue.UI_LETTER,
	Cue.UI_TICK,
	Cue.UI_TALLY,
	Cue.UI_POP,
	Cue.UI_WARNING,
	Cue.UI_START,
]
## Each cue's noise is seeded with this plus the cue, so renders repeat exactly.
const NOISE_SEED: int = 2600
## A major-third ratio and a semitone, for arpeggios.
const MAJOR_THIRD: float = 1.26
const SEMITONE: float = 1.0594631


## Render every cue.
static func render_all() -> Dictionary[Cue, AudioStreamWAV]:
	var streams: Dictionary[Cue, AudioStreamWAV] = {}
	for value: int in Cue.values():
		var cue: Cue = value as Cue
		streams[cue] = SfxSynth.render(voices_for(cue), NOISE_SEED + cue)
	return streams


## True when `cue` plays on the UI bus.
static func is_ui(cue: Cue) -> bool:
	return FOR_UI.has(cue)


## The synth layers of `cue`.
static func voices_for(cue: Cue) -> Array[SynthVoice]:
	var voices: Array[SynthVoice] = []
	match cue:
		Cue.SHOT:
			voices = [SynthVoice.tone(0.07, 1000.0, 180.0, 0.18).with_noise(0.35, 0.25, 0.6)]
		Cue.ENEMY_HIT:
			voices = [SynthVoice.tone(0.05, 300.0, 120.0, 0.3).with_noise(0.4, 0.6, 0.8)]
		Cue.EXPLOSION:
			voices = [
				SynthVoice.tone(0.45, 140.0, 35.0, 0.55).with_noise(0.35, 1.0, 0.25),
				SynthVoice.tone(0.25, 90.0, 40.0, 0.3).with_noise(0.6, 0.0, 1.0),
			]
		Cue.BIG_EXPLOSION:
			voices = [
				SynthVoice.tone(0.9, 120.0, 25.0, 0.7).with_noise(0.3, 1.0, 0.15),
				SynthVoice.tone(0.6, 70.0, 25.0, 0.4).with_noise(0.6, 0.0, 1.0),
			]
		Cue.COMBO:
			voices = [SynthVoice.tone(0.12, 440.0, 660.0, 0.12).with_noise(0.3, 0.0, 1.0)]
		Cue.PLAYER_HIT:
			voices = [
				SynthVoice.tone(0.18, 220.0, 70.0, 0.45).with_noise(0.5, 0.6, 0.4),
				SynthVoice.tone(0.08, 900.0, 300.0, 0.12).with_noise(0.4, 0.0, 1.0),
			]
		Cue.LOW_ARMOR:
			voices = [
				SynthVoice.tone(0.07, 1320.0, 1320.0, 0.1).with_noise(0.4, 0.0, 1.0).held(),
				SynthVoice.tone(0.07, 990.0, 990.0, 0.1).with_noise(0.4, 0.0, 1.0).held().after(
					0.1
				),
			]
		Cue.REPAIR:
			voices = _arpeggio(660.0, MAJOR_THIRD, 3, 0.07, 0.14)
		Cue.ONE_UP:
			voices = _arpeggio(523.0, MAJOR_THIRD, 4, 0.08, 0.14)
		Cue.PLAYER_DESTROYED:
			voices = [
				SynthVoice.tone(1.6, 220.0, 25.0, 0.8).with_noise(0.4, 1.0, 0.12),
				SynthVoice.tone(0.8, 90.0, 30.0, 0.4).with_noise(0.6, 0.0, 1.0),
			]
		Cue.SIREN:
			voices = [
				SynthVoice.tone(0.5, 520.0, 1040.0, 0.16).with_noise(0.45, 0.0, 1.0).held(),
				SynthVoice.tone(0.5, 1040.0, 520.0, 0.16).with_noise(0.45, 0.0, 1.0).held().after(
					0.5
				),
			]
		Cue.BOSS_HIT:
			voices = [SynthVoice.tone(0.04, 500.0, 250.0, 0.16).with_noise(0.35, 0.3, 0.7)]
		Cue.BOSS_PHASE:
			voices = [
				SynthVoice.tone(0.5, 200.0, 600.0, 0.25).with_noise(0.4, 0.0, 1.0),
				SynthVoice.tone(0.35, 160.0, 60.0, 0.35).with_noise(0.2, 1.0, 0.3),
			]
		Cue.LEVEL_START:
			voices = [
				SynthVoice.tone(0.25, 330.0, 660.0, 0.15).with_noise(0.4, 0.0, 1.0),
				SynthVoice.tone(0.35, 495.0, 990.0, 0.12).with_noise(0.3, 0.0, 1.0).after(0.1),
			]
		Cue.UI_MOVE:
			voices = [SynthVoice.tone(0.04, 1400.0, 1700.0, 0.12).with_noise(0.3, 0.0, 1.0)]
		Cue.UI_CONFIRM:
			voices = [SynthVoice.tone(0.12, 600.0, 1500.0, 0.12).with_noise(0.35, 0.1, 0.8)]
		Cue.UI_BACK:
			voices = [SynthVoice.tone(0.1, 900.0, 400.0, 0.1).with_noise(0.35, 0.05, 0.8)]
		Cue.UI_TOGGLE:
			voices = [
				SynthVoice.tone(0.04, 800.0, 800.0, 0.1).with_noise(0.4, 0.0, 1.0),
				SynthVoice.tone(0.05, 1200.0, 1200.0, 0.1).with_noise(0.4, 0.0, 1.0).after(0.05),
			]
		Cue.UI_SLIDE:
			voices = [SynthVoice.tone(0.03, 1000.0, 1100.0, 0.08).with_noise(0.4, 0.0, 1.0)]
		Cue.UI_LETTER:
			voices = [SynthVoice.tone(0.05, 1500.0, 1300.0, 0.1).with_noise(0.4, 0.0, 1.0)]
		Cue.UI_TICK:
			voices = [SynthVoice.tone(0.025, 2000.0, 2000.0, 0.08).with_noise(0.4, 0.0, 1.0)]
		Cue.UI_TALLY:
			voices = _arpeggio(784.0, MAJOR_THIRD, 3, 0.06, 0.12)
		Cue.UI_POP:
			voices = [SynthVoice.tone(0.09, 700.0, 1800.0, 0.12).with_noise(0.4, 0.0, 1.0)]
		Cue.UI_WARNING:
			voices = [SynthVoice.tone(0.2, 880.0, 880.0, 0.14).with_noise(0.45, 0.0, 1.0).held()]
		Cue.UI_START:
			voices = _arpeggio(440.0, MAJOR_THIRD, 4, 0.06, 0.13)
	if voices.is_empty():
		push_error("SfxBank: no voices for cue %d" % cue)
	return voices


## `count` rising notes from `root_hz`, each `ratio` above the last.
static func _arpeggio(
	root_hz: float, ratio: float, count: int, step: float, level: float
) -> Array[SynthVoice]:
	var voices: Array[SynthVoice] = []
	for i: int in count:
		var hz: float = root_hz * pow(ratio, float(i))
		voices.append(
			SynthVoice.tone(step * 1.5, hz, hz * SEMITONE, level).with_noise(0.35, 0.0, 1.0).after(
				step * i
			)
		)
	return voices
