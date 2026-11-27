class_name FeedbackRig
extends Node3D
## All of the game's juice and audio (#26), each part a subscriber to the
## Events bus that never touches the rules (#9: rules decide, nodes report,
## feedback reacts). main.gd binds it to Events, lets it drive the engine's
## time scale and the gamepads, and connects `camera` to the camera rig.
##
##   time        TimeScaleDirector  hit-stop and slow-mo
##   camera      CameraJuice        shot kicks, shake (grows with the Combo), FOV punches
##   explosions  ExplosionPool      pooled blasts, the boss defeat chain
##   popups      ScorePopups        score and Combo pop-ups
##   muzzle      MuzzleFlashes      a flash per shot
##   overlay     ScreenOverlay      damage vignette, warning edge, desaturate
##   rumble      RumbleDirector     gamepad rumble
##   unlock      AudioUnlock        no audio before the first user gesture
##   buses       AudioBuses         Master, Music, SFX and UI volumes from Settings
##   sfx         SfxDirector        a sound for every action, low-Armor beeps, the siren
##   music       MusicDirector      title, level and boss loops, crossfades, stings
##   library     MusicLibrary       renders the songs in the background

var time: TimeScaleDirector = TimeScaleDirector.new()
var camera: CameraJuice = CameraJuice.new()
var explosions: ExplosionPool = ExplosionPool.new()
var popups: ScorePopups = ScorePopups.new()
var muzzle: MuzzleFlashes = MuzzleFlashes.new()
var overlay: ScreenOverlay = ScreenOverlay.new()
var rumble: RumbleDirector = RumbleDirector.new()
var unlock: AudioUnlock = AudioUnlock.new()
var buses: AudioBuses = AudioBuses.new()
var sfx: SfxDirector = SfxDirector.new()
var music: MusicDirector = MusicDirector.new()
var library: MusicLibrary = MusicLibrary.new()


func _init() -> void:
	for part: Node in [
		time,
		camera,
		explosions,
		popups,
		muzzle,
		overlay,
		rumble,
		unlock,
		buses,
		sfx,
		music,
		library
	]:
		add_child(part)


## Subscribe every part to `bus` (the Events autoload, or a test bus).
func bind(bus: EventBus) -> void:
	time.bind(bus)
	camera.bind(bus)
	explosions.bind(bus)
	popups.bind(bus)
	muzzle.bind(bus)
	overlay.bind(bus)
	rumble.bind(bus)
	unlock.bind(bus)
	buses.bind(bus)
	sfx.bind(bus)
	music.bind(bus, library)
	(
		BusLinks
		. require_ok(
			"FeedbackRig",
			[
				unlock.unlocked.connect(sfx.unlock),
				unlock.unlocked.connect(music.unlock),
				explosions.detonated.connect(sfx.play_blast),
			]
		)
	)


## Let the juice drive Engine.time_scale and the gamepads (the game, not tests).
func drive_engine() -> void:
	time.drive_engine()
	rumble.drive_input()


## How many audio players are sounding, music included.
func playing_count() -> int:
	var count: int = sfx.playing_count()
	for player: AudioStreamPlayer in music.players():
		if player.playing:
			count += 1
	return count
