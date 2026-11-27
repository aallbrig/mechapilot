class_name MusicDirector
extends Node
## Chooses and crossfades the music (#73, "Audio"), on the Music bus:
##
##   Title, Scoreboard        the title theme
##   Level Intro, Skirmish    the level loop
##   Boss Warning, Boss Fight the boss loop, crossfaded in on boss_warning_started
##   Level Clear              the loop fades and the Level Clear sting plays
##   Game Over                the loop fades and the Game Over sting plays
##   Paused                   the music ducks until play resumes
##
## Two decks take turns, so a change is always a crossfade, and a new loop cuts
## a sting that is still sounding. Nothing plays until unlock() (the AudioUnlock
## gate); a track wanted before then, or before its stream has rendered, starts
## as soon as it can. It runs in real time.

## A boss's arrival crossfades over this long (s); every other change is quicker.
const CROSSFADE_SECONDS: float = 1.5
const FADE_SECONDS: float = 0.6
## The music's level while paused (linear).
const PAUSE_DUCK: float = 0.35
## A gain at or below this counts as silent (the deck stops).
const SILENT: float = 0.001
## No track (silence).
const NONE: int = -1

var _clock: RealClock = RealClock.new()
var _library: MusicLibrary
var _decks: Array[AudioStreamPlayer] = []
var _gain: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _target: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _sting: AudioStreamPlayer = AudioStreamPlayer.new()
var _live: int = 0
var _wanted: int = NONE
var _playing: int = NONE
var _fade_seconds: float = FADE_SECONDS
var _duck: float = 1.0
var _unlocked: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for _i: int in 2:
		var deck: AudioStreamPlayer = AudioStreamPlayer.new()
		deck.bus = AudioBuses.MUSIC
		add_child(deck)
		_decks.append(deck)
	_sting.bus = AudioBuses.MUSIC
	add_child(_sting)


func _process(_delta: float) -> void:
	advance(_clock.step())


## Play from `library`, and subscribe to `bus` (the Events autoload, or a test bus).
func bind(bus: EventBus, library: MusicLibrary) -> void:
	_library = library
	(
		BusLinks
		. require_ok(
			"MusicDirector",
			[
				library.track_ready.connect(_on_track_ready),
				bus.flow.game_state_changed.connect(_on_game_state_changed),
				bus.boss.boss_warning_started.connect(_on_boss_warning_started),
				bus.run.level_cleared.connect(_on_level_cleared),
			]
		)
	)


## Audio may play from now on (the first user gesture arrived).
func unlock() -> void:
	_unlocked = true
	_refresh()


## Run the fades on by `real_delta` seconds.
func advance(real_delta: float) -> void:
	var step: float = real_delta / maxf(_fade_seconds, SILENT)
	for i: int in _decks.size():
		_gain[i] = move_toward(_gain[i], _target[i], step)
		var deck: AudioStreamPlayer = _decks[i]
		if _gain[i] <= SILENT and _target[i] <= SILENT:
			if deck.playing:
				deck.stop()
		else:
			deck.volume_db = linear_to_db(maxf(_gain[i] * _duck, SILENT))


## The track playing on the live deck (a SongBook.Track), or NONE.
func current_track() -> int:
	return _playing


## The live deck's gain (0..1), and the other deck's.
func live_gain() -> float:
	return _gain[_live]


func fading_gain() -> float:
	return _gain[1 - _live]


## The player of each deck, then the sting's (for tests).
func players() -> Array[AudioStreamPlayer]:
	var all: Array[AudioStreamPlayer] = _decks.duplicate()
	all.append(_sting)
	return all


func _want(track: int, fade_seconds: float) -> void:
	if track == _wanted:
		return
	_wanted = track
	_fade_seconds = fade_seconds
	_refresh()


func _refresh() -> void:
	if not _unlocked or _wanted == _playing:
		return
	if _wanted == NONE:
		_target[_live] = 0.0
		_playing = NONE
		return
	var stream: AudioStream = _library.track_stream(_wanted as SongBook.Track)
	if stream == null:
		return
	_target[_live] = 0.0
	_live = 1 - _live
	var deck: AudioStreamPlayer = _decks[_live]
	deck.stream = stream
	_gain[_live] = 0.0
	_target[_live] = 1.0
	deck.volume_db = linear_to_db(SILENT)
	deck.play()
	_sting.stop()
	_playing = _wanted


func _play_sting(track: SongBook.Track) -> void:
	_want(NONE, FADE_SECONDS)
	if not _unlocked:
		return
	var stream: AudioStream = _library.track_stream(track)
	if stream == null:
		return
	_sting.stream = stream
	_sting.play()


func _on_track_ready(_track: SongBook.Track) -> void:
	_refresh()


func _on_game_state_changed(from: GameState.Phase, to: GameState.Phase) -> void:
	_duck = PAUSE_DUCK if to == GameState.Phase.PAUSED else 1.0
	match to:
		GameState.Phase.TITLE, GameState.Phase.SCOREBOARD:
			_want(SongBook.Track.TITLE, FADE_SECONDS)
		GameState.Phase.LEVEL_INTRO, GameState.Phase.SKIRMISH:
			_want(SongBook.Track.LEVEL, FADE_SECONDS)
		GameState.Phase.BOSS_WARNING, GameState.Phase.BOSS_FIGHT:
			_want(SongBook.Track.BOSS, CROSSFADE_SECONDS)
		GameState.Phase.GAME_OVER:
			if from != GameState.Phase.GAME_OVER:
				_play_sting(SongBook.Track.GAME_OVER)
		GameState.Phase.BOOT:
			_want(NONE, FADE_SECONDS)
		_:
			pass
	advance(0.0)


func _on_boss_warning_started(_boss_name: String, _duration: float) -> void:
	_want(SongBook.Track.BOSS, CROSSFADE_SECONDS)


func _on_level_cleared(_tally: LevelTally) -> void:
	_play_sting(SongBook.Track.LEVEL_CLEAR)
