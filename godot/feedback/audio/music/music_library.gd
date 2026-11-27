class_name MusicLibrary
extends Node
## Renders the SongBook in the background, a few milliseconds per frame, so
## the game never stalls: the title theme first (the Boot screen waits for a
## tap anyway), then the level and boss loops, then the stings. `track_ready`
## reports each one. Rendering is not playing, so it may start before the
## audio unlock.

## The track's stream is ready.
signal track_ready(track: SongBook.Track)

## Render budget per frame (microseconds).
const FRAME_BUDGET_USEC: int = 3000
## Each song's noise is seeded with this plus its track, so it renders the same.
const NOISE_SEED: int = 7300
## The render order: what is needed first comes first.
const ORDER: Array[SongBook.Track] = [
	SongBook.Track.TITLE,
	SongBook.Track.LEVEL,
	SongBook.Track.BOSS,
	SongBook.Track.LEVEL_CLEAR,
	SongBook.Track.GAME_OVER,
]

var _streams: Dictionary[SongBook.Track, AudioStream] = {}
var _queue: Array[SongBook.Track] = ORDER.duplicate()
var _renderer: SongRenderer = null


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	render_for(FRAME_BUDGET_USEC)


## Render for up to `budget_usec` microseconds.
func render_for(budget_usec: int) -> void:
	if _queue.is_empty():
		return
	var track: SongBook.Track = _queue.front()
	if _renderer == null:
		var errors: Array[String] = []
		_renderer = SongRenderer.new(SongBook.song(track, errors), NOISE_SEED + track)
		for problem: String in errors:
			push_error("MusicLibrary: %s" % problem)
	if _renderer.step(budget_usec):
		var stream: AudioStreamWAV = _renderer.stream()
		_renderer = null
		provide(track, stream)


## Render everything now.
func render_all() -> void:
	while not _queue.is_empty():
		render_for(FRAME_BUDGET_USEC)


## Use `stream` for `track` (the renderer's result, or a stand-in in tests).
func provide(track: SongBook.Track, stream: AudioStream) -> void:
	if not _queue.is_empty() and _queue.front() == track:
		_renderer = null
	_queue.erase(track)
	_streams[track] = stream
	track_ready.emit(track)


## The stream of `track`, or null while it is still rendering.
func track_stream(track: SongBook.Track) -> AudioStream:
	if _streams.has(track):
		return _streams[track]
	return null


func is_done() -> bool:
	return _queue.is_empty()
