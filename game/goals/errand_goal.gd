class_name ErrandGoal
extends Goal
## A quest: stop at [member planet] with [member passenger] on board, before the bus gets
## to where they are going. It is done when the bus docks there, by a tow as much as by a
## course, whatever else it stopped at on the way. It fails when the bus docks at their
## destination first, or when they are kicked off.

var passenger: Passenger
var planet: Planet


func _init(who: Passenger, at: Planet) -> void:
	passenger = who
	planet = at


func get_text() -> String:
	return "Stop at %s for %s" % [planet.display_name, passenger.name]


func _on_delivered(who: Passenger) -> void:
	if who == passenger:
		_fail("%s left the bus" % passenger.name)


func _on_kicked(who: Passenger) -> void:
	if who == passenger:
		_fail("%s was kicked" % passenger.name)


func _on_bus_docked(at: Planet) -> void:
	if at == planet:
		_complete()
	elif at == passenger.destination:
		_fail("Stopped at %s first" % at.display_name)
