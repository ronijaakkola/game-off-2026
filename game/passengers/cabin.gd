class_name Cabin
extends Node
## The inside of the bus: the passengers on board and the amenities that serve them. Each
## frame it runs every passenger's ride, and an amenity serves a request for its need the
## moment it opens. At a planet it runs a stop: the passengers going there get off one at
## a time and pay by their mood, then those waiting there get on one at a time while seats
## are free. Each takes [member step_seconds], so a busy stop takes longer.

signal boarded(passenger: Passenger)
## [param passenger] got off at their destination and paid [param payout] credits.
signal delivered(passenger: Passenger, payout: int)
## The stop [method stop_at] started is over: everyone going there got off, and those
## waiting got on.
signal stop_finished

@export_range(1, 12) var seats := 4
## What serves needs by itself. Upgrades add to it.
@export var amenities: Array[Amenity] = []
## Seconds each passenger takes to get off or on at a stop.
@export_range(0.0, 3.0, 0.05) var step_seconds := 0.6

## Whether the bus waits at a planet, docked or charging, so patience runs down at half
## speed. The scene that holds the bus sets it.
var docked := true

var _passengers: Array[Passenger] = []
# The stop under way: who still gets off, with what they pay, and where the rest board.
var _stopping := false
var _stop_planet: Planet
var _stop_waiting: WaitingPassengers
var _getting_off: Array[Passenger] = []
var _payouts: Array[int] = []
var _getting_on: Array[Passenger] = []
var _boarding_taken := false
var _until_step := 0.0


func _process(delta: float) -> void:
	for passenger: Passenger in _passengers:
		passenger.tick(delta, docked)
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
## Then those waiting at [param waiting] board one at a time, longest waiting first, while
## seats are free. The first one goes at once, and [signal stop_finished] comes
## [member step_seconds] after the last, or at once when nobody gets off or on.
func stop_at(planet: Planet, waiting: WaitingPassengers = null) -> void:
	_stop_planet = planet
	_stop_waiting = waiting
	_boarding_taken = false
	_getting_on.clear()
	for passenger: Passenger in _passengers.duplicate():
		if passenger.destination == planet:
			_passengers.erase(passenger)
			_getting_off.append(passenger)
			_payouts.append(passenger.get_payout())
	_stopping = true
	_until_step = 0.0
	_step()


# One passenger off, else one on, else the stop is over.
func _step() -> void:
	if not _getting_off.is_empty():
		delivered.emit(_getting_off.pop_front(), _payouts.pop_front())
		_until_step += step_seconds
		return
	if not _boarding_taken:
		_boarding_taken = true
		if _stop_waiting:
			var free := seats - _passengers.size()
			_getting_on = _stop_waiting.take(_stop_planet, free)
	if not _getting_on.is_empty():
		board(_getting_on.pop_front())
		_until_step += step_seconds
		return
	_stopping = false
	_stop_planet = null
	_stop_waiting = null
	stop_finished.emit()


func _amenity_for(need: Need) -> Amenity:
	for amenity: Amenity in amenities:
		if amenity.need == need.id:
			return amenity
	return null
