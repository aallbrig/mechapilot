extends GdUnitTestSuite
## The fixture's one healthy suite: the harness tests plant attack suites next to
## it and check that it still passes on its own (scripts/godot-test, #125).


func test_fixture_passes() -> void:
	var _ok: GdUnitAssert = assert_int(1 + 1).is_equal(2)
