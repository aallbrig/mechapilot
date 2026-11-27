class_name DevCommands
extends RefCounted
## Carries out the Developer console's commands (#116) through the same rule
## APIs gameplay uses: RunLedger for score, Armor, lives and invulnerability;
## LevelProgression for the Boss Gauge and Level skips; and an order to game/
## for "kill all enemies", which destroys them through the enemy field's own
## shot-kill path, so the ledger scores them as it scores any kill.
##
## Commands are ignored unless Developer mode is on (the last
## profile.settings_changed). Commands that change a Run need one in play
## (Level Intro to Boss Fight, not paused) and mark it dev-assisted, so it is
## never saved to the Scoreboard. Developer invulnerability may be toggled at
## any time; a Run started with it on is dev-assisted from the start.
##
## Listens: dev.dev_command_requested, profile.settings_changed, run.run_started.
## Announces: dev.dev_status_changed (after every accepted command and at each
## Run start) and dev.enemies_purge_ordered.

## Points the ADD_SCORE command awards.
const SCORE_BONUS: int = 1000

var _events: EventBus
var _machine: GameStateMachine
var _ledger: RunLedger
var _progression: LevelProgression
var _enabled: bool = false
var _invulnerable: bool = false


func _init(
	events: EventBus, machine: GameStateMachine, ledger: RunLedger, progression: LevelProgression
) -> void:
	_events = events
	_machine = machine
	_ledger = ledger
	_progression = progression
	var subscribed: Array[int] = [
		_events.dev.dev_command_requested.connect(run_command),
		_events.profile.settings_changed.connect(_on_settings_changed),
		_events.run.run_started.connect(_on_run_started),
	]
	Subscriptions.require_ok("DevCommands", subscribed)


## True while Developer mode is on.
func is_enabled() -> bool:
	return _enabled


## Carries out `command`. Returns true when it changed anything.
func run_command(command: DevCommand.Command) -> bool:
	if not _enabled:
		return false
	var done: bool = false
	if command == DevCommand.Command.TOGGLE_INVULNERABILITY:
		_invulnerable = _ledger.toggle_dev_invulnerability()
		done = true
	elif _in_play():
		done = _run_command(command)
	if done:
		_announce_status()
	return done


func _run_command(command: DevCommand.Command) -> bool:
	var done: bool = true
	match command:
		DevCommand.Command.ADD_SCORE:
			_ledger.award_points(SCORE_BONUS)
		DevCommand.Command.ADD_LIFE:
			_ledger.award_life()
		DevCommand.Command.RESTORE_ARMOR:
			done = _ledger.restore_armor()
		DevCommand.Command.FILL_BOSS_GAUGE:
			done = _progression.fill_boss_gauge()
		DevCommand.Command.SKIP_LEVEL:
			# Marked first: the skip may end the Run (Victory), and its summary
			# must already carry the mark.
			_ledger.mark_dev_assisted()
			done = _progression.skip_level()
		DevCommand.Command.KILL_ALL_ENEMIES:
			_events.dev.announce_enemies_purge_ordered()
		_:
			done = false
	if done:
		_ledger.mark_dev_assisted()
	return done


func _in_play() -> bool:
	return _progression.is_run_active() and GameState.is_play(_machine.state())


func _announce_status() -> void:
	_events.dev.announce_dev_status_changed(
		_invulnerable, _progression.is_run_active() and _ledger.is_dev_assisted()
	)


func _on_settings_changed(settings: GameSettings) -> void:
	_enabled = settings.developer_mode


func _on_run_started(_level_number: int) -> void:
	_announce_status()
