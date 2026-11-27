class_name IntelCodex
extends RefCounted
## Intel unlocks (#73): an enemy kind or a boss stays "???" in the Intel codex
## until it is first encountered in play, and the unlock persists through a
## DocumentStore. Only ids in the known catalog can unlock.
##
## Listens: flow.game_state_changed (encounters count only during play, not
## the Title's attract mode), enemy.enemy_spawned and boss.boss_summoned.
## Announces: profile.intel_unlocked (first encounter) and
## profile.intel_changed (on restore()).

const DOCUMENT_VERSION: int = 1

var _events: EventBus
var _store: DocumentStore
var _known: Array[StringName] = []
var _unlocked: Array[StringName] = []
var _phase: GameState.Phase = GameState.Phase.BOOT


## `known_ids`: every enemy kind id and boss id the codex lists.
func _init(events: EventBus, store: DocumentStore, known_ids: Array[StringName]) -> void:
	_events = events
	_store = store
	_known = known_ids.duplicate()
	var subscribed: Array[int] = [
		_events.flow.game_state_changed.connect(_on_game_state_changed),
		_events.enemy.enemy_spawned.connect(_on_enemy_spawned),
		_events.boss.boss_summoned.connect(_on_boss_summoned),
	]
	Subscriptions.require_ok("IntelCodex", subscribed)


## The catalog for a Run: every enemy kind, then every Level's boss.
static func catalog(levels: Array[LevelDefinition]) -> Array[StringName]:
	var ids: Array[StringName] = EnemyKind.IDS.duplicate()
	for level: LevelDefinition in levels:
		if not ids.has(level.boss.id):
			ids.append(level.boss.id)
	return ids


## Reads the stored unlocks (unknown ids are dropped) and announces them.
func restore() -> void:
	_unlocked.clear()
	var document: Dictionary = _store.read_document()
	if document.has("unlocked") and document["unlocked"] is Array:
		var stored: Array = document["unlocked"]
		for item: Variant in stored:
			if item is String or item is StringName:
				var id: StringName = StringName(str(item))
				if _known.has(id) and not _unlocked.has(id):
					_unlocked.append(id)
	_events.profile.announce_intel_changed(unlocked())


func is_unlocked(id: StringName) -> bool:
	return _unlocked.has(id)


## A copy of the unlocked ids, in unlock order.
func unlocked() -> Array[StringName]:
	return _unlocked.duplicate()


## Unlocks `id` if it is known and still locked: saves and announces it.
## Returns true when it was newly unlocked.
func unlock(id: StringName) -> bool:
	if not _known.has(id) or _unlocked.has(id):
		return false
	_unlocked.append(id)
	var stored: Array[String] = []
	for unlocked_id: StringName in _unlocked:
		stored.append(String(unlocked_id))
	if not _store.write_document({"version": DOCUMENT_VERSION, "unlocked": stored}):
		push_warning("IntelCodex: could not be saved")
	_events.profile.announce_intel_unlocked(id)
	return true


func _on_game_state_changed(_from: GameState.Phase, to: GameState.Phase) -> void:
	_phase = to


func _on_enemy_spawned(_enemy_id: int, kind: EnemyKind.Kind, _position: Vector3) -> void:
	if GameState.is_play(_phase):
		var _new: bool = unlock(EnemyKind.id_of(kind))


func _on_boss_summoned(
	boss_id: StringName, _boss_name: String, _max_health: int, _phases: int
) -> void:
	if GameState.is_play(_phase):
		var _new: bool = unlock(boss_id)
