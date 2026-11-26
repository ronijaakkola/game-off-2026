extends Node
## The solar system with the goal panel showing the design's state: 12 of 50 passengers
## delivered, and a 4.2 average against a 4.0 rating goal, so one goal is short and one
## is met. With "Quest" after `--`, a Business passenger rides on an express quest, so the panel
## also shows "Quests" and their portrait wears the flag; with "Failed" as well, the bus
## has stopped at another planet first. With "Stay", the player has stayed after a promotion,
## so the jump to the next system shows in place of the goals; with "Hint" as well, its
## feature hint opens on the button, unless the player has closed it before, and with "Quest"
## as well, the card takes the goals' place over the quest, and with "Hover" as well, the
## pointer comes onto the card 2 s in.


func _ready() -> void:
	if "Stay" in OS.get_cmdline_user_args():
		if "Hint" in OS.get_cmdline_user_args():
			# Hints show only in a saved run, which a preview isn't.
			($SolarSystem/FeatureHints as FeatureHints).saver = null
		if "Quest" in OS.get_cmdline_user_args():
			_show_quest()
		($SolarSystem/Progression as Progression).stay()
		if "Hover" in OS.get_cmdline_user_args():
			await get_tree().create_timer(2.0).timeout
			(
				(find_child("GoalPanel", true, false) as GoalPanel)
				. get_jump_button()
				. mouse_entered
				. emit()
			)
		return
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
	quest.reward_credits = ExpressQuest.REWARD_CREDITS[0]
	quest.reward_research = ExpressQuest.REWARD_RESEARCH[0]
	var giver := $SolarSystem/QuestGiver as QuestGiver
	giver.enabled = false
	giver.take_on(quest)
	if "Failed" in OS.get_cmdline_user_args():
		goal.bus_docked(bus.get_docked_planet())
