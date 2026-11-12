class_name DeliveryCountGoal
extends Goal
## A milestone: deliver [member target] passengers, counted from when the goal is added.
## Kicked passengers don't count.

var target: int
var delivered := 0


func _init(count: int) -> void:
	target = maxi(count, 1)


func get_text() -> String:
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


func _on_delivered(_passenger: Passenger) -> void:
	delivered += 1
	if delivered >= target:
		_complete()
	else:
		changed.emit()
