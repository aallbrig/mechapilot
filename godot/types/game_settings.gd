class_name GameSettings
extends RefCounted
## The player's settings (#73, "Settings"). A plain value: core/settings.gd
## validates, persists and announces it.

const DEFAULT_VOLUME: float = 0.8
const DEFAULT_TOUCH_STICK_OPACITY: float = 0.6
const MIN_TOUCH_STICK_OPACITY: float = 0.1
const MAX_TOUCH_STICK_OPACITY: float = 1.0

## Volumes, 0.0 (mute) to 1.0 (full), for the Master, Music and SFX buses.
var master_volume: float = DEFAULT_VOLUME
var music_volume: float = DEFAULT_VOLUME
var sfx_volume: float = DEFAULT_VOLUME
## Camera shake on hits and explosions.
var screen_shake: bool = true
## Turns off shake, hit-stop, flashes and other strong motion.
var reduced_motion: bool = false
## First-flight tutorial prompts.
var tutorial_hints: bool = true
## Gamepad rumble on hits and boss kills.
var rumble: bool = true
## Opacity of the touch sticks, MIN_TOUCH_STICK_OPACITY to MAX_TOUCH_STICK_OPACITY.
var touch_stick_opacity: float = DEFAULT_TOUCH_STICK_OPACITY
## Developer mode (#116): shows the DEV button and lets backquote and gamepad
## Select open the Developer console. Off by default.
var developer_mode: bool = false


## A copy, so a holder can never change another holder's settings.
func copy() -> GameSettings:
	var other: GameSettings = GameSettings.new()
	other.master_volume = master_volume
	other.music_volume = music_volume
	other.sfx_volume = sfx_volume
	other.screen_shake = screen_shake
	other.reduced_motion = reduced_motion
	other.tutorial_hints = tutorial_hints
	other.rumble = rumble
	other.touch_stick_opacity = touch_stick_opacity
	other.developer_mode = developer_mode
	return other


## A copy with every value forced into its legal range.
func clamped() -> GameSettings:
	var other: GameSettings = copy()
	other.master_volume = clampf(master_volume, 0.0, 1.0)
	other.music_volume = clampf(music_volume, 0.0, 1.0)
	other.sfx_volume = clampf(sfx_volume, 0.0, 1.0)
	other.touch_stick_opacity = clampf(
		touch_stick_opacity, MIN_TOUCH_STICK_OPACITY, MAX_TOUCH_STICK_OPACITY
	)
	return other


## True when both hold the same values.
func equals(other: GameSettings) -> bool:
	return (
		is_equal_approx(master_volume, other.master_volume)
		and is_equal_approx(music_volume, other.music_volume)
		and is_equal_approx(sfx_volume, other.sfx_volume)
		and screen_shake == other.screen_shake
		and reduced_motion == other.reduced_motion
		and tutorial_hints == other.tutorial_hints
		and rumble == other.rumble
		and is_equal_approx(touch_stick_opacity, other.touch_stick_opacity)
		and developer_mode == other.developer_mode
	)
