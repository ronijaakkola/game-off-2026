class_name Appetite
extends RefCounted
## When a passenger next asks for each of their type's needs. [Passenger] owns one, runs it
## while they could ask, and opens the request that is due.
## Each need waits a random interval between requests ([member Need.min_interval] to
## [member Need.max_interval], times the type's scale). The first wait is only part of one
## ([member Need.first_wait]): everyone comes on board somewhere between hungry and just
## fed, so those picked up together don't all ask at the same moment.

var _needs: Array[Need]
var _interval_scale: float
var _rng: RandomNumberGenerator
# Seconds until each need asks again.
var _timers := PackedFloat32Array()


func _init(needs: Array[Need], interval_scale: float, rng: RandomNumberGenerator) -> void:
	_needs = needs
	_interval_scale = interval_scale
	_rng = rng
	for need: Need in _needs:
		var part := _rng.randf_range(need.first_wait, 1.0) if need.first_wait < 1.0 else 1.0
		_timers.append(_interval(need) * part)


## Runs [param delta] seconds of every wait.
func run(delta: float) -> void:
	for i: int in _timers.size():
		_timers[i] -= delta


## The need whose wait is over, the type's first one first, or null.
func get_due() -> Need:
	for i: int in _timers.size():
		if _timers[i] <= 0.0:
			return _needs[i]
	return null


## [param need] was just served: it asks again a new interval after [param seconds], the
## time the served activity lasts. A need that isn't one of the type's has no wait to set.
func rest(need: Need, seconds: float) -> void:
	var index := _needs.find(need)
	if index >= 0:
		_timers[index] = seconds + _interval(need)


## Makes what is left of every wait [param scale] times as long.
func delay(scale: float) -> void:
	for i: int in _timers.size():
		_timers[i] *= scale


## The seconds left of each wait, for a save game ([method load_save]).
func to_save() -> Array:
	return Array(_timers)


func load_save(saved: Array) -> void:
	for i: int in mini(saved.size(), _timers.size()):
		_timers[i] = float(saved[i])


func _interval(need: Need) -> float:
	var seconds := _rng.randf_range(need.min_interval, maxf(need.min_interval, need.max_interval))
	return seconds * _interval_scale
