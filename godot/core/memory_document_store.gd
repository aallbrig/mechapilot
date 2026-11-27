class_name MemoryDocumentStore
extends DocumentStore
## A DocumentStore held in memory, for tests and for runs without storage.
## It keeps a deep copy, so callers can never change the stored document by
## holding on to a reference, exactly like a file round trip.

var _document: Dictionary = {}
var _writes: int = 0


func _init(initial: Dictionary = {}) -> void:
	_document = initial.duplicate(true)


func read_document() -> Dictionary:
	return _document.duplicate(true)


func write_document(document: Dictionary) -> bool:
	_document = document.duplicate(true)
	_writes += 1
	return true


## How many times the document was written (tests use it to check saves).
func write_count() -> int:
	return _writes
