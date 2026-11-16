class_name NeedTimers
extends RefCounted
## When each of a passenger's needs asks again: a wait for every need of their type, each
## a random time between the need's shortest and longest, times the type's
## [member PassengerType.need_interval_scale]. The ride runs them down, and a need served
## waits its served time and a new interval. [Passenger] owns one.

var _type: PassengerType
var _rng: RandomNumberGenerator
# Seconds until each need in _type.needs asks again.
var _left := PackedFloat32Array()


## A wait for each of [param type]'s needs, picked by [param rng].
func _init(type: PassengerType, rng: RandomNumberGenerator) -> void:
	_type = type
	_rng = rng
	for need: Need in type.needs:
		_left.append(_interval(need))


## Makes what is left of every wait [param scale] times as long.
func delay(scale: float) -> void:
	for i: int in _left.size():
		_left[i] *= scale


## Runs every wait down by [param seconds].
func run(seconds: float) -> void:
	for i: int in _left.size():
		_left[i] -= seconds


## The first need whose wait is over, or null.
func get_due() -> Need:
	for i: int in _left.size():
		if _left[i] <= 0.0:
			return _type.needs[i]
	return null


## [param need] was served, and asks again after [param seconds] and a new interval. A need
## that isn't one of the type's has no wait.
func restart(need: Need, seconds: float) -> void:
	var index := _type.needs.find(need)
	if index >= 0:
		_left[index] = seconds + _interval(need)


## What is left of each wait, for a save game ([method load_save]).
func to_save() -> Array:
	return Array(_left)


## Puts back the waits [method to_save] gave. One for a need the type no longer has is
## left out.
func load_save(saved: Array) -> void:
	for i: int in mini(saved.size(), _left.size()):
		_left[i] = float(saved[i])


func _interval(need: Need) -> float:
	var seconds := _rng.randf_range(need.min_interval, maxf(need.min_interval, need.max_interval))
	return seconds * _type.need_interval_scale
