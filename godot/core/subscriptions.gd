class_name Subscriptions
extends RefCounted
## Checks the results of a core/ class's bus connections in one place.
## Usage: Subscriptions.require_ok("Scoreboard", [a.connect(f), b.connect(g)])


## Pushes an error naming `owner_name` if any connect() result is not OK.
static func require_ok(owner_name: String, results: Array[int]) -> void:
	for result: int in results:
		if result != OK:
			push_error(
				"%s: could not subscribe to the Events bus: %s" % [owner_name, error_string(result)]
			)
