class_name RescueGoal
extends Goal
## A quest: get [member passenger], picked up from a capsule adrift, to where they are going
## before the time they expect, leeway and all. It is done when the bus docks there with
## them on board in time. It fails the moment their ride runs late, or when they are
## kicked off.

var passenger: Passenger


func _init(who: Passenger) -> void:
	passenger = who


func get_text() -> String:
	return "Get %s to %s in time" % [passenger.name, passenger.destination.display_name]


func _on_bus_moved(_position: Vector3, on_board: Array[Passenger], _in_flight: bool) -> void:
	if passenger in on_board and passenger.ride.get_late_seconds() > 0.0:
		_fail("Too late")


func _on_bus_docked(at: Planet) -> void:
	if at == passenger.destination:
		_complete()


func _on_delivered(who: Passenger) -> void:
	if who == passenger:
		_complete()


func _on_kicked(who: Passenger) -> void:
	if who == passenger:
		_fail("%s was kicked" % passenger.name)
