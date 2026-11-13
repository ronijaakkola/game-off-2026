class_name GoalTracker
extends Node
## A set of the player's goals: it tells each one what happens in the game, from the
## [Cabin], the [Ledger] and the bus, and says when one changes, is completed
## or fails. Goals stay in it once completed or failed, until removed. The scene has one
## for the goals a promotion takes and one for the quests under way.

## Started tracking [param goal], before it is told how things stand.
signal goal_added(goal: Goal)
## Stopped tracking [param goal].
signal goal_removed(goal: Goal)
## [param goal]'s progress, whether it is met, or its state changed.
signal goal_changed(goal: Goal)
signal goal_completed(goal: Goal)
signal goal_failed(goal: Goal)

@export var bus: FrameshiftBus:
	set(value):
		if bus:
			bus.docked.disconnect(_on_bus_docked)
		bus = value
		if bus:
			bus.docked.connect(_on_bus_docked)
@export var cabin: Cabin:
	set(value):
		if cabin:
			cabin.delivered.disconnect(_on_delivered)
			cabin.kicked.disconnect(_on_kicked)
		cabin = value
		if cabin:
			cabin.delivered.connect(_on_delivered)
			cabin.kicked.connect(_on_kicked)

## The ledger whose recent rating the goals follow. The scene that owns it sets it.
var ledger: Ledger:
	set(value):
		if ledger:
			ledger.rated.disconnect(_on_rated)
		ledger = value
		if ledger:
			ledger.rated.connect(_on_rated)
			_on_rated(0.0)

var _goals: Array[Goal] = []
# The callables each goal's changed, completed and failed signals are connected to.
var _relays: Dictionary[Goal, Array] = {}


func _process(_delta: float) -> void:
	if not bus or _goals.is_empty():
		return
	var on_board: Array[Passenger] = cabin.get_passengers() if cabin else []
	var in_flight := not bus.is_at_planet()
	for goal: Goal in _goals.duplicate():
		goal.bus_moved(bus.global_position, on_board, in_flight)


## Starts tracking [param goal], from how things stand now.
func add(goal: Goal) -> void:
	if goal in _goals:
		return
	_goals.append(goal)
	# Methods of this node rather than bound signal emits, so freeing the tracker
	# disconnects them, and the goals they bind are freed with it.
	var relays: Array[Callable] = [
		_on_goal_changed.bind(goal), _on_goal_completed.bind(goal), _on_goal_failed.bind(goal)
	]
	goal.changed.connect(relays[0])
	goal.completed.connect(relays[1])
	goal.failed.connect(relays[2])
	_relays[goal] = relays
	goal_added.emit(goal)
	if ledger:
		goal.rating_changed(ledger.get_recent_rating(), ledger.get_rating_count())


## Stops tracking [param goal].
func remove(goal: Goal) -> void:
	if goal not in _goals:
		return
	_goals.erase(goal)
	var relays: Array = _relays[goal]
	goal.changed.disconnect(relays[0])
	goal.completed.disconnect(relays[1])
	goal.failed.disconnect(relays[2])
	_relays.erase(goal)
	goal_removed.emit(goal)


## Every goal tracked, in the order added. A copy.
func get_goals() -> Array[Goal]:
	return _goals.duplicate()


## Whether every goal is met now: each milestone completed and each standing goal holding.
## False with no goals.
func are_all_met() -> bool:
	if _goals.is_empty():
		return false
	for goal: Goal in _goals:
		if not goal.is_met():
			return false
	return true


func _on_delivered(passenger: Passenger, _payout: int) -> void:
	for goal: Goal in _goals.duplicate():
		goal.passenger_delivered(passenger)


func _on_kicked(passenger: Passenger) -> void:
	for goal: Goal in _goals.duplicate():
		goal.passenger_kicked(passenger)


func _on_bus_docked(planet: Planet) -> void:
	for goal: Goal in _goals.duplicate():
		goal.bus_docked(planet)


func _on_rated(_stars: float) -> void:
	var recent := ledger.get_recent_rating()
	var count := ledger.get_rating_count()
	for goal: Goal in _goals.duplicate():
		goal.rating_changed(recent, count)


func _on_goal_changed(goal: Goal) -> void:
	goal_changed.emit(goal)


func _on_goal_completed(goal: Goal) -> void:
	goal_completed.emit(goal)


func _on_goal_failed(goal: Goal) -> void:
	goal_failed.emit(goal)
