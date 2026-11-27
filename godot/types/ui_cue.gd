class_name UiCue
extends RefCounted
## The sound cues of the screens (#73: every UI element has sound). Screens
## announce one with Events.flow.announce_ui_cue_requested(); feedback/ plays it.

enum Cue {
	## A control gained focus or the pointer.
	FOCUS,
	## A button was pressed.
	CONFIRM,
	## Back, Cancel or Resume.
	BACK,
	## A toggle flipped.
	TOGGLE,
	## A slider moved.
	SLIDE,
	## An initials letter changed.
	LETTER,
	## A tally counter ticked up.
	TICK,
	## A tally finished counting.
	TALLY_DONE,
	## A highlight popped (a new Scoreboard entry, 1UP, a card).
	POP,
	## The boss WARNING banner flashed.
	WARNING,
	## The Boot screen was pressed: the game starts and audio unlocks.
	START,
}
