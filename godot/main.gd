extends Node
## The composition root: the only script that knows the concrete classes. It
## builds the core/ rules on the Events bus, binds the juice and audio
## (FeedbackRig) to the bus before the stores restore, so the restored Settings
## reach it, connects the camera juice to the camera rig, hands the player
## mech's mounts and motion to its feedback, attaches the touch controls (shown
## only on a touch screen) to the player's input, boots the Game State machine
## and ticks the rules on the fixed physics step.
## The screens (ui/) and the Title's attract mode (game/attract) are composed in
## main.tscn and hear only the Events bus; every UI sound plays through the
## FeedbackRig (flow.ui_cue_requested).
## The boot marker lets the web smoke test see the bus round trip in the browser.

const BOOT_OK_MARKER: String = "mechapilot: boot ok"

var _machine: GameStateMachine
var _ledger: RunLedger
var _progression: LevelProgression
var _director: SpawnDirector
var _scoreboard: Scoreboard
var _settings: Settings
var _intel: IntelCodex
var _tutorial: TutorialProgress

@onready var _ui: UiRoot = $Ui/UiRoot
@onready var _stage: FlightStage = $FlightStage
@onready var _mech_feedback: MechFeedback = $MechFeedback
@onready var _touch: TouchControls = $TouchControls
@onready var _feedback: FeedbackRig = $Feedback


func _ready() -> void:
	var errors: Array[String] = []
	var levels: Array[LevelDefinition] = LevelLibrary.all_levels(errors)
	for problem: String in errors:
		push_error("mechapilot: %s" % problem)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	_machine = GameStateMachine.new(Events)
	_ledger = RunLedger.new(Events)
	_progression = LevelProgression.new(Events, _machine, _ledger, BossHealth.new(Events), levels)
	_director = SpawnDirector.new(Events, rng, levels)
	_scoreboard = Scoreboard.new(Events, LocalDocumentStore.new(LocalDocumentStore.Slot.SCOREBOARD))
	_settings = Settings.new(Events, LocalDocumentStore.new(LocalDocumentStore.Slot.SETTINGS))
	_intel = IntelCodex.new(
		Events, LocalDocumentStore.new(LocalDocumentStore.Slot.INTEL), IntelCodex.catalog(levels)
	)
	_tutorial = TutorialProgress.new(LocalDocumentStore.new(LocalDocumentStore.Slot.TUTORIAL))
	# Before the stores restore, so the touch sticks hear the saved opacity.
	_touch.attach(Events, _stage.player_input(), DisplayServer.is_touchscreen_available())
	_wire_feedback()
	_settings.restore()
	_scoreboard.restore()
	_intel.restore()
	_tutorial.restore()
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


func _wire_feedback() -> void:
	_feedback.bind(Events)
	_feedback.drive_engine()
	var rig: CameraRig = _stage.camera_rig()
	_check(_feedback.camera.trauma_requested.connect(rig.add_trauma) as Error)
	_check(_feedback.camera.kick_requested.connect(rig.kick) as Error)
	_check(_feedback.camera.fov_punch_requested.connect(rig.punch_fov) as Error)


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
