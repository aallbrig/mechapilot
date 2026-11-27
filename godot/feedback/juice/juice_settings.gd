class_name JuiceSettings
extends RefCounted
## What the player's settings allow the juice to do. One place decides, so every
## director reads "reduced motion" and the toggles the same way (#26, #73):
##
##   camera motion   shake, kicks and FOV punches: the shake toggle, and never
##                   with reduced motion
##   hit-stop        never with reduced motion
##   flashes         strobing and pulsing overlays: never with reduced motion
##   rumble          the rumble toggle


static func camera_motion(settings: GameSettings) -> bool:
	return settings.screen_shake and not settings.reduced_motion


static func hitstop(settings: GameSettings) -> bool:
	return not settings.reduced_motion


static func flashes(settings: GameSettings) -> bool:
	return not settings.reduced_motion


static func rumble(settings: GameSettings) -> bool:
	return settings.rumble
