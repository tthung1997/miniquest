class_name HeroBuffs
extends RefCounted
## The timed statuses on a hero, such as Bulwark's damage reduction.
##
## Each status has a magnitude and a time left. Applying one that is already
## running replaces it, so recasting refreshes rather than stacks. What a
## magnitude means belongs to whoever reads it; the readers are in Hero.

## Status `id` is over: it ran out, was consumed, or was cleared. Not emitted when
## applying replaces a running one.
signal ended(id: StringName)

const BULWARK: StringName = &"bulwark"
const SWIFT_STEP: StringName = &"swift_step"
const BLOOD_FRENZY: StringName = &"blood_frenzy"
const ARCANE_SURGE: StringName = &"arcane_surge"
const VANISH: StringName = &"vanish"
const FLAME_BRAND: StringName = &"flame_brand"
const RIPOSTE: StringName = &"riposte"

var _magnitude: Dictionary[StringName, float] = {}
var _left: Dictionary[StringName, float] = {}


## Give status `id` at `magnitude` for `duration` seconds.
func apply(id: StringName, magnitude: float, duration: float) -> void:
	if duration <= 0.0:
		return
	_magnitude[id] = magnitude
	_left[id] = duration


## Count every status down by `delta` seconds, dropping the ones that ran out.
func tick(delta: float) -> void:
	for id: StringName in _left.keys():
		_left[id] -= delta
		if _left[id] <= 0.0:
			_end(id)


func is_active(id: StringName) -> bool:
	return _left.has(id)


## The magnitude of status `id`, or zero when it is not running.
func magnitude(id: StringName) -> float:
	return _magnitude.get(id, 0.0)


## Seconds left of status `id`, or zero.
func remaining(id: StringName) -> float:
	return _left.get(id, 0.0)


## End status `id` now and return its magnitude, or zero if it was not running.
func consume(id: StringName) -> float:
	var value: float = magnitude(id)
	_end(id)
	return value


func clear() -> void:
	for id: StringName in _left.keys():
		_end(id)


func _end(id: StringName) -> void:
	if not _left.has(id):
		return
	_left.erase(id)
	_magnitude.erase(id)
	ended.emit(id)
