class_name Cabin
extends Node
## The inside of the bus: the passengers on board and the amenities that serve them. Each
## frame it runs every passenger's ride, and an amenity serves a request for its need the
## moment it opens. At a planet it runs a stop: the passengers going there get off one at
## a time and pay by their mood. Those the player picks up get on one at a time, after
## everyone getting off. Each takes [member step_seconds], so a busy stop takes longer.

signal boarded(passenger: Passenger)
## [param passenger] got off at their destination and paid [param payout] credits.
signal delivered(passenger: Passenger, payout: int)
## Everyone getting off at the stop [method stop_at] started has got off, one step after
## the last of them. Emitted even when nobody got off.
signal unloaded
## The stop is over: everyone going there got off, and everyone picked up got on.
signal stop_finished

@export_range(1, 12) var seats := 4
## What serves needs by itself. Upgrades add to it.
@export var amenities: Array[Amenity] = []
## Seconds each passenger takes to get off or on at a stop.
@export_range(0.0, 3.0, 0.05) var step_seconds := 0.6

## Whether the bus waits at a planet, docked or charging, so patience runs down at half
## speed. The scene that holds the bus sets it. When it turns false the bus has left, and
## everyone on board has departed, so the patience of those who just boarded starts running
## down.
var docked := true:
	set(value):
		if docked and not value:
			for passenger: Passenger in _passengers:
				passenger.depart()
		docked = value

## Whether the bus is parking at a planet, so everyone's patience holds: the bus has
## arrived. The scene that holds the bus sets it.
var parking := false

var _passengers: Array[Passenger] = []
# The stop under way: who still gets off, with what they pay, and who still gets on.
var _stopping := false
var _unloading := false
var _getting_off: Array[Passenger] = []
var _payouts: Array[int] = []
var _getting_on: Array[Passenger] = []
var _until_step := 0.0


func _process(delta: float) -> void:
	for passenger: Passenger in _passengers:
		passenger.tick(delta, docked, parking)
		if passenger.request:
			var amenity := _amenity_for(passenger.request)
			if amenity:
				passenger.serve_with(amenity)
	if _stopping:
		_until_step -= delta
		while _stopping and _until_step <= 0.0:
			_step()


## The passengers on board, in the order they boarded. A copy. Those getting off at a stop
## under way are no longer on board.
func get_passengers() -> Array[Passenger]:
	return _passengers.duplicate()


func has_free_seat() -> bool:
	return _passengers.size() < seats


## Seats no one has taken or been picked up for.
func get_free_seats() -> int:
	return seats - _passengers.size() - _getting_on.size()


## Whether a stop is under way: passengers are still getting off or on.
func is_stopping() -> bool:
	return _stopping


## Takes [param passenger] on board at once. False, and nothing happens, when every seat
## is taken.
func board(passenger: Passenger) -> bool:
	if not has_free_seat() or passenger in _passengers:
		return false
	_passengers.append(passenger)
	boarded.emit(passenger)
	return true


## The player serves [param passenger]'s open request.
func serve(passenger: Passenger) -> void:
	passenger.serve()


## Starts a stop at [param planet]. Everyone going there leaves their seat now, and their
## patience stops, so they pay by the mood they arrived in; they get off one at a time.
## The first one goes at once, and [signal stop_finished] comes [member step_seconds] after
## the last, or at once when nobody gets off or on.
func stop_at(planet: Planet) -> void:
	for passenger: Passenger in _passengers.duplicate():
		if passenger.destination == planet:
			_passengers.erase(passenger)
			_getting_off.append(passenger)
			_payouts.append(passenger.get_payout())
	_unloading = true
	_start_stop()


## The player picks up [param passenger]: they get on after everyone getting off and
## everyone picked up before them, one step each, so a stop starts if none is under way.
## False, and nothing happens, when no seat is free for them.
func pick_up(passenger: Passenger) -> bool:
	if get_free_seats() <= 0 or passenger in _passengers or passenger in _getting_on:
		return false
	_getting_on.append(passenger)
	if not _stopping:
		_start_stop()
	return true


func _start_stop() -> void:
	if _stopping:
		return
	_stopping = true
	_until_step = 0.0
	_step()


# One passenger off, else one on, else the stop is over.
func _step() -> void:
	if not _getting_off.is_empty():
		delivered.emit(_getting_off.pop_front(), _payouts.pop_front())
		_until_step += step_seconds
		return
	if _unloading:
		_unloading = false
		unloaded.emit()
	if not _getting_on.is_empty():
		board(_getting_on.pop_front())
		_until_step += step_seconds
		return
	_stopping = false
	stop_finished.emit()


func _amenity_for(need: Need) -> Amenity:
	for amenity: Amenity in amenities:
		if amenity.need == need.id:
			return amenity
	return null
