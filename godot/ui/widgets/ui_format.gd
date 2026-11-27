class_name UiFormat
extends RefCounted
## Number formats shared by the HUD, the tallies and the Scoreboard.

const GROUP_SIZE: int = 3
const PERCENT: float = 100.0


## A score with thousands separators: 1234567 is "1,234,567".
static func score(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		if count > 0 and count % GROUP_SIZE == 0:
			out = "," + out
		out = digits[i] + out
		count += 1
	return ("-" + out) if value < 0 else out


## A ratio from 0 to 1 as a whole percentage: 0.756 is "76%".
static func percent(ratio: float) -> String:
	return "%d%%" % roundi(clampf(ratio, 0.0, 1.0) * PERCENT)
