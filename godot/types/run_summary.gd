class_name RunSummary
extends RefCounted
## The final tally of a Run, announced with `Events.run.run_ended` at Game Over
## or Victory.

const SECONDS_PER_MINUTE: int = 60

## The final score.
var score: int = 0
## The Level the Run reached (1 to 6).
var level_reached: int = 1
## Run time in seconds. It excludes every Level Intro, pause and Level Clear.
var time_seconds: float = 0.0
## Enemies destroyed by the player's shots over the whole Run.
var kills: int = 0
## True when the Run ended in Victory (the Level 6 boss was defeated).
var victory: bool = false


func _init(
	run_score: int, run_level_reached: int, run_time_seconds: float, run_kills: int, won: bool
) -> void:
	score = run_score
	level_reached = run_level_reached
	time_seconds = run_time_seconds
	kills = run_kills
	victory = won


## The Run time as `mm:ss` (whole seconds, rounded down).
func formatted_time() -> String:
	return format_mm_ss(time_seconds)


## Formats seconds as `mm:ss`, rounded down. Negative values format as 00:00.
static func format_mm_ss(seconds: float) -> String:
	var whole: int = maxi(floori(seconds), 0)
	var minutes: int = floori(float(whole) / SECONDS_PER_MINUTE)
	return "%02d:%02d" % [minutes, whole % SECONDS_PER_MINUTE]
