class_name DocumentStore
extends RefCounted
## The storage interface behind every persisted store (Scoreboard, Settings,
## Intel and tutorial progress): one JSON-shaped Dictionary per store.
## core/ classes depend only on this interface. MemoryDocumentStore (core/) keeps
## the document in memory for tests; LocalDocumentStore (game/) keeps it in a
## user:// file. Subclasses override both methods.


## The stored document, or an empty Dictionary when nothing is stored yet or
## the stored data cannot be read. Callers validate every field.
func read_document() -> Dictionary:
	return {}


## Replaces the stored document. Returns false when it could not be written.
func write_document(_document: Dictionary) -> bool:
	return false
