class_name VipTourQuest
extends Quest
## A quest from a [Vip], who calls from a planet ([VipCalls]): pick them up there and take
## them to every stop of their [Tour] in order ([VipTourGoal]). Whoever offers it makes the
## passenger first, with their tour and where they wait as their origin.

const KIND := "vip_tour"
## What it pays on top of their fare.
const REWARD_CREDITS := 900
const REWARD_RESEARCH := 10
const LINES: Array[String] = [
	"Darling! I'm stuck on %s and I simply must be seen on %s. In that order, please.",
	"You're the bus everyone talks about? Fetch me from %s. Then %s, and don't mix them up.",
	"My driver quit. Again. Collect me at %s, then it's %s. In that order, I have a schedule.",
	"I'm on %s and my fans are on %s. In exactly that order. [money]I tip well[/money].",
]

## Seconds they wait to be picked up once the player accepts. Whoever offers the quest
## sets it before the transmission opens.
var pick_up_seconds := 0.0

## What they say as they call in place of one of [constant LINES], as a [CustomVip]'s
## text. [code]{pick_up}[/code] and [code]{stops}[/code] name the planets.
var custom_text := ""

var _line := ""


func plan(
	who: Passenger,
	_bus: FrameshiftBus,
	_planets: Array[Planet],
	_waiting: WaitingPassengers,
	rng: RandomNumberGenerator
) -> bool:
	if not who.tour or not who.origin:
		return false
	passenger = who
	reward_credits = REWARD_CREDITS
	reward_research = REWARD_RESEARCH
	_line = LINES[rng.randi_range(0, LINES.size() - 1)]
	return true


func restore(saved: Dictionary, who: Passenger, _planets: Dictionary[String, Planet]) -> bool:
	if not who.tour:
		return false
	passenger = who
	goal = VipTourGoal.new(who, who.origin if who.origin else who.destination)
	(goal as VipTourGoal).boarded = true
	load_save(saved)
	return true


func get_kind() -> String:
	return KIND


func get_ask() -> String:
	if _is_boarded():
		return "Take to"
	if goal and not goal.is_active():
		return "Pick up at"
	var left := (goal as VipTourGoal).seconds_left if goal else pick_up_seconds
	return "Pick up in %s at" % Vip.format_time(left)


func get_planet() -> Planet:
	if not passenger:
		return null
	return passenger.destination if _is_boarded() else passenger.origin


func get_transmission() -> Transmission:
	var transmission := super()
	var names: Array[String] = []
	for stop: Planet in passenger.tour.stops:
		names.append(stop.display_name)
	var last: String = names.pop_back()
	var pick_up := passenger.origin.display_name
	var stops := ", ".join(names) + " and " + last
	transmission.text = _line % [pick_up, stops]
	if custom_text:
		transmission.text = custom_text.format({"pick_up": pick_up, "stops": stops})
	transmission.destination = null
	transmission.quest = get_ask()
	transmission.quest_planet = passenger.origin
	transmission.quest_stops = passenger.tour.stops
	return transmission


func accept() -> void:
	goal = VipTourGoal.new(passenger, passenger.origin)
	(goal as VipTourGoal).seconds_left = pick_up_seconds


func _is_boarded() -> bool:
	return goal != null and (goal as VipTourGoal).boarded
