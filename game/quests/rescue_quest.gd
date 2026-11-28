class_name RescueQuest
extends Quest
## A quest from the [Castaway], out of a capsule the bus collected ([CapsuleField]): take
## them on board and get them to where they are going before they expect to get there
## ([RescueGoal]). Accepting boards them ([QuestGiver]) and puts a reward on getting them
## there in time; declined, they stay adrift.

const KIND := "rescue"
## What it pays in each star system, in the order they open: credits and research points.
const REWARD_CREDITS: Array[int] = [140, 320, 640]
const REWARD_RESEARCH: Array[int] = [2, 4, 7]
const LINES: Array[String] = [
	"Oh, hello. Lovely out here, isn't it? I'm due on %s, though. In good time, if you can?",
	"Is it Tuesday already? I only meant to float a while. Could you drop me at %s soon?",
	"Such a quiet little capsule. But %s is expecting me, I think. Could you hurry a bit?",
	"Ground control stopped answering ages ago. Would you take me to %s? Quickly, ideally.",
]
## What the [Castaway] says once the player has rescued them before.
const RETURNING_LINES: Array[String] = [
	"Ah, it's you. I drifted off again, in every sense. %s once more, in good time?",
	"We must stop meeting like this. It is peaceful, mind. Could you hurry me to %s?",
	"I had a fresh capsule and everything. Never mind. To %s, quickly, if you would?",
	"Back so soon? I was just getting comfortable. %s, please, and no dawdling.",
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
	transmission.text = _say()
	transmission.quest = get_ask()
	transmission.quest_planet = get_planet()
	return transmission


func accept() -> void:
	goal = RescueGoal.new(passenger)


# What they say in the transmission.
func _say() -> String:
	return _line % passenger.destination.display_name
