extends Node
## The solar system with the goal panel showing the design's state: 12 of 50 passengers
## delivered, and a 4.2 average against a 4.0 rating goal, so one goal is short and one
## is met. With "Quest" after `--`, a Business passenger rides on an express quest, so the panel
## also shows "Quests" and their portrait wears the flag; with "Failed" as well, the bus
## has stopped at another planet first.


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
	if "Quest" in OS.get_cmdline_user_args():
		_show_quest()


func _show_quest() -> void:
	var waiting := $SolarSystem/WaitingPassengers as WaitingPassengers
	var bus := $SolarSystem/Bus as FrameshiftBus
	var passenger := waiting.create(bus.get_docked_planet())
	# Business, as everyone who calls with a quest is: the flag sits beside the briefcase.
	passenger.type = waiting.business
	($SolarSystem/Cabin as Cabin).board(passenger)
	var goal := ExpressGoal.new(passenger)
	var quest := ExpressQuest.new()
	quest.passenger = passenger
	quest.planet = passenger.destination
	quest.goal = goal
	quest.reward_credits = ExpressQuest.REWARD_CREDITS
	quest.reward_research = {passenger.race: ExpressQuest.REWARD_RESEARCH}
	var giver := $SolarSystem/QuestGiver as QuestGiver
	giver.enabled = false
	giver.take_on(quest)
	if "Failed" in OS.get_cmdline_user_args():
		goal.bus_docked(bus.get_docked_planet())
