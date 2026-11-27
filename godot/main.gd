class_name Main
extends Node
## The composition root: the only script that knows the concrete classes. It
## builds the core/ rules on the Events bus, binds the juice and audio
## (FeedbackRig) to the bus before the stores restore, so the restored Settings
## reach it, connects the camera juice to the camera rig, hands the stage's
## mech, shots and camera to the fight (game/run), hands the player mech's
## mounts and motion to its feedback, attaches the touch controls (shown only on
## a touch screen) to the player's input, boots the Game State machine and ticks
## the rules on the fixed physics step.
## The screens (ui/) and the Title's attract mode (game/attract) are composed in
## main.tscn and hear only the Events bus; every UI sound plays through the
## FeedbackRig (flow.ui_cue_requested).
## The boot marker lets the web smoke test see the bus round trip in the browser.

const BOOT_OK_MARKER: String = "mechapilot: boot ok"

## True: every persisted store is kept in memory instead of user://. Tests
## that play the whole game set it before the scene enters the tree, so a
## playthrough never reads or writes a real Scoreboard, Settings or Intel.
var memory_stores: bool = false
## A seed for the rules' and the fight's random decisions (spawns, enemy speeds), or -1 for a random
## one. Tests set it before the scene enters the tree, so a run can be replayed.
var rng_seed: int = -1
## True: attach the touch controls as on a touch screen, whatever the display
## reports (a headless test has none). Tests set it before the scene enters the tree.
var touch_screen: bool = false

var _machine: GameStateMachine
var _ledger: RunLedger
var _progression: LevelProgression
var _director: SpawnDirector
var _scoreboard: Scoreboard
var _settings: Settings
var _intel: IntelCodex
var _tutorial: TutorialProgress
var _coach: TutorialCoach
var _dev: DevCommands

@onready var _ui: UiRoot = $Ui/UiRoot
@onready var _stage: FlightStage = $FlightStage
@onready var _run: RunDirector = $Run
@onready var _mech_feedback: MechFeedback = $MechFeedback
@onready var _touch: TouchControls = $TouchControls
@onready var _feedback: FeedbackRig = $Feedback


func _ready() -> void:
	var errors: Array[String] = []
	var levels: Array[LevelDefinition] = LevelLibrary.all_levels(errors)
	for problem: String in errors:
		push_error("mechapilot: %s" % problem)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	_machine = GameStateMachine.new(Events)
	_ledger = RunLedger.new(Events)
	_progression = LevelProgression.new(Events, _machine, _ledger, BossHealth.new(Events), levels)
	_director = SpawnDirector.new(Events, rng, levels)
	_scoreboard = Scoreboard.new(Events, _store(LocalDocumentStore.Slot.SCOREBOARD))
	_settings = Settings.new(Events, _store(LocalDocumentStore.Slot.SETTINGS))
	_intel = IntelCodex.new(
		Events,
		_store(LocalDocumentStore.Slot.INTEL),
		IntelCodex.catalog(levels),
		IntelCodex.entries_for(levels)
	)
	_tutorial = TutorialProgress.new(_store(LocalDocumentStore.Slot.TUTORIAL))
	# Before the stores restore, so the touch sticks hear the saved opacity.
	_touch.attach(
		Events, _stage.player_input(), touch_screen or DisplayServer.is_touchscreen_available()
	)
	_wire_feedback()
	_coach = TutorialCoach.new(Events, _tutorial)
	# Before the restore, so a saved Developer mode reaches it (#116).
	_dev = DevCommands.new(Events, _machine, _ledger, _progression)
	_settings.restore()
	_scoreboard.restore()
	_intel.restore()
	_tutorial.restore()
	_stage.use_levels(levels)
	_run.setup(Events, rng, levels, _stage.player(), _stage.shots(), _stage.camera_rig().camera())
	_wire_mech_feedback()
	_machine.boot()
	if _ui.visible_screens() == [&"Boot"]:
		print(BOOT_OK_MARKER)
	else:
		push_error("mechapilot: the Boot screen did not receive game_state_changed")


func _physics_process(delta: float) -> void:
	_ledger.tick(delta)
	_progression.tick(delta)
	_director.tick(delta)
	_coach.tick(delta)


func _wire_feedback() -> void:
	_feedback.bind(Events)
	# Movie Maker renders at a fixed FPS: hit-stop and slow-mo count frames.
	_feedback.time.fixed_frames = Engine.get_write_movie_path() != ""
	_feedback.drive_engine()
	_check(_run.field().enemy_telegraphed.connect(_feedback.sfx.play_charge) as Error)
	var rig: CameraRig = _stage.camera_rig()
	_check(_feedback.camera.trauma_requested.connect(rig.add_trauma) as Error)
	_check(_feedback.camera.kick_requested.connect(rig.kick) as Error)
	_check(_feedback.camera.fov_punch_requested.connect(rig.punch_fov) as Error)


func _store(slot: LocalDocumentStore.Slot) -> DocumentStore:
	if memory_stores:
		return MemoryDocumentStore.new()
	return LocalDocumentStore.new(slot)


func _wire_mech_feedback() -> void:
	var player: PlayerMech = _stage.player()
	var model: MechModel = player.model()
	_mech_feedback.attach(
		model.main_nozzles,
		MechModel.WING_FLAME_SIZE,
		model.foot_nozzles,
		MechModel.FOOT_FLAME_SIZE,
		model.eyes
	)
	_check(player.motion_sampled.connect(_mech_feedback.on_motion) as Error)
	_check(player.destroyed.connect(_mech_feedback.on_destroyed.unbind(1)) as Error)
	_check(player.respawned.connect(_mech_feedback.on_respawned.unbind(1)) as Error)


func _check(err: Error) -> void:
	if err != OK:
		push_error("mechapilot: could not wire a signal: %s" % error_string(err))
