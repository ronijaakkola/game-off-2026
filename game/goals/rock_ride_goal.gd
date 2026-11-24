class_name RockRideGoal
extends Goal
## A quest, a rock ride: fly [member passenger] among an asteroid field's rocks for
## [member seconds] in all, while they ride, not all at once. It fails when the bus docks at
## their destination first, or when they leave the bus before it.

## Seconds among the rocks it takes.
const SECONDS := 3.0

var passenger: Passenger
var seconds := SECONDS
# Seconds flown among the rocks with them on board so far.
var _flown := 0.0
# Whether they have been seen on board, so leaving it fails the quest.
var _boarded := false


func _init(who: Passenger) -> void:
	passenger = who


func get_text() -> String:
	return "Fly %s through the rocks" % passenger.name


func get_progress() -> float:
	return 1.0 if is_met() else clampf(_flown / seconds, 0.0, 1.0)


func to_save() -> Dictionary:
	var saved := super()
	saved["flown"] = _flown
	return saved


func load_save(saved: Dictionary) -> void:
	_flown = float(saved.get("flown", 0.0))
	super(saved)


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


func _on_bus_in_rocks(delta: float, on_board: Array[Passenger]) -> void:
	if passenger not in on_board:
		return
	_flown += delta
	changed.emit()
	if _flown >= seconds:
		_complete()
