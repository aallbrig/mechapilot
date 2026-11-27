class_name Scoreboard
extends RefCounted
## The local Scoreboard: the top 10 Runs, best first, with initials, score,
## Level reached and time, persisted through a DocumentStore.
##
## Listens: run.run_ended (remembers the Run; announces profile.scoreboard_qualified
## when it places) and profile.initials_submitted (saves the remembered Run).
## Announces: profile.scoreboard_qualified, profile.scoreboard_saved and
## profile.scoreboard_changed (on restore() and after every save).
## Ties keep the earlier entry first. A score of 0 never places, and neither
## does a dev-assisted Run (#116).

const CAPACITY: int = 10
const INITIALS_LENGTH: int = 3
const DOCUMENT_VERSION: int = 1
const MAX_LEVEL: int = RunRules.LEVEL_COUNT
const MAX_SCORE: int = 1_000_000_000
const MAX_TIME_SECONDS: float = 1.0e7

var _events: EventBus
var _store: DocumentStore
var _entries: Array[ScoreEntry] = []
var _pending: RunSummary = null


func _init(events: EventBus, store: DocumentStore) -> void:
	_events = events
	_store = store
	var subscribed: Array[int] = [
		_events.run.run_ended.connect(_on_run_ended),
		_events.profile.initials_submitted.connect(_on_initials_submitted),
	]
	Subscriptions.require_ok("Scoreboard", subscribed)


## Reads the stored entries (invalid rows are dropped) and announces them.
func restore() -> void:
	_entries = _parse(_store.read_document())
	_events.profile.announce_scoreboard_changed(entries(), -1)


## A copy of the entries, best first.
func entries() -> Array[ScoreEntry]:
	return _entries.duplicate()


## The 0-based rank `score` would take, or -1 if it would not place.
func rank_for(score: int) -> int:
	if score <= 0:
		return -1
	for i: int in _entries.size():
		if score > _entries[i].score:
			return i
	return _entries.size() if _entries.size() < CAPACITY else -1


## Inserts an entry if it places, saves, and announces it. Returns its 0-based
## rank, or -1 if it did not place. Initials are normalized (see normalize_initials).
func submit(entry: ScoreEntry) -> int:
	var rank: int = rank_for(entry.score)
	if rank < 0:
		return -1
	var saved: ScoreEntry = ScoreEntry.new(
		normalize_initials(entry.initials),
		entry.score,
		clampi(entry.level_reached, 1, MAX_LEVEL),
		clampf(entry.time_seconds, 0.0, MAX_TIME_SECONDS)
	)
	var _inserted: int = _entries.insert(rank, saved)
	if _entries.size() > CAPACITY:
		var _resized: int = _entries.resize(CAPACITY)
	if not _store.write_document(_serialize()):
		push_warning("Scoreboard: the entry could not be saved")
	_events.profile.announce_scoreboard_saved(saved, rank)
	_events.profile.announce_scoreboard_changed(entries(), rank)
	return rank


## Three letters A to Z: lowercase is raised, anything else becomes "A", and
## the result is cut or padded to three letters.
static func normalize_initials(raw: String) -> String:
	var upper: String = raw.to_upper()
	var out: String = ""
	for i: int in INITIALS_LENGTH:
		var letter: String = upper.substr(i, 1)
		out += letter if letter >= "A" and letter <= "Z" and letter.length() == 1 else "A"
	return out


func _on_run_ended(summary: RunSummary) -> void:
	var rank: int = -1 if summary.dev_assisted else rank_for(summary.score)
	_pending = summary if rank >= 0 else null
	if rank >= 0:
		_events.profile.announce_scoreboard_qualified(rank)


func _on_initials_submitted(initials: String) -> void:
	if _pending == null:
		return
	var summary: RunSummary = _pending
	_pending = null
	var _rank: int = submit(
		ScoreEntry.new(initials, summary.score, summary.level_reached, summary.time_seconds)
	)


func _serialize() -> Dictionary:
	var rows: Array[Dictionary] = []
	for entry: ScoreEntry in _entries:
		(
			rows
			. append(
				{
					"initials": entry.initials,
					"score": entry.score,
					"level_reached": entry.level_reached,
					"time_seconds": entry.time_seconds,
				}
			)
		)
	return {"version": DOCUMENT_VERSION, "entries": rows}


static func _parse(document: Dictionary) -> Array[ScoreEntry]:
	var parsed: Array[ScoreEntry] = []
	if not document.has("entries") or not document["entries"] is Array:
		return parsed
	var rows: Array = document["entries"]
	for row: Variant in rows:
		if not row is Dictionary:
			continue
		var reader: DataReader = DataReader.new()
		var data: Dictionary = row
		var entry: ScoreEntry = ScoreEntry.new(
			reader.text(data, "initials", "entry"),
			reader.integer(data, "score", "entry", 1, MAX_SCORE),
			reader.integer(data, "level_reached", "entry", 1, MAX_LEVEL),
			reader.number(data, "time_seconds", "entry", 0.0, MAX_TIME_SECONDS)
		)
		if reader.is_ok() and normalize_initials(entry.initials) == entry.initials:
			parsed.append(entry)
	return _stable_best_first(parsed)


## The entries sorted best first, equal scores kept in stored order, cut to CAPACITY.
static func _stable_best_first(rows: Array[ScoreEntry]) -> Array[ScoreEntry]:
	var sorted: Array[ScoreEntry] = []
	for entry: ScoreEntry in rows:
		var at: int = sorted.size()
		for i: int in sorted.size():
			if entry.score > sorted[i].score:
				at = i
				break
		var _inserted: int = sorted.insert(at, entry)
	if sorted.size() > CAPACITY:
		var _resized: int = sorted.resize(CAPACITY)
	return sorted
