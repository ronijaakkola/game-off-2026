class_name DeliveryCountGoal
extends Goal
## A milestone: deliver [member target] passengers, counted from when the goal is added,
## or only those of [member type] when it has one. Kicked passengers don't count.

var target: int
var delivered := 0
## The only kind of passenger it counts, or null for everyone.
var type: PassengerType


func _init(count: int, of_type: PassengerType = null) -> void:
	target = maxi(count, 1)
	type = of_type


func get_text() -> String:
	if type:
		return "Deliver %d %s passengers" % [target, type.display_name]
	return "Deliver %d passengers" % target


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
	delivered += 1
	if delivered >= target:
		_complete()
	else:
		changed.emit()
