class_name LocalDocumentStore
extends DocumentStore
## A DocumentStore kept as a JSON file under user:// (IndexedDB on the web).
## Each Slot maps to one fixed file: scripts/checks/godot-safe-api only allows a
## FileAccess path that is one complete "user://" literal, so the paths are
## spelled out per slot instead of being computed.

enum Slot { SCOREBOARD, SETTINGS, INTEL, TUTORIAL }

var _slot: Slot = Slot.SCOREBOARD


func _init(slot: Slot) -> void:
	_slot = slot


func read_document() -> Dictionary:
	if not _exists():
		return {}
	var file: FileAccess = _open(FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	var document: Dictionary = json.data
	return document


func write_document(document: Dictionary) -> bool:
	var file: FileAccess = _open(FileAccess.WRITE)
	if file == null:
		return false
	var ok: bool = file.store_string(JSON.stringify(document, "\t"))
	file.close()
	return ok


## Opens this slot's file. Returns null when it does not exist (READ) or cannot
## be created (WRITE).
func _open(mode: FileAccess.ModeFlags) -> FileAccess:
	match _slot:
		Slot.SCOREBOARD:
			return FileAccess.open("user://scoreboard.json", mode)
		Slot.SETTINGS:
			return FileAccess.open("user://settings.json", mode)
		Slot.INTEL:
			return FileAccess.open("user://intel.json", mode)
		Slot.TUTORIAL:
			return FileAccess.open("user://tutorial.json", mode)
	return null


func _exists() -> bool:
	match _slot:
		Slot.SCOREBOARD:
			return FileAccess.file_exists("user://scoreboard.json")
		Slot.SETTINGS:
			return FileAccess.file_exists("user://settings.json")
		Slot.INTEL:
			return FileAccess.file_exists("user://intel.json")
		Slot.TUTORIAL:
			return FileAccess.file_exists("user://tutorial.json")
	return false
