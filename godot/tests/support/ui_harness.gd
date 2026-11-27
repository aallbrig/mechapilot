class_name UiHarness
extends RefCounted
## Test support: the real screens (ui/ui_root.tscn) on a private Events bus,
## wired to the real core/ rules of a Run (RunHarness) and to in-memory
## Scoreboard and Settings stores, inside a host Control of a chosen size.
## The suite adds `host` to the tree, and calls dispose() at the end.

## Phone portrait, the narrowest layout (640 UI pixels wide, see project.godot).
const PORTRAIT: Vector2 = Vector2(640.0, 1138.0)
## 16:9 landscape: 1080p and 4K both map to this.
const LANDSCAPE: Vector2 = Vector2(1138.0, 640.0)

var run: RunHarness = RunHarness.new()
var bus: EventBus = run.bus
var scoreboard_store: MemoryDocumentStore = MemoryDocumentStore.new()
var settings_store: MemoryDocumentStore = MemoryDocumentStore.new()
var scoreboard: Scoreboard = Scoreboard.new(bus, scoreboard_store)
var settings: Settings = Settings.new(bus, settings_store)
var host: Control = Control.new()
var ui: UiRoot = (load("res://ui/ui_root.tscn") as PackedScene).instantiate() as UiRoot
## Every UI cue announced, in order.
var cues: Array[UiCue.Cue] = []
var _reduced_motion: bool = true


func _init(host_size: Vector2 = LANDSCAPE, reduced_motion: bool = true) -> void:
	_reduced_motion = reduced_motion
	TweenFx.reduced_motion = reduced_motion
	host.size = host_size
	ui.use_bus(bus)
	host.add_child(ui)
	var ok: bool = bus.flow.ui_cue_requested.connect(_on_cue) == OK
	if not ok:
		push_error("UiHarness: could not hear ui cues")


## Restores the stores and boots, as main.gd does (Boot is shown). Call after
## the host is in the tree.
func boot() -> void:
	settings.restore()
	if _reduced_motion:
		bus.profile.announce_settings_change_requested(_reduced(settings.current()))
	scoreboard.restore()
	run.machine.boot()


## Boot, then press start (the Title is shown).
func reach_title() -> void:
	boot()
	bus.flow.announce_start_requested()


## The screen named `screen_name`.
func screen(screen_name: StringName) -> UiScreen:
	return ui.screen(screen_name)


## Plays a Run to Game Over with `kills` Fighter kills first (0 scores nothing).
func reach_game_over(kills: int) -> void:
	run.reach_skirmish()
	for i: int in kills:
		var _points: int = run.kill(EnemyKind.Kind.FIGHTER)
		run.advance(RunRules.COMBO_WINDOW + RunHarness.STEP)
	var guard: int = 0
	while run.ledger.lives() > 0 and guard < 10:
		run.lose_life()
		guard += 1
	run.advance(run.levels[0].game_over_delay + RunHarness.STEP)


## Frees the screens, the host and the bus. Call once at the end of every test.
func dispose() -> void:
	host.free()
	run.dispose()
	TweenFx.reduced_motion = false


func _reduced(current: GameSettings) -> GameSettings:
	var wanted: GameSettings = current.copy()
	wanted.reduced_motion = true
	return wanted


func _on_cue(cue: UiCue.Cue) -> void:
	cues.append(cue)
