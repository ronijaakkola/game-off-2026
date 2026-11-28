class_name Goal
extends RefCounted
## One thing the player is asked to do, tracked by the [GoalTracker], which tells every goal
## what happens in the game: a passenger delivered or kicked, a rating counted, credits
## earned, the bus
## moving, docking, holding still, warping, flying among rocks or running hot. Each kind of
## goal overrides the facts it cares about.
## A [b]milestone[/b], such as delivering 50 passengers, is met once it is completed, and
## stays completed. A [b]standing[/b] goal, such as keeping the recent rating at 4 stars,
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
## Why it failed, as a short line such as "Ran out of time", or empty.
var failure := ""


## What the player is asked to do, such as "Deliver 50 passengers".
func get_text() -> String:
	return ""


## How it stands now, as a short line shown in place of who asked while it is under way,
## such as when a hop location opens, or empty.
func get_status() -> String:
	return ""


## Whether it can be done now, as [method get_status] tells the player.
func is_ready() -> bool:
	return false


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


## [param passenger] was kicked off the bus, or with [param left_behind] stayed behind as
## they left it, as when the bus jumped to the next star system: as good as kicked, unless
## a kind of goal tells the two apart.
func passenger_kicked(passenger: Passenger, left_behind := false) -> void:
	if not is_active():
		return
	if left_behind:
		_on_left_behind(passenger)
	else:
		_on_kicked(passenger)


## The recent rating is [param recent] stars, with [param count] rides rated in all. Also
## told once when the goal is added, so it starts from how things stand.
func rating_changed(recent: float, count: int) -> void:
	if is_active():
		_on_rating_changed(recent, count)


## Every frame: the bus is at [param position] with [param on_board] riding, and
## [param in_flight] is false while it is docked or charging at a planet.
func bus_moved(position: Vector3, on_board: Array[Passenger], in_flight: bool) -> void:
	if is_active():
		_on_bus_moved(position, on_board, in_flight)


## The bus docked at [param planet].
func bus_docked(planet: Planet) -> void:
	if is_active():
		_on_bus_docked(planet)


## The player earned [param amount] credits.
func credits_earned(amount: int) -> void:
	if is_active():
		_on_credits_earned(amount)


## Every frame the bus holds still in space, at [param position] with [param on_board]
## riding.
func bus_held(position: Vector3, on_board: Array[Passenger]) -> void:
	if is_active():
		_on_bus_held(position, on_board)


## Every frame the bus is at [param planet], parking, docked or charging there, with
## [param on_board] riding.
func bus_stopped_at(planet: Planet, on_board: Array[Passenger]) -> void:
	if is_active():
		_on_bus_stopped_at(planet, on_board)


## The bus went through a warp gate with [param on_board] riding.
func bus_warped(on_board: Array[Passenger]) -> void:
	if is_active():
		_on_bus_warped(on_board)


## Every frame the bus flies among an asteroid field's rocks, for [param delta] seconds,
## with [param on_board] riding.
func bus_in_rocks(delta: float, on_board: Array[Passenger]) -> void:
	if is_active():
		_on_bus_in_rocks(delta, on_board)


## Every frame the bus is past its comfortable temperature, with [param on_board] riding.
func bus_hot(on_board: Array[Passenger]) -> void:
	if is_active():
		_on_bus_hot(on_board)


## Its progress, for a save game. A kind of goal with progress of its own adds it.
func to_save() -> Dictionary:
	return {"state": state}


## Puts back the progress [method to_save] gave, and says it changed.
func load_save(saved: Dictionary) -> void:
	state = int(saved.get("state", state)) as State
	changed.emit()


func _on_delivered(_passenger: Passenger) -> void:
	pass


func _on_kicked(_passenger: Passenger) -> void:
	pass


func _on_left_behind(passenger: Passenger) -> void:
	_on_kicked(passenger)


func _on_rating_changed(_recent: float, _count: int) -> void:
	pass


func _on_bus_moved(_position: Vector3, _on_board: Array[Passenger], _in_flight: bool) -> void:
	pass


func _on_bus_docked(_planet: Planet) -> void:
	pass


func _on_credits_earned(_amount: int) -> void:
	pass


func _on_bus_held(_position: Vector3, _on_board: Array[Passenger]) -> void:
	pass


func _on_bus_stopped_at(_planet: Planet, _on_board: Array[Passenger]) -> void:
	pass


func _on_bus_warped(_on_board: Array[Passenger]) -> void:
	pass


func _on_bus_in_rocks(_delta: float, _on_board: Array[Passenger]) -> void:
	pass


func _on_bus_hot(_on_board: Array[Passenger]) -> void:
	pass


# Marks a milestone done.
func _complete() -> void:
	state = State.COMPLETED
	changed.emit()
	completed.emit()


# Marks it failed, for [param reason], a short line the player is shown.
func _fail(reason := "") -> void:
	failure = reason
	state = State.FAILED
	changed.emit()
	failed.emit()
