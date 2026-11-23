class_name WarpQuest
extends Quest
## A quest: the passenger has never been through a warp gate and wants to, so the bus warps
## with them on board ([WarpGoal]), from either gate, before their stop. Only where the
## run's planets have a gate. Accepting it gives them the time it takes to dock at the
## nearest gate's planet and come out of the other.

const KIND := "warp"
## What it pays in each star system, in the order they open: credits and research points.
## As an errand: the stop at the gate, and the fuel the warp takes.
const REWARD_CREDITS: Array[int] = [140, 320, 640]
const REWARD_RESEARCH: Array[int] = [2, 4, 7]
const LINES: Array[String] = [
	"I've flown all over and never once taken a warp drive. Could we try it?",
	"Everyone at the office has warped but me. Take the warp drive before my stop?",
	"I've always wondered what a warp drive feels like. Can we take one?",
]

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
	var nearest: Planet
	for planet: Planet in planets:
		if not WarpGate.twin_of(planet):
			continue
		var closer := (
			not nearest or get_chase_distance(bus, planet) < get_chase_distance(bus, nearest)
		)
		if closer:
			nearest = planet
	if not nearest:
		return false
	passenger = who
	# The stop at the gate and the far dock: the warp itself is about as quick as flying
	# the twins' short way in, so only the parking is added for the far side.
	detour_seconds = get_detour_seconds(who, bus, nearest, waiting, true) + PARK_SECONDS
	reward_credits = get_reward(REWARD_CREDITS)
	reward_research = get_reward(REWARD_RESEARCH)
	_line = LINES[rng.randi_range(0, LINES.size() - 1)]
	return true


func restore(saved: Dictionary, who: Passenger, _planets: Dictionary[String, Planet]) -> bool:
	passenger = who
	goal = WarpGoal.new(who)
	load_save(saved)
	return true


func get_kind() -> String:
	return KIND


func get_ask() -> String:
	return "Take the warp drive"


func get_transmission() -> Transmission:
	var transmission := super()
	transmission.text = _line
	transmission.quest = get_ask()
	return transmission


func accept() -> void:
	passenger.ride.extend(detour_seconds, passenger.type.slack)
	goal = WarpGoal.new(passenger)
