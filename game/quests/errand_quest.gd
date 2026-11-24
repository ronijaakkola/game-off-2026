class_name ErrandQuest
extends Quest
## A quest: the passenger has something to do at another planet, so the bus stops there
## before their own stop ([ErrandGoal]), in any order with its other stops. The planet is a
## detour ([method Quest.get_detours]). Accepting it gives them the time the detour takes,
## and the stop there doesn't count against the stops they tolerate.

const KIND := "errand"
## What it pays in each star system, in the order they open: credits and research points.
const REWARD_CREDITS: Array[int] = [140, 320, 640]
const REWARD_RESEARCH: Array[int] = [2, 4, 7]
const LINES: Array[String] = [
	"I need to pick up a package on %s. Can we stop there before my stop?",
	"I left my keys at a friend's on %s. Could we stop there on the way?",
	"It's my mum's birthday! Can we stop at %s so I can buy her flowers?",
	"I promised to feed my neighbour's cat on %s. Can we stop there first?",
	"My library book is due back on %s today. Could we stop there on the way?",
	"The best dumplings in the system are on %s. Stop there before my stop?",
]
## What a Business passenger says instead.
const BUSINESS_LINES: Array[String] = [
	"I left the contract documents on %s! Can we stop there before my meeting?",
	"I have to sign some papers on %s. Could we stop there on the way?",
	"My client is waiting on %s. A quick stop there first, please?",
	"I forgot my laptop at the office on %s. Can we swing by and stop there?",
]

## Where their errand is.
var planet: Planet
## Seconds the detour adds to their ride.
var detour_seconds := 0.0
var _line := ""


func plan(
	who: Passenger,
	bus: FrameshiftBus,
	planets: Array[Planet],
	waiting: WaitingPassengers,
	rng: RandomNumberGenerator
) -> bool:
	var others := get_detours(who, bus, planets)
	if others.is_empty():
		return false
	passenger = who
	planet = others[rng.randi_range(0, others.size() - 1)]
	detour_seconds = get_detour_seconds(who, bus, planet, waiting, true)
	reward_credits = get_reward(REWARD_CREDITS)
	reward_research = get_reward(REWARD_RESEARCH)
	var lines := BUSINESS_LINES if who.type == waiting.business else LINES
	_line = lines[rng.randi_range(0, lines.size() - 1)]
	return true


func restore(saved: Dictionary, who: Passenger, planets: Dictionary[String, Planet]) -> bool:
	planet = planets.get(saved.get("planet", ""))
	if not planet:
		return false
	passenger = who
	passenger.errand = planet
	goal = ErrandGoal.new(who, planet)
	load_save(saved)
	return true


func get_kind() -> String:
	return KIND


func get_ask() -> String:
	return "Stop at"


func get_planet() -> Planet:
	return planet


func get_transmission() -> Transmission:
	var transmission := super()
	transmission.text = _line % planet.display_name
	transmission.quest = get_ask()
	transmission.quest_planet = planet
	return transmission


func accept() -> void:
	passenger.errand = planet
	passenger.ride.extend(detour_seconds, passenger.type.slack)
	goal = ErrandGoal.new(passenger, planet)
