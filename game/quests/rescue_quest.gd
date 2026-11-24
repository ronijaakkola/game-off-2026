class_name RescueQuest
extends Quest
## A quest from a passenger the bus picked up from a capsule adrift ([CapsuleField]): get
## them to where they are going before they expect to get there ([RescueGoal]). Accepting
## changes nothing about their ride; it only puts a reward on getting them there in time.

const KIND := "rescue"
## What it pays in each star system, in the order they open: credits and research points.
const REWARD_CREDITS: Array[int] = [140, 320, 640]
const REWARD_RESEARCH: Array[int] = [2, 4, 7]
const LINES: Array[String] = [
	"Thanks for picking me up! My air was nearly out. Can you get me to %s in good time?",
	"I've been drifting for hours! My family on %s must be worried sick. Could you hurry?",
	"You saved me! My ship broke down on the way to %s. Can you get me there quickly?",
	"I thought nobody would ever come! Please, get me to %s before they give up on me.",
]
## What the [Castaway] says once the player has rescued them before.
const RETURNING_LINES: Array[String] = [
	"You again! I swear the hatch opens by itself. Could you get me to %s in good time?",
	"Adrift again, would you believe it? Thanks for coming back for me. To %s, quickly?",
	"I knew you'd find me! My new capsule is worse than the last. Please hurry me to %s.",
	"Me again, sorry! I only stepped out for some air. Can you rush me to %s?",
]

var _line := ""


func plan(
	who: Passenger,
	_bus: FrameshiftBus,
	_planets: Array[Planet],
	_waiting: WaitingPassengers,
	rng: RandomNumberGenerator
) -> bool:
	if not who.destination:
		return false
	passenger = who
	reward_credits = get_reward(REWARD_CREDITS)
	reward_research = get_reward(REWARD_RESEARCH)
	var lines := RETURNING_LINES if who.returning else LINES
	_line = lines[rng.randi_range(0, lines.size() - 1)]
	return true


func restore(saved: Dictionary, who: Passenger, _planets: Dictionary[String, Planet]) -> bool:
	if not who.destination:
		return false
	passenger = who
	goal = RescueGoal.new(who)
	load_save(saved)
	return true


func get_kind() -> String:
	return KIND


func get_ask() -> String:
	return "Rush to"


func get_planet() -> Planet:
	return passenger.destination if passenger else null


func get_transmission() -> Transmission:
	var transmission := super()
	transmission.text = _line % passenger.destination.display_name
	transmission.quest = get_ask()
	transmission.quest_planet = passenger.destination
	return transmission


func accept() -> void:
	goal = RescueGoal.new(passenger)
