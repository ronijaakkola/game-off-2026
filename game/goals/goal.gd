class_name Goal
extends RefCounted
## One thing the player is asked to do, tracked by the [GoalTracker], which tells every goal
## what happens in the game: a passenger delivered or kicked, a rating counted, the bus
## moving. Each kind of goal overrides the facts it cares about.
## A [b]milestone[/b], such as delivering 50 passengers, is met once it is completed, and
## stays completed. A [b]standing[/b] goal, such as keeping the average rating at 4 stars,
## is met or not as things stand, and never completes by itself. A quest, a goal about one
## passenger, can fail, as when that passenger is kicked off. A completed or failed goal
## takes in no more facts.

## The progress, whether it is met, or its state changed.
signal changed
## A milestone is done. It stays done.
signal completed
## It can no longer be done, as when the passenger a quest is about is kicked off.
signal failed

enum State { ACTIVE, COMPLETED, FAILED }

var state := State.ACTIVE


## What the player is asked to do, such as "Deliver 50 passengers".
func get_text() -> String:
	return ""


## How far along it is, from 0 to 1. 1 once met.
func get_progress() -> float:
	return 1.0 if is_met() else 0.0


## Whether it is met now: a milestone once completed, a standing goal while it holds.
func is_met() -> bool:
	return state == State.COMPLETED


## Whether it is met or not as things stand, rather than completed once.
func is_standing() -> bool:
	return false


func is_active() -> bool:
	return state == State.ACTIVE


## [param passenger] got off at their destination.
func passenger_delivered(passenger: Passenger) -> void:
	if is_active():
		_on_delivered(passenger)


## [param passenger] was kicked off the bus.
func passenger_kicked(passenger: Passenger) -> void:
	if is_active():
		_on_kicked(passenger)


## The average rating is [param average] stars, over [param count] rides. Also told once
## when the goal is added, so it starts from how things stand.
func rating_changed(average: float, count: int) -> void:
	if is_active():
		_on_rating_changed(average, count)


## Every frame: the bus is at [param position] with [param on_board] riding, and
## [param in_flight] is false while it is docked or charging at a planet.
func bus_moved(position: Vector3, on_board: Array[Passenger], in_flight: bool) -> void:
	if is_active():
		_on_bus_moved(position, on_board, in_flight)


func _on_delivered(_passenger: Passenger) -> void:
	pass


func _on_kicked(_passenger: Passenger) -> void:
	pass


func _on_rating_changed(_average: float, _count: int) -> void:
	pass


func _on_bus_moved(_position: Vector3, _on_board: Array[Passenger], _in_flight: bool) -> void:
	pass


# Marks a milestone done.
func _complete() -> void:
	state = State.COMPLETED
	changed.emit()
	completed.emit()


func _fail() -> void:
	state = State.FAILED
	changed.emit()
	failed.emit()
