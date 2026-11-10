extends Node
## The solar system with the goal panel showing the design's state: 12 of 50 passengers
## delivered, and a 4.2 average against a 4.0 rating goal, so one goal is short and one
## is met.


func _ready() -> void:
	var tracker := $SolarSystem/Goals as GoalTracker
	for goal: Goal in tracker.get_goals():
		tracker.remove(goal)
	var deliveries := DeliveryCountGoal.new(50)
	tracker.add(deliveries)
	tracker.add(RatingGoal.new(4.0))
	for i: int in 12:
		deliveries.passenger_delivered(null)
	for goal: Goal in tracker.get_goals():
		goal.rating_changed(4.2, 5)
