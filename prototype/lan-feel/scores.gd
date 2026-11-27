extends RefCounted
## PROTOTYPE local top-10 leaderboard, saved with ConfigFile under user://.

const PATH := "user://leaderboard.cfg"
const SIZE := 10


static func load_rows() -> Array[Dictionary]:
	var cfg := ConfigFile.new()
	var rows: Array[Dictionary] = []
	if cfg.load(PATH) != OK:
		return rows
	for i in SIZE:
		var key := "e%d" % i
		if not cfg.has_section_key("top", key):
			break
		var row: Dictionary = cfg.get_value("top", key)
		rows.append(row)
	return rows


static func qualifies(score: int) -> bool:
	if score <= 0:
		return false
	var rows := load_rows()
	return rows.size() < SIZE or score > int(rows[rows.size() - 1]["score"])


## Insert and save; returns the 0-based rank, or -1 when it did not place.
static func submit(initials: String, score: int) -> int:
	var rows := load_rows()
	var rank := rows.size()
	for i in rows.size():
		if score > int(rows[i]["score"]):
			rank = i
			break
	if rank >= SIZE:
		return -1
	rows.insert(rank, {"initials": initials, "score": score})
	rows.resize(mini(rows.size(), SIZE))
	var cfg := ConfigFile.new()
	for i in rows.size():
		cfg.set_value("top", "e%d" % i, rows[i])
	cfg.save(PATH)
	return rank
