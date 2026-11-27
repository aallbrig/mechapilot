class_name UiScreen
extends Control
## The base of every screen. A screen builds its controls in _ready(), then
## UiRoot binds it to the Events bus (bind()), and shows and hides it with
## enter() and leave() as the Game State changes. A screen only ever hears
## Events and announces intents: it never calls the rules.
##
## bind() juices every focusable control and button the screen has built
## (ControlJuice: hover, focus and press with sound); a control built later
## is juiced with juice().

## Ask UiRoot to open a sub-screen (Settings, Credits, ...) on top of this one.
signal navigate_requested(target: StringName)
## Ask UiRoot to close this sub-screen and return to the one below.
signal back_requested

const ENTER_OFFSET: Vector2 = Vector2(0.0, 48.0)
const ITEM_STAGGER: float = 0.05

var _bus: EventBus
var _device: InputDevice.Kind = InputDevice.Kind.KEYBOARD
var _juices: Array[ControlJuice] = []


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Connects the screen to `bus` and juices its controls. Called once by UiRoot.
func bind(bus: EventBus) -> void:
	_bus = bus
	_subscribe()
	juice_tree(self)


## Shows the screen with its entrance and focuses its default control.
func enter() -> void:
	visible = true
	position = Vector2.ZERO
	_on_enter()
	TweenFx.slide_in(self, ENTER_OFFSET)
	focus_default()


## Hides the screen and drops any focus inside it.
func leave() -> void:
	for each: ControlJuice in _juices:
		if each.target().has_focus():
			each.target().release_focus()
	visible = false
	position = Vector2.ZERO
	_on_leave()


## Gives focus to the default control, if the screen has one.
func focus_default() -> void:
	var target: Control = default_focus()
	if target != null and target.is_visible_in_tree():
		target.grab_focus()


## The control keyboard and gamepad focus starts on (null: none).
func default_focus() -> Control:
	return null


## Back or Cancel was pressed while this screen is on top. Returns true when
## the screen handled it.
func handle_cancel() -> bool:
	return false


## The player switched devices: update prompts.
func set_device(device: InputDevice.Kind) -> void:
	_device = device
	_on_device_changed()


## Every juiced control, in the order it was juiced.
func juiced_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for each: ControlJuice in _juices:
		controls.append(each.target())
	return controls


## Juices `control` (hover, focus and press with sound).
func juice(control: Control, press_cue: UiCue.Cue = UiCue.Cue.CONFIRM) -> void:
	for existing: ControlJuice in _juices:
		if existing.target() == control:
			return
	var made: ControlJuice = ControlJuice.attach(control, press_cue)
	if made.cued.connect(cue) != OK:
		push_error("%s: could not hear the juice of %s" % [name, control.name])
	_juices.append(made)


## Juices every focusable control and button under `root`.
func juice_tree(root: Node) -> void:
	for child: Node in root.get_children():
		if (
			child is BaseButton
			or (child is Control and (child as Control).focus_mode != FOCUS_NONE)
		):
			juice(child as Control)
		juice_tree(child)


## Asks UiRoot to open the sub-screen `target` (see UiRoot.SUB_SCREENS).
func request_navigate(target: StringName) -> void:
	navigate_requested.emit(target)


## Asks UiRoot to close this sub-screen.
func request_back() -> void:
	back_requested.emit()


## Announces a UI sound cue.
func cue(which: UiCue.Cue) -> void:
	if _bus != null:
		_bus.flow.announce_ui_cue_requested(which)


## Pops `items` in one after another (the screen's entrance).
func stagger_in(items: Array[Control]) -> void:
	for i: int in items.size():
		TweenFx.pop(items[i], TweenFx.POP_FROM, TweenFx.POP_TIME, ITEM_STAGGER * i)


## Connect to the bus here (called once by bind()).
func _subscribe() -> void:
	pass


## Called by enter() before the entrance plays.
func _on_enter() -> void:
	pass


## Called by leave().
func _on_leave() -> void:
	pass


## Called when the device changes.
func _on_device_changed() -> void:
	pass


## Reports a failed bus connection; returns true when all of them succeeded.
func _require(results: Array[int]) -> bool:
	for result: int in results:
		if result != OK:
			push_error("%s: could not subscribe: %s" % [name, error_string(result)])
			return false
	return true
