extends GdUnitTestSuite
## PlayerBusLink: the mech and its input report to the Events bus, and react to
## the RunLedger's decisions (#21's catalog). Each test uses its own bus.

const TICK: float = 1.0 / 60.0

var _bus: EventBus
var _mech: PlayerMech
var _input: PlayerInput
var _link: PlayerBusLink
var _fired: Array[Vector3] = []
var _hits: Array[DamageSource.Source] = []
var _repairs: Array[Vector3] = []
var _devices: Array[InputDevice.Kind] = []


func before_test() -> void:
	_fired.clear()
	_hits.clear()
	_repairs.clear()
	_devices.clear()
	_bus = EventBus.new()
	_mech = PlayerMech.new()
	_mech.tuning.shot_spread = 0.0
	add_child(_mech)
	_input = PlayerInput.new()
	add_child(_input)
	_link = PlayerBusLink.new()
	add_child(_link)
	_link.link(_bus, _mech, _input)


func after_test() -> void:
	_link.free()
	_input.free()
	_mech.free()
	_bus.free()


func _on_fired(_origin: Vector3, direction: Vector3) -> void:
	_fired.append(direction)


func _on_hit(source: DamageSource.Source, _position: Vector3, _attack_damage: int) -> void:
	_hits.append(source)


func _on_repair(position: Vector3) -> void:
	_repairs.append(position)


func _on_device(device: InputDevice.Kind) -> void:
	_devices.append(device)


func _firing() -> PilotIntent:
	var intent: PilotIntent = PilotIntent.new()
	intent.aim = Vector2.RIGHT
	intent.firing = true
	return intent


func test_bus_link_announces_shots_hits_and_repairs() -> void:
	var subscribed: Array[int] = [
		_bus.player.player_fired.connect(_on_fired),
		_bus.player.player_hit.connect(_on_hit),
		_bus.player.repair_collected.connect(_on_repair),
	]
	_mech.tick(TICK, _firing())
	var _hit: bool = _mech.take_hit(DamageSource.Source.BOMB, Vector3.LEFT)
	_mech.position = Vector3(1.0, 2.0, 0.0)
	_mech.repair()
	var _linked: GdUnitAssert = assert_int(_link.error_count()).is_equal(0)
	var _connected: GdUnitAssert = assert_int(subscribed.count(OK)).is_equal(3)
	var _shot: GdUnitAssert = assert_array(_fired).is_equal([Vector3.RIGHT])
	var _reported_hit: GdUnitAssert = assert_array(_hits).is_equal([DamageSource.Source.BOMB])
	var _repair: GdUnitAssert = assert_array(_repairs).is_equal([Vector3(1.0, 2.0, 0.0)])


func test_bus_link_announces_the_last_used_device() -> void:
	var err: Error = _bus.flow.input_device_changed.connect(_on_device) as Error
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	_input.handle_event(pad, 10.0)
	_input.handle_event(pad, 10.1)
	var _connected: GdUnitAssert = assert_int(err).is_equal(OK)
	var _once: GdUnitAssert = assert_array(_devices).is_equal([InputDevice.Kind.GAMEPAD])


func test_linked_mech_lets_the_ledger_decide_hits() -> void:
	var _hit: bool = _mech.take_hit(DamageSource.Source.ENEMY_BULLET, Vector3.LEFT)
	var flash_before_decision: bool = _mech.model().is_flashing()
	var guarded_before_decision: bool = _mech.is_invulnerable()
	_bus.player.announce_armor_changed(90, 100, -10)
	var flash_after_loss: bool = _mech.model().is_flashing()
	_bus.player.announce_invulnerability_started(RunRules.HIT_INVULNERABILITY)
	var blocked: bool = not _mech.take_hit(DamageSource.Source.ENEMY_BULLET, Vector3.LEFT)
	_bus.player.announce_invulnerability_ended()
	var open_again: bool = _mech.take_hit(DamageSource.Source.ENEMY_BULLET, Vector3.LEFT)
	var _waits: GdUnitAssert = (
		assert_bool(flash_before_decision or guarded_before_decision).is_false()
	)
	var _reacts: GdUnitAssert = assert_bool(flash_after_loss).is_true()
	var _guarded: GdUnitAssert = assert_bool(blocked).is_true()
	var _open: GdUnitAssert = assert_bool(open_again).is_true()


func test_armor_gain_is_not_a_hit_reaction() -> void:
	_bus.player.announce_armor_changed(100, 100, 30)
	var _no_flash: GdUnitAssert = assert_bool(_mech.model().is_flashing()).is_false()


func test_ledger_destroys_and_respawns_the_mech_where_it_fell() -> void:
	_mech.position = Vector3(6.0, -3.0, 0.0)
	_bus.player.announce_player_destroyed(_mech.position, DestroyCause.Cause.SHOT)
	var down: bool = not _mech.is_alive()
	_bus.player.announce_player_respawned()
	var back: bool = _mech.is_alive()
	var at: Vector3 = _mech.position
	var _down: GdUnitAssert = assert_bool(down).is_true()
	var _back: GdUnitAssert = assert_bool(back).is_true()
	var _where: GdUnitAssert = assert_vector(at).is_equal(Vector3(6.0, -3.0, 0.0))


func test_run_start_puts_the_mech_at_the_origin() -> void:
	_mech.position = Vector3(20.0, 9.0, 0.0)
	_bus.run.announce_run_started(1)
	var _origin: GdUnitAssert = assert_vector(_mech.position).is_equal(PlayerBusLink.RUN_START)
	var _alive: GdUnitAssert = assert_bool(_mech.is_alive()).is_true()


func test_mech_hit_costs_ledger_armor_and_starts_its_window() -> void:
	var ledger: RunLedger = RunLedger.new(_bus)
	ledger.start_run()
	_bus.flow.announce_game_state_changed(GameState.Phase.SKIRMISH, GameState.Phase.SKIRMISH)
	var full: int = ledger.armor()
	var _hit: bool = _mech.take_hit(DamageSource.Source.ENEMY_BULLET, Vector3.LEFT)
	var after_hit: int = ledger.armor()
	var guarded: bool = _mech.is_invulnerable() and ledger.is_invulnerable()
	var flashed: bool = _mech.model().is_flashing()
	var blocked: bool = not _mech.take_hit(DamageSource.Source.ENEMY_BULLET, Vector3.LEFT)
	var _cost: GdUnitAssert = assert_int(full - after_hit).is_equal(
		RunRules.damage_for(DamageSource.Source.ENEMY_BULLET, 0)
	)
	var _guarded: GdUnitAssert = assert_bool(guarded).is_true()
	var _flashed: GdUnitAssert = assert_bool(flashed).is_true()
	var _blocked: GdUnitAssert = assert_bool(blocked).is_true()


func test_collected_repair_kit_restores_ledger_armor() -> void:
	var ledger: RunLedger = RunLedger.new(_bus)
	ledger.start_run()
	_bus.flow.announce_game_state_changed(GameState.Phase.SKIRMISH, GameState.Phase.SKIRMISH)
	var _hit: bool = _mech.take_hit(DamageSource.Source.ENEMY_COLLISION, Vector3.LEFT)
	var hurt: int = ledger.armor()
	var kit: RepairKit = RepairKit.new()
	add_child(kit)
	kit.collector = _mech
	kit.position = _mech.position
	kit.step(TICK)
	var healed: int = ledger.armor()
	kit.free()
	var _restored: GdUnitAssert = assert_int(healed).is_equal(
		mini(hurt + RunRules.REPAIR_ARMOR, RunRules.MAX_ARMOR)
	)
	var _was_hurt: GdUnitAssert = assert_int(hurt).is_less(RunRules.MAX_ARMOR)
