extends Node
## The composition root: the only script that knows the concrete classes. It
## builds the core/ rules on the Events bus, restores the persisted stores,
## boots the Game State machine and ticks the rules on the fixed physics step.
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

@onready var _menu_screen: MenuScreen = $MenuScreen


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
	_settings.restore()
	_scoreboard.restore()
	_intel.restore()
	_tutorial.restore()
	_machine.boot()
	if _menu_screen.visible:
		print(BOOT_OK_MARKER)
	else:
		push_error("mechapilot: the Title screen did not receive game_state_changed")


func _physics_process(delta: float) -> void:
	_ledger.tick(delta)
	_progression.tick(delta)
	_director.tick(delta)
