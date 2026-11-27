class_name BusLinks
extends RefCounted
## Checks the results of a feedback director's bus connections in one place
## (feedback/ may not use core/'s Subscriptions).
## Usage: BusLinks.require_ok("SfxDirector", [a.connect(f), b.connect(g)])


## Pushes an error naming `owner_name` if any connect() result is not OK.
static func require_ok(owner_name: String, results: Array[int]) -> void:
	for result: int in results:
		if result != OK:
			push_error(
				"%s: could not subscribe to a signal: %s" % [owner_name, error_string(result)]
			)
