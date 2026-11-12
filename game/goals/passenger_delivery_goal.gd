class_name PassengerDeliveryGoal
extends Goal
## A quest: deliver [member passenger] to their destination. Kicking them off fails it.

var passenger: Passenger


func _init(who: Passenger) -> void:
	passenger = who


func get_text() -> String:
	var planet := passenger.destination.display_name if passenger.destination else "?"
	return "Deliver %s to %s" % [passenger.name, planet]


func _on_delivered(who: Passenger) -> void:
	if who == passenger:
		_complete()


func _on_kicked(who: Passenger) -> void:
	if who == passenger:
		_fail("%s was kicked" % passenger.name)
