class_name GameState
extends RefCounted
## The Game State: the phase the game is in (see GLOSSARY.md and #73).
## A shared value type in types/, so the Events bus, core/ rules and screens
## all name the same typed enum instead of passing untyped values.
## The legal transitions between phases live in core/game_state_machine.gd.

enum Phase {
	BOOT,
	TITLE,
	LEVEL_INTRO,
	SKIRMISH,
	BOSS_WARNING,
	BOSS_FIGHT,
	LEVEL_CLEAR,
	PAUSED,
	GAME_OVER,
	VICTORY,
	SCOREBOARD,
}


## True for the phases of active play: the only phases that may be paused.
static func is_play(phase: Phase) -> bool:
	return (
		phase == Phase.LEVEL_INTRO
		or phase == Phase.SKIRMISH
		or phase == Phase.BOSS_WARNING
		or phase == Phase.BOSS_FIGHT
	)


## True for the phases in which the player can be hit, score and spend Run time:
## play without the Level Intro card.
static func is_timed(phase: Phase) -> bool:
	return phase == Phase.SKIRMISH or phase == Phase.BOSS_WARNING or phase == Phase.BOSS_FIGHT
