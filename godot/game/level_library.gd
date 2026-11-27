class_name LevelLibrary
extends RefCounted
## Reads the six Level files (preloaded as JSON resources, so they ship in the
## web export) and parses them into LevelDefinitions for core/.

const FILES: Array[JSON] = [
	preload("res://levels/level_1.json"),
	preload("res://levels/level_2.json"),
	preload("res://levels/level_3.json"),
	preload("res://levels/level_4.json"),
	preload("res://levels/level_5.json"),
	preload("res://levels/level_6.json"),
]


## Every Level in Run order. Returns an empty list, with every problem in
## `errors` (if given), unless all six parse and are numbered 1 to 6 in order.
static func all_levels(errors: Array[String] = []) -> Array[LevelDefinition]:
	var levels: Array[LevelDefinition] = []
	for i: int in FILES.size():
		var problems: Array[String] = []
		var data: Variant = FILES[i].data
		var level: LevelDefinition = null
		if data is Dictionary:
			var document: Dictionary = data
			level = LevelDefinition.parse(document, problems)
		else:
			problems.append("not a JSON object")
		if level != null and level.number != i + 1:
			problems.append("number is %d, expected %d" % [level.number, i + 1])
		for problem: String in problems:
			errors.append("level_%d.json: %s" % [i + 1, problem])
		if problems.is_empty():
			levels.append(level)
	if levels.size() != FILES.size():
		levels.clear()
	return levels
