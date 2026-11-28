class_name Settings
extends RefCounted
## The player's settings (#73), persisted through a DocumentStore. A stored
## field that is missing or mistyped falls back to its default on its own, so
## one bad value never resets the rest.
##
## Listens: profile.settings_change_requested (clamped, saved, announced) and
## profile.settings_reset_requested (defaults, saved, announced).
## Announces: profile.settings_changed (on restore(), change and reset).

const DOCUMENT_VERSION: int = 1

var _events: EventBus
var _store: DocumentStore
var _current: GameSettings = GameSettings.new()


func _init(events: EventBus, store: DocumentStore) -> void:
	_events = events
	_store = store
	var subscribed: Array[int] = [
		_events.profile.settings_change_requested.connect(apply),
		_events.profile.settings_reset_requested.connect(reset),
	]
	Subscriptions.require_ok("Settings", subscribed)


## Reads the stored settings and announces them.
func restore() -> void:
	_current = _parse(_store.read_document())
	_events.profile.announce_settings_changed(current())


## A copy of the settings in effect.
func current() -> GameSettings:
	return _current.copy()


## Clamps `settings` into range, saves and announces them.
func apply(settings: GameSettings) -> void:
	_current = settings.clamped()
	_save()


## Restores every default, saves and announces them.
func reset() -> void:
	_current = GameSettings.new()
	_save()


func _save() -> void:
	if not _store.write_document(_serialize(_current)):
		push_warning("Settings: could not be saved")
	_events.profile.announce_settings_changed(current())


static func _serialize(settings: GameSettings) -> Dictionary:
	return {
		"version": DOCUMENT_VERSION,
		"master_volume": settings.master_volume,
		"music_volume": settings.music_volume,
		"sfx_volume": settings.sfx_volume,
		"screen_shake": settings.screen_shake,
		"reduced_motion": settings.reduced_motion,
		"tutorial_hints": settings.tutorial_hints,
		"rumble": settings.rumble,
		"touch_stick_opacity": settings.touch_stick_opacity,
		"developer_mode": settings.developer_mode,
	}


static func _parse(document: Dictionary) -> GameSettings:
	var defaults: GameSettings = GameSettings.new()
	var parsed: GameSettings = GameSettings.new()
	parsed.master_volume = _number(document, "master_volume", defaults.master_volume)
	parsed.music_volume = _number(document, "music_volume", defaults.music_volume)
	parsed.sfx_volume = _number(document, "sfx_volume", defaults.sfx_volume)
	parsed.screen_shake = _flag(document, "screen_shake", defaults.screen_shake)
	parsed.reduced_motion = _flag(document, "reduced_motion", defaults.reduced_motion)
	parsed.tutorial_hints = _flag(document, "tutorial_hints", defaults.tutorial_hints)
	parsed.rumble = _flag(document, "rumble", defaults.rumble)
	parsed.touch_stick_opacity = _number(
		document, "touch_stick_opacity", defaults.touch_stick_opacity
	)
	parsed.developer_mode = _flag(document, "developer_mode", defaults.developer_mode)
	return parsed.clamped()


static func _number(document: Dictionary, key: String, fallback: float) -> float:
	if document.has(key) and (document[key] is float or document[key] is int):
		var value: float = document[key]
		return value if is_finite(value) else fallback
	return fallback


static func _flag(document: Dictionary, key: String, fallback: bool) -> bool:
	if document.has(key) and document[key] is bool:
		var value: bool = document[key]
		return value
	return fallback
