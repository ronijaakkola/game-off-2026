class_name FlybyGoal
extends Goal
## A quest: fly [member passenger] past [member planet]: while they ride, the bus comes
## within [member reach] of the planet's surface in flight, having been out of reach since
## they boarded, so leaving the planet they boarded at isn't a flyby, and coming back to it
## is. Flying in to dock there counts; sitting docked or charging there doesn't. It fails
## when they leave the bus before the flyby, however they leave: kicked off, getting off,
## or gone from the cabin any other way.

## How near the planet's surface the bus comes, in units, for a flyby.
const REACH := 3.0

var passenger: Passenger
var planet: Planet
var reach := REACH
# Whether the bus has been out of reach of the planet since they boarded, so leaving it
# isn't a flyby.
var _left := false
# Whether they have been seen on board, so leaving it fails the quest.
var _boarded := false


func _init(who: Passenger, past: Planet) -> void:
	passenger = who
	planet = past


func get_text() -> String:
	return "Fly %s past %s" % [passenger.name, planet.display_name]


func _on_delivered(who: Passenger) -> void:
	if who == passenger:
		_fail("%s left the bus" % passenger.name)


func _on_kicked(who: Passenger) -> void:
	if who == passenger:
		_fail("%s was kicked" % passenger.name)


func _on_bus_moved(position: Vector3, on_board: Array[Passenger], in_flight: bool) -> void:
	if passenger not in on_board:
		if _boarded:
			_fail("%s left the bus" % passenger.name)
		return
	_boarded = true
	var near := (
		position.distance_to(planet.get_body_global_position()) <= planet.get_body_radius() + reach
	)
	if not near:
		_left = true
	elif in_flight and _left:
		_complete()
