extends GdUnitTestSuite
## The Credits name the game's creator (#105): on screen and in CREDITS.md.

var _h: UiHarness


## Phone portrait is the narrowest layout, so the name must fit on one line
## there. The harness runs with reduced motion on.
func before_test() -> void:
	_h = UiHarness.new(UiHarness.PORTRAIT)
	add_child(_h.host)


func after_test() -> void:
	_h.dispose()


func test_credits_screen_names_the_creator() -> void:
	_h.reach_title()
	_h.ui.open(&"credits")
	await await_idle_frame()
	await await_idle_frame()
	var screen: CreditsScreen = _h.screen(&"Credits") as CreditsScreen
	var opening: Array[Label] = screen.opening()
	var words: PackedStringArray = []
	var styles: Array[StringName] = []
	var lines: Array[int] = []
	var hidden: Array[String] = []
	for line: Label in opening:
		var _added: bool = words.append(line.text)
		styles.append(line.theme_type_variation)
		lines.append(line.get_line_count())
		if (
			not line.is_visible_in_tree()
			or not is_equal_approx(line.get_global_transform_with_canvas().get_scale().x, 1.0)
			or not is_equal_approx(line.modulate.a, 1.0)
		):
			hidden.append(line.text)
	var _reduced: GdUnitAssert = assert_bool(TweenFx.reduced_motion).is_true()
	var _named: GdUnitAssert = assert_str(" ".join(words)).is_equal("Created by Andrew Allbright")
	var _titled: GdUnitAssert = assert_array(styles).is_equal([&"ComboLabel", &"TitleLabel"])
	var _one_line: GdUnitAssert = assert_array(lines).is_equal([1, 1])
	var _shown: GdUnitAssert = assert_array(hidden).is_empty()
	var _first: GdUnitAssert = assert_int(screen.opening_index()).is_equal(0)


func test_credits_file_names_the_creator() -> void:
	var file: FileAccess = FileAccess.open("res://CREDITS.md", FileAccess.READ)
	var lines: PackedStringArray = file.get_as_text().split("\n")
	var creator_at: int = lines.find("Created by Andrew Allbright.")
	var table_at: int = -1
	for i: int in lines.size():
		if table_at < 0 and lines[i].begins_with("| Asset"):
			table_at = i
	var below_table: String = (
		CreditsScreen
		. creator_in(
			"# Credits\n\n| Asset | Source | Licence |\n| --- | --- | --- |\n\nCreated by Someone Else.\n"
		)
	)
	var in_cell: String = CreditsScreen.creator_in("| Created by Someone Else. | x | y |\n")
	var _named: GdUnitAssert = assert_int(creator_at).is_greater_equal(0)
	var _above: GdUnitAssert = assert_int(creator_at).is_less(table_at)
	var _read: GdUnitAssert = assert_str(CreditsScreen.read_creator()).is_equal("Andrew Allbright")
	var _not_below: GdUnitAssert = assert_str(below_table).is_empty()
	var _not_cell: GdUnitAssert = assert_str(in_cell).is_empty()
