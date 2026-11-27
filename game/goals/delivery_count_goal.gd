class_name DeliveryCountGoal
extends Goal
## A milestone: deliver [member target] passengers, counted from when the goal is added,
## or only those of [member type] when it has one, and only those who weren't late when
## [member on_time]. Kicked passengers don't count.

var target: int
var delivered := 0
## The only kind of passenger it counts, or null for everyone.
var type: PassengerType
## Whether only those delivered on time count.
var on_time := false


func _init(count: int, of_type: PassengerType = null, in_time := false) -> void:
	target = maxi(count, 1)
	type = of_type
	on_time = in_time


func get_text() -> String:
	var text := "Deliver %d passengers" % target
	if type:
		text = "Deliver %d %s passengers" % [target, type.display_name]
	return text + (" on time" if on_time else "")


func get_progress() -> float:
	return minf(float(delivered) / target, 1.0)


func to_save() -> Dictionary:
	var saved := super()
	saved["delivered"] = delivered
	return saved


func load_save(saved: Dictionary) -> void:
	delivered = int(saved.get("delivered", delivered))
	super(saved)


func _on_delivered(passenger: Passenger) -> void:
	if type and passenger.type != type:
		return
	if on_time and passenger.ride.get_late_seconds() > 0.0:
		return
	delivered += 1
	if delivered >= target:
		_complete()
	else:
		changed.emit()
