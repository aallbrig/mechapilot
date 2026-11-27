class_name TouchSticks
extends RefCounted
## The touch rules (#25, the owner's direction in #25 and #73 Controls), free of
## drawing and of the clock: feed it touches with their times, read the sticks.
##
## - Each touch is tracked by its index, independently. At most one finger owns
##   each stick; other fingers are ignored until it lifts.
## - Left half (touch-down x below `split_x`): a move stick anchored at the
##   touch-down point. It never fires, even when the finger crosses the middle.
## - Right half: undecided at first, and nothing fires. Released within
##   TAP_TIME and TAP_SLOP of travel, it is a tap: one shot at the tapped point
##   (take_taps). Held past TAP_TIME, or dragged past TAP_SLOP, it becomes the
##   aim stick, anchored at the touch-down point: aim() is the drag from the
##   anchor, never the finger's position. PlayerInput fires along it once it
##   is past its dead zone (PlayerInput.TOUCH_AIM_THRESHOLD).
## - A cancelled touch (the OS took it) ends its stick and is never a tap.
##
## Directions are in world terms (x right, y up); positions in screen pixels.

## A right-half touch shorter than this (s) and moving less than TAP_SLOP (px) is a tap.
const TAP_TIME: float = 0.18
const TAP_SLOP: float = 12.0
## Finger travel (px) for a full stick.
const STICK_RANGE: float = 70.0
const NO_TOUCH: int = -1

## Screen x that splits the move half (left) from the aim half (right).
var split_x: float = 0.0

var _move: Stick = Stick.new()
var _aim: Stick = Stick.new()
var _aim_started: float = 0.0
var _aim_travel: float = 0.0
var _aim_holding: bool = false
var _taps: Array[Vector2] = []


## A finger touched down at `at` (time `now`).
func press(index: int, at: Vector2, now: float) -> void:
	if _move.index == index or _aim.index == index:
		return
	if at.x < split_x:
		if not _move.is_held():
			_move.grab(index, at)
	elif not _aim.is_held():
		_aim.grab(index, at)
		_aim_started = now
		_aim_travel = 0.0
		_aim_holding = false


## A tracked finger moved to `to`.
func drag(index: int, to: Vector2, now: float) -> void:
	if index == _move.index:
		_move.finger = to
	elif index == _aim.index:
		_aim.finger = to
		_aim_travel = maxf(_aim_travel, to.distance_to(_aim.anchor))
		update(now)


## A finger lifted at `at`. A quick, short aim touch queues a tap at its
## touch-down point.
func release(index: int, at: Vector2, now: float, cancelled: bool = false) -> void:
	if index == _move.index:
		_move.drop()
	elif index == _aim.index:
		_aim_travel = maxf(_aim_travel, at.distance_to(_aim.anchor))
		update(now)
		if not _aim_holding and not cancelled:
			_taps.append(_aim.anchor)
		_aim.drop()
		_aim_holding = false


## Let time pass: an aim touch held past TAP_TIME becomes the aim stick.
func update(now: float) -> void:
	if not _aim.is_held() or _aim_holding:
		return
	if now - _aim_started >= TAP_TIME or _aim_travel >= TAP_SLOP:
		_aim_holding = true


## Forget every touch (leaving play, or the controls switched off).
func reset() -> void:
	_move.drop()
	_aim.drop()
	_aim_holding = false
	_taps.clear()


## The move stick, length at most 1 (zero when not held).
func move() -> Vector2:
	return _move.vector()


## The aim stick, length at most 1. Zero until the aim touch is a hold.
func aim() -> Vector2:
	return _aim.vector() if _aim_holding else Vector2.ZERO


## The taps since the last call, in screen pixels, oldest first.
func take_taps() -> Array[Vector2]:
	var out: Array[Vector2] = _taps.duplicate()
	_taps.clear()
	return out


func is_move_held() -> bool:
	return _move.is_held()


## True once the aim touch has become a hold (the aim stick is open).
func is_aim_holding() -> bool:
	return _aim.is_held() and _aim_holding


## True while `index` owns a stick.
func is_tracking(index: int) -> bool:
	return index != NO_TOUCH and (index == _move.index or index == _aim.index)


func move_stick() -> Stick:
	return _move


func aim_stick() -> Stick:
	return _aim


## One virtual stick: the finger that owns it, where it touched down, and where it is.
class Stick:
	extends RefCounted

	var index: int = NO_TOUCH
	var anchor: Vector2 = Vector2.ZERO
	var finger: Vector2 = Vector2.ZERO

	func is_held() -> bool:
		return index != NO_TOUCH

	func grab(by: int, at: Vector2) -> void:
		index = by
		anchor = at
		finger = at

	func drop() -> void:
		index = NO_TOUCH

	## The drag from the anchor in screen pixels, capped at STICK_RANGE.
	func offset() -> Vector2:
		return (finger - anchor).limit_length(STICK_RANGE)

	## The drag in world terms (y up), length at most 1; zero when not held.
	func vector() -> Vector2:
		if not is_held():
			return Vector2.ZERO
		var drag: Vector2 = offset() / STICK_RANGE
		return Vector2(drag.x, -drag.y)
