class_name TutorialProgress
extends RefCounted
## First-flight tutorial progress (#73, #75): which prompts are done, and
## whether the first Run has been flown. Persisted through a DocumentStore.
## It announces nothing: #75's tutorial rules decide when prompts show (and
## check GameSettings.tutorial_hints); this class only remembers.

const DOCUMENT_VERSION: int = 1

var _store: DocumentStore
var _done: Array[StringName] = []
var _first_run_done: bool = false


func _init(store: DocumentStore) -> void:
	_store = store


## Reads the stored progress (unknown prompt ids are dropped).
func restore() -> void:
	_done.clear()
	var document: Dictionary = _store.read_document()
	if document.has("done") and document["done"] is Array:
		var stored: Array = document["done"]
		for item: Variant in stored:
			var id: StringName = StringName(str(item)) if item is String else &""
			if TutorialPrompt.IDS.has(id) and not _done.has(id):
				_done.append(id)
	_first_run_done = document.has("first_run_done") and document["first_run_done"] is bool
	if _first_run_done:
		_first_run_done = document["first_run_done"]


## True once `prompt` has been shown and dismissed.
func is_done(prompt: TutorialPrompt.Id) -> bool:
	return _done.has(TutorialPrompt.id_of(prompt))


## Marks `prompt` done and saves. Returns true when it was not done before.
func mark_done(prompt: TutorialPrompt.Id) -> bool:
	var id: StringName = TutorialPrompt.id_of(prompt)
	if _done.has(id):
		return false
	_done.append(id)
	_save()
	return true


## True when every prompt is done.
func is_complete() -> bool:
	return _done.size() == TutorialPrompt.IDS.size()


## True once the first Run has been flown (the tutorial runs only in it).
func is_first_run_done() -> bool:
	return _first_run_done


## Remembers that the first Run has been flown, and saves.
func mark_first_run_done() -> void:
	if _first_run_done:
		return
	_first_run_done = true
	_save()


## Forgets all progress (for "reset tutorial") and saves.
func reset() -> void:
	_done.clear()
	_first_run_done = false
	_save()


func _save() -> void:
	var stored: Array[String] = []
	for id: StringName in _done:
		stored.append(String(id))
	var document: Dictionary = {
		"version": DOCUMENT_VERSION, "done": stored, "first_run_done": _first_run_done
	}
	if not _store.write_document(document):
		push_warning("TutorialProgress: could not be saved")
