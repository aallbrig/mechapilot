class_name DevCommand
extends RefCounted
## The Developer console's commands that act on a Run (#116). The console
## announces one with `Events.dev.dev_command_requested`; core/DevCommands
## carries it out through the same rule APIs gameplay uses. There is no
## free-text command: this list is the whole vocabulary.

enum Command {
	TOGGLE_INVULNERABILITY,
	ADD_SCORE,
	FILL_BOSS_GAUGE,
	SKIP_LEVEL,
	KILL_ALL_ENEMIES,
	RESTORE_ARMOR,
	ADD_LIFE,
}
