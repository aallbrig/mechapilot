extends GdUnitTestSuite
## LocalDocumentStore keeps each store in its own user:// JSON file.
## user:// is private to each suite under scripts/godot-test.


func test_local_document_store_round_trips_user_file() -> void:
	var store: LocalDocumentStore = LocalDocumentStore.new(LocalDocumentStore.Slot.SCOREBOARD)
	var other: LocalDocumentStore = LocalDocumentStore.new(LocalDocumentStore.Slot.SETTINGS)
	var document: Dictionary = {"version": 1, "entries": [{"initials": "AAA", "score": 10}]}
	var wrote: bool = store.write_document(document)
	var read_back: Dictionary = (
		LocalDocumentStore.new(LocalDocumentStore.Slot.SCOREBOARD).read_document()
	)
	var _wrote: GdUnitAssert = assert_bool(wrote).is_true()
	var _same: GdUnitAssert = assert_str(JSON.stringify(read_back)).is_equal(
		JSON.stringify({"version": 1.0, "entries": [{"initials": "AAA", "score": 10.0}]})
	)
	var _separate_file: GdUnitAssert = assert_dict(other.read_document()).is_empty()
	var _on_disk: GdUnitAssert = (
		assert_bool(FileAccess.file_exists("user://scoreboard.json")).is_true()
	)


func test_local_document_store_reads_missing_or_corrupt_as_empty() -> void:
	var file: FileAccess = FileAccess.open("user://intel.json", FileAccess.WRITE)
	var stored: bool = file.store_string("[not json")
	file.close()
	var corrupt: Dictionary = LocalDocumentStore.new(LocalDocumentStore.Slot.INTEL).read_document()
	var missing: Dictionary = (
		LocalDocumentStore.new(LocalDocumentStore.Slot.TUTORIAL).read_document()
	)
	var _stored: GdUnitAssert = assert_bool(stored).is_true()
	var _corrupt: GdUnitAssert = assert_dict(corrupt).is_empty()
	var _missing: GdUnitAssert = assert_dict(missing).is_empty()
