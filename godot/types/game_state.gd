class_name GameState
extends RefCounted
## The Game State: the phase the game is in (see GLOSSARY.md).
## A shared value type in types/, so the Events bus, core/ rules and screens
## all name the same typed enum instead of passing untyped values.

enum Phase { MENU, GAMEPLAY, GAME_OVER, SCOREBOARD }
