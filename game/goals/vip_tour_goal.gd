class_name VipTourGoal
extends Goal
## A quest: pick [member passenger], a VIP, up at [member pick_up] and take them to every
## stop of their [Tour] in order. Its text names the step the player is on. They wait to
## be picked up for [member seconds_left] and no longer ([method wait]). It is done when
## the bus docks at the last stop with them on board, and fails when they give up waiting,
## are kicked off or are left behind.

var passenger: Passenger
var pick_up: Planet
## Whether they have been picked up.
var boarded := false
## Seconds they still wait to be picked up.
var seconds_left := 0.0

var _done := 0


func _init(who: Passenger, at: Planet) -> void:
	passenger = who
	pick_up = at
	_done = who.tour.done


func get_text() -> String:
	if not boarded:
		return "Pick up %s at %s" % [passenger.name, pick_up.display_name]
	var tour := passenger.tour
	var step := mini(tour.done + 1, tour.stops.size())
	var stop := tour.get_next().display_name
	return "Take %s to %s (%d of %d)" % [passenger.name, stop, step, tour.stops.size()]


## Runs [param delta] seconds of their wait to be picked up. It changes as each second
## goes, and fails when none is left.
func wait(delta: float) -> void:
	if boarded or not is_active():
		return
	var before := ceili(seconds_left)
	seconds_left -= delta
	if seconds_left <= 0.0:
		_fail("%s gave up waiting" % passenger.name)
	elif ceili(seconds_left) != before:
		changed.emit()


## They took a seat on the bus: the wait is over.
func board() -> void:
	if boarded:
		return
	boarded = true
	changed.emit()


func get_progress() -> float:
	if is_met():
		return 1.0
	var steps := passenger.tour.done + (1 if boarded else 0)
	return float(steps) / (passenger.tour.stops.size() + 1)


func to_save() -> Dictionary:
	var saved := super()
	saved["boarded"] = boarded
	return saved


func load_save(saved: Dictionary) -> void:
	boarded = bool(saved.get("boarded", boarded))
	super(saved)


func _on_bus_moved(_position: Vector3, on_board: Array[Passenger], _in_flight: bool) -> void:
	var now_boarded := boarded or passenger in on_board
	if now_boarded == boarded and passenger.tour.done == _done:
		return
	boarded = now_boarded
	_done = passenger.tour.done
	changed.emit()


# Before the cabin's stop, so the lift of a quest done reaches them before they rate.
func _on_bus_docked(at: Planet) -> void:
	if boarded and passenger.tour.is_last() and at == passenger.destination:
		_complete()


func _on_delivered(who: Passenger) -> void:
	if who == passenger:
		_complete()


func _on_kicked(who: Passenger) -> void:
	if who == passenger:
		_fail("%s left the bus" % passenger.name)
