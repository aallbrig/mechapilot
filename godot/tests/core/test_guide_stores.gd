extends GdUnitTestSuite
## The game guide's persisted stores (#75) restore only what they wrote: a
## tampered or corrupt document never unlocks an Intel entry, skips a tutorial
## prompt or ends the first Run.

var _bus: EventBus


func before_test() -> void:
	_bus = EventBus.new()


func after_test() -> void:
	_bus.free()


func test_tutorial_progress_ignores_tampered_stored_progress() -> void:
	var nested: Dictionary = {"move": true}
	var listed: Array = ["aim_and_fire"]
	var tampered: MemoryDocumentStore = (
		MemoryDocumentStore
		. new(
			{
				"done": [1, null, "move", "move", nested, listed, "bogus", "SHOTS_DROP", 2.0, true],
				"first_run_done": "yes",
			}
		)
	)
	var progress: TutorialProgress = TutorialProgress.new(tampered)
	progress.restore()
	var done: Array[TutorialPrompt.Id] = []
	for prompt: TutorialPrompt.Id in TutorialPrompt.Id.values():
		if progress.is_done(prompt):
			done.append(prompt)
	var first_run_done: bool = progress.is_first_run_done()
	var complete: bool = progress.is_complete()
	var shapes: Array[bool] = []
	for bad_done: Variant in ["move", {"move": true}, 7]:
		var odd: TutorialProgress = TutorialProgress.new(
			MemoryDocumentStore.new({"done": bad_done, "first_run_done": 1})
		)
		odd.restore()
		shapes.append(odd.is_done(TutorialPrompt.Id.MOVE) or odd.is_first_run_done())
	var _only_move: GdUnitAssert = assert_array(done).is_equal([TutorialPrompt.Id.MOVE])
	var _first_run: GdUnitAssert = assert_bool(first_run_done).is_false()
	var _not_complete: GdUnitAssert = assert_bool(complete).is_false()
	var _bad_shapes: GdUnitAssert = assert_array(shapes).is_equal([false, false, false])


func test_intel_codex_ignores_tampered_stored_unlocks() -> void:
	var levels: Array[LevelDefinition] = LevelLibrary.all_levels()
	var listed: Array = ["heavy"]
	var tampered: MemoryDocumentStore = MemoryDocumentStore.new(
		{"unlocked": [1, "fighter", "fighter", "zzz", null, listed, 3.5]}
	)
	var codex: IntelCodex = IntelCodex.new(
		_bus, tampered, IntelCodex.catalog(levels), IntelCodex.entries_for(levels)
	)
	codex.restore()
	var restored: Array[StringName] = codex.unlocked()
	var shapes: Array[int] = []
	for bad_unlocked: Variant in [{"fighter": true}, "fighter", 7]:
		var odd: IntelCodex = IntelCodex.new(
			_bus,
			MemoryDocumentStore.new({"unlocked": bad_unlocked}),
			IntelCodex.catalog(levels),
			IntelCodex.entries_for(levels)
		)
		odd.restore()
		shapes.append(odd.unlocked().size())
	var _only_fighter: GdUnitAssert = assert_array(restored).is_equal([&"fighter"])
	var _bad_shapes: GdUnitAssert = assert_array(shapes).is_equal([0, 0, 0])
