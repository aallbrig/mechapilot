class_name SongBook
extends RefCounted
## The game's music (#26, #73): a title theme, a level loop and a boss loop,
## plus the Level Clear and Game Over stings. Original chiptune written for this
## repository (CC0, godot/CREDITS.md) and synthesized at startup by
## SongRenderer, so no audio file ships. Bass and arpeggio lines are generated
## from each song's chords and a one-bar template, where "R" is the chord's
## root, "3" its third, "5" its fifth and "8" the root an octave up.

enum Track { TITLE, LEVEL, BOSS, LEVEL_CLEAR, GAME_OVER }

const LEAD_VOLUME: float = 0.2
const HARMONY_VOLUME: float = 0.11
const BASS_VOLUME: float = 0.3
const ARP_VOLUME: float = 0.06
const DRUM_VOLUME: float = 0.34
const BASS_OCTAVE: int = 2
const ARP_OCTAVE: int = 4
const DEGREES: Dictionary[String, int] = {"R": 0, "5": 7, "8": 12}
const MINOR_THIRD: int = 3
const MAJOR_THIRD: int = 4

const TITLE_LEAD: String = """
A4 - - - C5 - E5 - D5 - C5 - B4 - C5 - | A4 - - - - - - - F4 - A4 - C5 - - - |
G4 - - - C5 - E5 - G5 - - - E5 - - - | D5 - - - B4 - - - G4 - A4 - B4 - D5 - |
E5 - - - A5 - - - G5 - E5 - C5 - - - | F5 - - - E5 - D5 - C5 - - - A4 - - - |
B4 - - - D5 - - - G5 - - - F5 - D5 - | E5 - - - - - - - G#4 - B4 - E5 - - .
"""
const LEVEL_LEAD: String = """
E5 - . E5 G5 - . E5 A5 - G5 - E5 - D5 - | E5 - - - . . C5 D5 E5 - G5 - E5 - . . |
D5 - . D5 G5 - . D5 B5 - A5 - G5 - D5 - | F#5 - - - E5 - D5 - A4 - - - . . . . |
E5 - . E5 G5 - . E5 A5 - G5 - E5 - D5 - | C5 - - - E5 - G5 - C6 - B5 - G5 - E5 - |
D5 - - - F#5 - A5 - D6 - - - C6 - A5 - | B5 - - - - - - - D#5 - F#5 - B5 - - .
"""
const BOSS_LEAD: String = """
D5 - D5 . F5 - D5 . A5 - G5 . F5 - E5 . | D5 - - - A4 - - - D5 - E5 - F5 - G5 - |
F5 - F5 . D5 - F5 . Bb5 - A5 . G5 - F5 . | E5 - - - C#5 - - - A4 - C#5 - E5 - G5 - |
A5 - A5 . F5 - A5 . D6 - C6 . A5 - F5 . | G5 - F5 - E5 - D5 - E5 - F5 - A5 - - - |
Bb5 - - - G5 - - - D5 - G5 - Bb5 - D6 - | C#6 - - - A5 - - - E5 - C#5 - A4 - - .
"""
const CLEAR_LEAD: String = """
C5 - F5 - A5 - C6 - - - A5 - C6 - - - | D6 - - - B5 - G5 - B5 - D6 - - - - - |
E6 - - - - - - - - - - - - - . .
"""
const CLEAR_HARMONY: String = """
A4 - C5 - F5 - A5 - - - F5 - A5 - - - | B4 - - - G5 - D5 - G5 - B5 - - - - - |
C5 - - - - - - - - - - - - - . .
"""
const CLEAR_BASS: String = """
F2 - - - - - - - C3 - - - F3 - - - | G2 - - - - - - - D3 - - - G3 - - - |
C3 - - - - - - - - - - - - - . .
"""
const CLEAR_DRUMS: String = """
k . . . s . . . k . k . s . s s | k . . . s . . . k . k . s s s s |
k . . . . . . . . . . . . . . .
"""
const OVER_LEAD: String = """
A4 - - - G4 - - - F4 - - - E4 - - - | D4 - - - E4 - - - C4 - - - B3 - - - |
A3 - - - - - - - - - - - - - . .
"""
const OVER_BASS: String = """
A2 - - - - - - - F2 - - - - - - - | D2 - - - - - - - E2 - - - - - - - |
A1 - - - - - - - - - - - - - . .
"""


## The song of `track`, and any problems with its data in `errors`.
static func song(track: Track, errors: Array[String]) -> Song:
	var built: Song
	match track:
		Track.TITLE:
			built = _loop("Title", 112.0, "Am F C G Am F G E", TITLE_LEAD, errors)
			_chord_line(built, Song.Instrument.BASS, "R - - . R - 8 . R - - . 5 - 8 .", errors)
			_chord_line(built, Song.Instrument.ARP, "R 3 5 8 R 3 5 8 R 3 5 8 R 3 5 8", errors)
			_drums(
				built, "k . h . s . h . k . h k s . h .", "k . h . s . h . k . s . s s s s", errors
			)
		Track.LEVEL:
			built = _loop("Level", 140.0, "Em C G D Em C D B", LEVEL_LEAD, errors)
			_chord_line(built, Song.Instrument.BASS, "R . R 8 R . R 8 R . R 8 5 . 8 .", errors)
			_chord_line(built, Song.Instrument.ARP, "R 5 8 5 R 5 8 5 R 5 8 5 R 5 8 5", errors)
			_drums(
				built, "k . h . s . h k k . h . s . h h", "k . h . s . h k s . s . s s s s", errors
			)
		Track.BOSS:
			built = _loop("Boss", 160.0, "Dm Dm Bb A Dm Dm Gm A", BOSS_LEAD, errors)
			_chord_line(built, Song.Instrument.BASS, "R R R R 8 R R R R R R R 8 R 5 R", errors)
			_chord_line(built, Song.Instrument.ARP, "R 3 5 3 R 3 5 3 8 5 3 5 R 3 5 3", errors)
			_drums(
				built, "k . h k s . h . k . h k s . h s", "k . k . s . s . k k s s s s s s", errors
			)
		Track.LEVEL_CLEAR:
			built = Song.new("Level Clear", 150.0, 3, false)
			built.add_melodic(Song.Instrument.LEAD, LEAD_VOLUME, CLEAR_LEAD, errors)
			built.add_melodic(Song.Instrument.HARMONY, HARMONY_VOLUME, CLEAR_HARMONY, errors)
			built.add_melodic(Song.Instrument.BASS, BASS_VOLUME, CLEAR_BASS, errors)
			built.add_drums(DRUM_VOLUME, CLEAR_DRUMS, errors)
		Track.GAME_OVER:
			built = Song.new("Game Over", 96.0, 3, false)
			built.add_melodic(Song.Instrument.LEAD, LEAD_VOLUME, OVER_LEAD, errors)
			built.add_melodic(Song.Instrument.BASS, BASS_VOLUME, OVER_BASS, errors)
	return built


## A looping song with its chords (one per bar) and its lead line.
static func _loop(
	title: String, bpm: float, chords: String, lead: String, errors: Array[String]
) -> Song:
	var names: PackedStringArray = Song.tokens_of(chords)
	var built: Song = Song.new(title, bpm, names.size(), true)
	built.chords = names
	built.add_melodic(Song.Instrument.LEAD, LEAD_VOLUME, lead, errors)
	return built


## A bass or arpeggio line: `template` (one bar) played over every chord.
static func _chord_line(
	built: Song, instrument: Song.Instrument, template: String, errors: Array[String]
) -> void:
	var bass: bool = instrument == Song.Instrument.BASS
	var octave: int = BASS_OCTAVE if bass else ARP_OCTAVE
	var volume: float = BASS_VOLUME if bass else ARP_VOLUME
	var bar: PackedStringArray = Song.tokens_of(template)
	if bar.size() != Song.STEPS_PER_BAR:
		errors.append("%s: a chord template has %d steps" % [built.title, bar.size()])
	var codes: PackedInt32Array = PackedInt32Array()
	for chord: String in built.chords:
		var root: int = Song.midi_of(_root_name(chord) + str(octave))
		if root < 0:
			errors.append("%s: bad chord %s" % [built.title, chord])
		var third: int = MINOR_THIRD if chord.ends_with("m") else MAJOR_THIRD
		for token: String in bar:
			var _added: bool = codes.append(_degree_code(token, root, third))
	built.add_steps(instrument, volume, codes, errors)


## The drum channel: `groove` every bar, then `fill` in the last.
static func _drums(built: Song, groove: String, fill: String, errors: Array[String]) -> void:
	var pattern: String = ""
	for _bar: int in built.chords.size() - 1:
		pattern += groove + " "
	built.add_drums(DRUM_VOLUME, pattern + fill, errors)


## "Am" -> "A", "C#m" -> "C#", "Bb" -> "Bb".
static func _root_name(chord: String) -> String:
	return chord.trim_suffix("m") if chord.length() > 1 else chord


static func _degree_code(token: String, root: int, third: int) -> int:
	var code: int = Song.REST_CODE
	if token == Song.HOLD:
		code = Song.HOLD_CODE
	elif token == "3":
		code = root + third
	elif DEGREES.has(token):
		code = root + DEGREES[token]
	return code
