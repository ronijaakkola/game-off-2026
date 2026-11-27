class_name HopGoal
extends Goal
## A quest: bring the bus to a halt at the hop location, [member spot], a place in open
## space, with [member passenger] on board, so they can hop out there. It is done when the
## bus holds still in space within [member radius] of the spot; flying through doesn't
## count. It fails only when they leave the bus first, kicked off or left behind. A kind
## whose hop location moves, or is only open at times, overrides [method get_spot],
## [method is_open] and [method get_window_text] ([WindowHopGoal]).

## How far from the spot the bus may come to rest, in units.
const RADIUS := 0.8

var passenger: Passenger
## Where they want to hop out, in global space, on the orbit plane.
var spot: Vector3
var radius := RADIUS
# Whether they have been seen on board, so leaving it fails the quest.
var _boarded := false


func _init(who: Passenger, at: Vector3) -> void:
	passenger = who
	spot = at


func get_text() -> String:
	return "Bring bus to halt at the hop location"


## Where the hop location is now, in global space.
func get_spot() -> Vector3:
	return spot


## Whether they would hop out there now.
func is_open() -> bool:
	return true


## When the hop location opens or closes, as a short line for the player, or empty for one
## that is always open.
func get_window_text() -> String:
	return ""


func _on_kicked(who: Passenger) -> void:
	if who == passenger:
		_fail("%s left the bus" % passenger.name)


func _on_bus_moved(_position: Vector3, on_board: Array[Passenger], _in_flight: bool) -> void:
	if passenger in on_board:
		_boarded = true
	elif _boarded:
		_fail("%s left the bus" % passenger.name)


func _on_bus_held(position: Vector3, on_board: Array[Passenger]) -> void:
	if passenger not in on_board or not is_open():
		return
	if RouteStop.flat(position - get_spot()).length() <= radius:
		_complete()
