class_name BossPickUpQuest
extends Quest
## The Boss's quest once the last star system's goals are met ([BossPickUp]): pick up
## someone they don't name at the planet the [Stargate] is to be built beside. It has no
## timer, pays nothing, and is done as the bus docks there ([method arrive]). Whoever gives
## it makes the passenger first, with where they wait as their origin. A save keeps it with
## The Boss's pick-up, since they aren't on board while it is under way.

const KIND := "boss_pick_up"


func restore(saved: Dictionary, who: Passenger, _planets: Dictionary[String, Planet]) -> bool:
	passenger = who
	goal = PickUpGoal.new()
	load_save(saved)
	return true


func get_kind() -> String:
	return KIND


func get_ask() -> String:
	return "Pick up at"


func get_planet() -> Planet:
	return passenger.origin if passenger else null


func accept() -> void:
	goal = PickUpGoal.new()


## The bus is where they wait: the quest is done.
func arrive() -> void:
	if goal and goal.is_active():
		(goal as PickUpGoal).reach()


## Done once the bus is there.
class PickUpGoal:
	extends Goal

	func get_text() -> String:
		return "Pick up The Boss's passenger"

	## Marks it done.
	func reach() -> void:
		_complete()
