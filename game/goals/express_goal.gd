class_name ExpressGoal
extends Goal
## A quest: make [member passenger]'s destination the bus's next stop. It is done when
## they get off there, and fails when the bus docks at any other planet first, by a tow as
## much as by a course, or when they are kicked off. Passing through points in space, or
## coming to rest there, is no stop.

var passenger: Passenger


func _init(who: Passenger) -> void:
	passenger = who


func get_text() -> String:
	var planet := passenger.destination.display_name if passenger.destination else "?"
	return "Take %s straight to %s" % [passenger.name, planet]


func _on_delivered(who: Passenger) -> void:
	if who == passenger:
		_complete()


func _on_kicked(who: Passenger) -> void:
	if who == passenger:
		_fail("%s was kicked" % passenger.name)


func _on_bus_docked(planet: Planet) -> void:
	if planet != passenger.destination:
		var stopped := planet.display_name if planet.display_name else String(planet.name)
		_fail("Stopped at %s first" % stopped)
