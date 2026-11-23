class_name PhotoStopQuest
extends FlybyQuest
## A quest: the passenger wants a photo of a planet, so the bus comes to rest in space near
## it ([PhotoStopGoal]) before their stop: a fly past that has to stop in the zone. The
## planet is chosen as a fly past's is. Accepting it gives them the time the detour takes,
## stopping and charging again included.

const PHOTO_KIND := "photo_stop"
## What it pays in each star system, in the order they open: credits and research points.
## As an errand, since it costs a stop.
const PHOTO_REWARD_CREDITS: Array[int] = [140, 320, 640]
const PHOTO_REWARD_RESEARCH: Array[int] = [2, 4, 7]
const PHOTO_LINES: Array[String] = [
	"The board wants a photo of %s for the annual report. Can we stop near it so I can take one?",
	"I'm pitching a resort on %s. Stop near it so I can get a shot for the slides?",
	"My investors want to see %s. Could we hold still near it for a photo?",
]


func get_kind() -> String:
	return PHOTO_KIND


func get_ask() -> String:
	return "Stop near"


func _make_goal() -> FlybyGoal:
	return PhotoStopGoal.new(passenger, planet)


func _stops() -> bool:
	return true


func _get_lines() -> Array[String]:
	return PHOTO_LINES


func _get_reward_credits() -> Array[int]:
	return PHOTO_REWARD_CREDITS


func _get_reward_research() -> Array[int]:
	return PHOTO_REWARD_RESEARCH
