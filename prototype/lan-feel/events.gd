extends Node
## PROTOTYPE event bus (throwaway). Gameplay emits, audio and HUD listen.

signal game_started
signal shot_fired(origin: Vector3, direction: Vector3)
signal enemy_hit(position: Vector3)
signal enemy_killed(position: Vector3, points: int, combo: int)
signal wave_started(number: int)
signal player_died(position: Vector3)
signal score_changed(score: int, combo: int)
signal life_lost(lives_left: int)
signal extra_life(lives: int)
signal ui_focus
signal ui_confirm
