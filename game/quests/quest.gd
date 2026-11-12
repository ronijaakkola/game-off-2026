class_name Quest
extends RefCounted
## What a passenger asks of the player in a transmission, for a reward: the [member goal]
## that tracks it, what it pays once that is completed, and the transmission that offers
## it. The [QuestGiver] offers it, and tracks and pays it once the player accepts. Each
## kind of quest extends this with what it asks.

## Who asks.
var passenger: Passenger
## What tracks it once it is accepted.
var goal: Goal
## What it pays when it is done.
var reward_credits := 0
var reward_research: Dictionary[Race.Type, int] = {}


## Which kind of quest it is, for a save game.
func get_kind() -> String:
	return ""


## What it asks, as a short line such as "Rush to", which [method get_planet]'s name
## follows when there is one.
func get_ask() -> String:
	return ""


## The planet it is about, or null.
func get_planet() -> Planet:
	return null


## The transmission that offers it: the passenger, what they say, what they ask and the
## reward.
func get_transmission() -> Transmission:
	var transmission := Transmission.from_passenger(passenger)
	transmission.reward_credits = reward_credits
	transmission.reward_research = reward_research
	transmission.accept_text = "Yes"
	transmission.decline_text = "No"
	return transmission


## The player took it on: makes whatever change it asks for and builds [member goal].
func accept() -> void:
	pass


## The quest under way, for a save game. The passenger is kept by whoever saves it.
func to_save() -> Dictionary:
	var research := {}
	for race: Race.Type in reward_research:
		research[str(race)] = reward_research[race]
	return {
		"kind": get_kind(),
		"credits": reward_credits,
		"research": research,
		"goal": goal.to_save() if goal else {},
	}


## Puts back the reward [method to_save] gave. A kind of quest builds its goal first, then
## calls this, which puts its progress back.
func load_save(saved: Dictionary) -> void:
	reward_credits = int(saved.get("credits", 0))
	reward_research = {}
	var research: Dictionary = saved.get("research", {})
	for race: Variant in research:
		reward_research[int(str(race)) as Race.Type] = int(research[race])
	if goal:
		goal.load_save(saved.get("goal", {}))
