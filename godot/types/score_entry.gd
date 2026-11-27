class_name ScoreEntry
extends RefCounted
## One row of the Scoreboard: who (three-letter initials), how much, how far
## and how long.

## Three letters, A to Z (core/scoreboard.gd normalizes them).
var initials: String = ""
## The Run's final score.
var score: int = 0
## The Level the Run reached (1 to 6).
var level_reached: int = 1
## Run time in seconds (see RunSummary.time_seconds).
var time_seconds: float = 0.0


func _init(
	entry_initials: String, entry_score: int, entry_level_reached: int, entry_time_seconds: float
) -> void:
	initials = entry_initials
	score = entry_score
	level_reached = entry_level_reached
	time_seconds = entry_time_seconds


## The Run time as `mm:ss`.
func formatted_time() -> String:
	return RunSummary.format_mm_ss(time_seconds)


## True when both entries hold the same values.
func equals(other: ScoreEntry) -> bool:
	return (
		initials == other.initials
		and score == other.score
		and level_reached == other.level_reached
		and is_equal_approx(time_seconds, other.time_seconds)
	)
