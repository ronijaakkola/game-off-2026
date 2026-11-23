class_name WarpGoal
extends Goal
## A quest: take [member passenger] through a warp gate. It is done when the bus warps with
## them on board, and fails when the bus docks at their destination first, or when they
## leave the bus before it.

var passenger: Passenger
# Whether they have been seen on board, so leaving it fails the quest.
var _boarded := false


func _init(who: Passenger) -> void:
	passenger = who


func get_text() -> String:
	return "Warp %s through a gate" % passenger.name


func _on_delivered(who: Passenger) -> void:
	if who == passenger:
		_fail("%s left the bus" % passenger.name)


func _on_kicked(who: Passenger) -> void:
	if who == passenger:
		_fail("%s was kicked" % passenger.name)


func _on_bus_docked(at: Planet) -> void:
	if at == passenger.destination:
		_fail("Stopped at %s first" % at.display_name)


func _on_bus_moved(_position: Vector3, on_board: Array[Passenger], _in_flight: bool) -> void:
	if passenger in on_board:
		_boarded = true
	elif _boarded:
		_fail("%s left the bus" % passenger.name)


func _on_bus_warped(on_board: Array[Passenger]) -> void:
	if passenger in on_board:
		_complete()
