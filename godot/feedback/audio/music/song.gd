class_name Song
extends RefCounted
## One piece of music in tracker form: a tempo, a length in sixteenth-note
## steps, and channels of notes. Patterns are written one token per step,
## separated by spaces ("|" between bars is ignored):
##
##   melodic channels   a note name with its octave ("A4", "C#5", "Bb3") starts
##                      a note, "-" holds the previous note, "." is a rest
##   the drum channel   "k" kick, "s" snare, "h" closed hat, "o" open hat, "." rest
##
## parse_*() collect every problem in `errors`, so the song book is checked by
## a test instead of failing quietly at runtime.

enum Instrument { LEAD, HARMONY, BASS, ARP, DRUMS }
enum Drum { KICK, SNARE, HAT, OPEN_HAT }

const STEPS_PER_BEAT: int = 4
const STEPS_PER_BAR: int = 16
const NOTE_NAMES: Dictionary[String, int] = {
	"C": 0,
	"D": 2,
	"E": 4,
	"F": 5,
	"G": 7,
	"A": 9,
	"B": 11,
}
const DRUM_TOKENS: Dictionary[String, Drum] = {
	"k": Drum.KICK,
	"s": Drum.SNARE,
	"h": Drum.HAT,
	"o": Drum.OPEN_HAT,
}
const HOLD: String = "-"
const REST: String = "."
const BAR: String = "|"
## Step codes of add_steps(): hold the previous note, or rest.
const HOLD_CODE: int = -2
const REST_CODE: int = -1

var title: String = ""
var bpm: float = 120.0
var steps: int = 0
var loops: bool = true
## One chord name per bar ("Am", "F", "C#m"), for songs built from chords.
var chords: PackedStringArray = PackedStringArray()
var channels: Array[Channel] = []


## One note (or drum hit) of a channel: when it starts and how long it lasts
## (in steps), and its MIDI note number (or Drum).
class Note:
	extends RefCounted
	var start: int
	var length: int
	var pitch: int


## One instrument's line of notes, at a volume.
class Channel:
	extends RefCounted
	var instrument: Instrument
	var volume: float
	var notes: Array[Note] = []


func _init(song_title: String, tempo: float, bars: int, looping: bool) -> void:
	title = song_title
	bpm = tempo
	steps = bars * STEPS_PER_BAR
	loops = looping


## Seconds per step.
func step_seconds() -> float:
	return 60.0 / bpm / float(STEPS_PER_BEAT)


func seconds() -> float:
	return step_seconds() * float(steps)


## Add a melodic channel parsed from `pattern`, which must fill the song.
func add_melodic(
	instrument: Instrument, volume: float, pattern: String, errors: Array[String]
) -> void:
	var codes: PackedInt32Array = PackedInt32Array()
	for token: String in tokens_of(pattern):
		if token == HOLD:
			var _held: bool = codes.append(HOLD_CODE)
		elif token == REST:
			var _rest: bool = codes.append(REST_CODE)
		else:
			var pitch: int = midi_of(token)
			if pitch < 0:
				errors.append("%s: bad note %s at step %d" % [title, token, codes.size()])
			var _note_code: bool = codes.append(maxi(pitch, REST_CODE))
	add_steps(instrument, volume, codes, errors)


## Add a melodic channel from one code per step: a MIDI note, HOLD_CODE or
## REST_CODE. It must fill the song.
func add_steps(
	instrument: Instrument, volume: float, codes: PackedInt32Array, errors: Array[String]
) -> void:
	var channel: Channel = _channel(instrument, volume)
	var current: Note = null
	for step: int in codes.size():
		var code: int = codes[step]
		if code == HOLD_CODE:
			if current == null:
				errors.append("%s: hold with no note at step %d" % [title, step])
			else:
				current.length += 1
		elif code == REST_CODE:
			current = null
		else:
			current = _note(channel, step, code)
	_check_length(codes.size(), errors)


## Add the drum channel parsed from `pattern`, which must fill the song.
func add_drums(volume: float, pattern: String, errors: Array[String]) -> void:
	var channel: Channel = _channel(Instrument.DRUMS, volume)
	var tokens: PackedStringArray = tokens_of(pattern)
	for step: int in tokens.size():
		var token: String = tokens[step]
		if DRUM_TOKENS.has(token):
			var _hit: Note = _note(channel, step, DRUM_TOKENS[token])
		elif token != REST:
			errors.append("%s: bad drum %s at step %d" % [title, token, step])
	_check_length(tokens.size(), errors)


## The step tokens of `pattern` (bar lines dropped).
static func tokens_of(pattern: String) -> PackedStringArray:
	var tokens: PackedStringArray = PackedStringArray()
	for token: String in pattern.replace("\n", " ").replace("\t", " ").split(" ", false):
		var trimmed: String = token.strip_edges()
		if trimmed != "" and trimmed != BAR:
			var _added: bool = tokens.append(trimmed)
	return tokens


## The MIDI note of a name like "A4", "C#5" or "Bb3"; -1 if it is not one.
static func midi_of(token: String) -> int:
	if token.length() < 2 or not NOTE_NAMES.has(token.left(1)):
		return -1
	var semitone: int = NOTE_NAMES[token.left(1)]
	var rest: String = token.substr(1)
	if rest.begins_with("#"):
		semitone += 1
		rest = rest.substr(1)
	elif rest.begins_with("b"):
		semitone -= 1
		rest = rest.substr(1)
	if not rest.is_valid_int():
		return -1
	return (rest.to_int() + 1) * 12 + semitone


## The frequency (Hz) of MIDI note `pitch`.
static func hz_of(pitch: int) -> float:
	return 440.0 * pow(2.0, float(pitch - 69) / 12.0)


func _channel(instrument: Instrument, volume: float) -> Channel:
	var channel: Channel = Channel.new()
	channel.instrument = instrument
	channel.volume = volume
	channels.append(channel)
	return channel


func _note(channel: Channel, step: int, pitch: int) -> Note:
	var note: Note = Note.new()
	note.start = step
	note.length = 1
	note.pitch = pitch
	channel.notes.append(note)
	return note


func _check_length(count: int, errors: Array[String]) -> void:
	if count != steps:
		errors.append("%s: a channel has %d steps, the song %d" % [title, count, steps])
