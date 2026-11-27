extends GdUnitTestSuite
## The Credits name the game's creator (#105): on screen and in CREDITS.md.

var _h: UiHarness


func before_test() -> void:
	_h = UiHarness.new()
	add_child(_h.host)


func after_test() -> void:
	_h.dispose()


func test_credits_screen_names_the_creator() -> void:
	_h.reach_title()
	_h.ui.open(&"credits")
	var screen: CreditsScreen = _h.screen(&"Credits") as CreditsScreen
	var opening: Array[Label] = screen.opening()
	var words: PackedStringArray = []
	var styles: Array[StringName] = []
	for line: Label in opening:
		var _added: bool = words.append(line.text)
		styles.append(line.theme_type_variation)
	var _named: GdUnitAssert = assert_str(" ".join(words)).is_equal("Created by Andrew Allbright")
	var _titled: GdUnitAssert = assert_array(styles).is_equal([&"ComboLabel", &"TitleLabel"])
	var _first: GdUnitAssert = assert_int(screen.opening_index()).is_equal(0)


func test_credits_file_names_the_creator() -> void:
	var file: FileAccess = FileAccess.open("res://CREDITS.md", FileAccess.READ)
	var lines: PackedStringArray = file.get_as_text().split("\n")
	var creator_at: int = lines.find("Created by Andrew Allbright.")
	var table_at: int = -1
	for i: int in lines.size():
		if table_at < 0 and lines[i].begins_with("| Asset"):
			table_at = i
	var _named: GdUnitAssert = assert_int(creator_at).is_greater_equal(0)
	var _above: GdUnitAssert = assert_int(creator_at).is_less(table_at)
	var _read: GdUnitAssert = assert_str(CreditsScreen.read_creator()).is_equal("Andrew Allbright")
