class_name PhotoStopGoal
extends FlybyGoal
## A quest: stop [member passenger] near [member planet] for a photo: while they ride, the
## bus holds still in space within [member reach] of the planet's surface. Flying past
## doesn't count, and nor does docking there. It fails as a fly past does: when the bus
## docks at their destination first, or when they leave the bus before it.


func get_text() -> String:
	return "Stop near %s for %s" % [planet.display_name, passenger.name]


func _on_bus_moved(_position: Vector3, on_board: Array[Passenger], _in_flight: bool) -> void:
	if passenger in on_board:
		_boarded = true
	elif _boarded:
		_fail("%s left the bus" % passenger.name)


func _on_bus_held(position: Vector3, on_board: Array[Passenger]) -> void:
	if passenger not in on_board:
		return
	var at := planet.get_body_global_position()
	if position.distance_to(at) <= planet.get_body_radius() + reach:
		_complete()
