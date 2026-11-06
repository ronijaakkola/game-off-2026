class_name Cabin
extends Node
## The inside of the bus: the passengers on board and the amenities that serve them. Each
## frame it runs every passenger's ride, and an amenity serves a request for its need the
## moment it opens. At a planet, the passengers going there get off and pay by their mood.

signal boarded(passenger: Passenger)
## [param passenger] got off at their destination and paid [param payout] credits.
signal delivered(passenger: Passenger, payout: int)

@export_range(1, 12) var seats := 4
## What serves needs by itself. Upgrades add to it.
@export var amenities: Array[Amenity] = []

## Whether the bus waits at a planet, docked or charging, so patience runs down at half
## speed. The scene that holds the bus sets it.
var docked := true

var _passengers: Array[Passenger] = []


func _process(delta: float) -> void:
	for passenger: Passenger in _passengers:
		passenger.tick(delta, docked)
		if passenger.request:
			var amenity := _amenity_for(passenger.request)
			if amenity:
				passenger.serve_with(amenity)


## The passengers on board, in the order they boarded. A copy.
func get_passengers() -> Array[Passenger]:
	return _passengers.duplicate()


func has_free_seat() -> bool:
	return _passengers.size() < seats


## Takes [param passenger] on board. False, and nothing happens, when every seat is taken.
func board(passenger: Passenger) -> bool:
	if not has_free_seat() or passenger in _passengers:
		return false
	_passengers.append(passenger)
	boarded.emit(passenger)
	return true


## The player serves [param passenger]'s open request.
func serve(passenger: Passenger) -> void:
	passenger.serve()


## Lets off everyone going to [param planet]. Returns the credits they paid in all.
func arrive_at(planet: Planet) -> int:
	var total := 0
	for passenger: Passenger in _passengers.duplicate():
		if passenger.destination != planet:
			continue
		_passengers.erase(passenger)
		var payout := passenger.get_payout()
		total += payout
		delivered.emit(passenger, payout)
	return total


func _amenity_for(need: Need) -> Amenity:
	for amenity: Amenity in amenities:
		if amenity.need == need.id:
			return amenity
	return null
