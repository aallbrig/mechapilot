class_name TutorialPrompt
extends RefCounted
## The first-flight tutorial prompts of #73, each shown at most once.
## core/tutorial_progress.gd remembers which ones are done.

enum Id { MOVE, AIM_AND_FIRE, SHOTS_DROP, BOSS_GAUGE, REPAIR_KITS, BOSS_INCOMING }

const IDS: Array[StringName] = [
	&"move", &"aim_and_fire", &"shots_drop", &"boss_gauge", &"repair_kits", &"boss_incoming"
]


## The persisted id of a prompt.
static func id_of(prompt: Id) -> StringName:
	return IDS[prompt]
