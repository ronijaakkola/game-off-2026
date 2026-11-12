class_name ExpressGoal
extends Goal
## A quest: get [member passenger] to their destination within [member seconds] of taking
## it on. The time runs while they ride, docked or not, and stops once they leave their
## seat to get off. It fails the moment the time runs out, or when they are kicked off.

var passenger: Passenger
## The seconds allowed, and how many are left.
var seconds: float
var seconds_left: float
# Whether they have been seen on board, so leaving their seat stops the time.
var _boarded := false
var _arrived := false


func _init(who: Passenger, within: float) -> void:
	passenger = who
	seconds = maxf(within, 1.0)
	seconds_left = seconds


func get_text() -> String:
	var planet := passenger.destination.display_name if passenger.destination else "?"
	return "Rush %s to %s" % [passenger.name, planet]


## How much of the time is left, from 1 to 0, and 1 once it is done.
func get_progress() -> float:
	return 1.0 if is_met() else seconds_left / seconds


func to_save() -> Dictionary:
	var saved := super()
	saved["seconds"] = seconds
	saved["seconds_left"] = seconds_left
	return saved


func load_save(saved: Dictionary) -> void:
	seconds = float(saved.get("seconds", seconds))
	seconds_left = float(saved.get("seconds_left", seconds_left))
	super(saved)


func _on_delivered(who: Passenger) -> void:
	if who == passenger:
		_complete()


func _on_kicked(who: Passenger) -> void:
	if who == passenger:
		_fail()


func _on_bus_moved(_position: Vector3, on_board: Array[Passenger], _in_flight: bool) -> void:
	if passenger in on_board:
		_boarded = true
	elif _boarded:
		_arrived = true


func _on_time_passed(delta: float) -> void:
	if _arrived:
		return
	seconds_left = maxf(seconds_left - delta, 0.0)
	if seconds_left <= 0.0:
		_fail()
	else:
		changed.emit()
