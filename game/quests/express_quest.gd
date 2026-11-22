class_name ExpressQuest
extends Quest
## A quest: the passenger changes their mind mid-ride and wants another planet, one that
## isn't on the route, to be the bus's next stop. Accepting it changes their destination
## ([method Passenger.reroute]), so it is always a detour for everyone else on board.

const KIND := "express"
## What it pays in each star system, in the order they open: credits and research points.
const REWARD_CREDITS: Array[int] = [140, 320, 640]
const REWARD_RESEARCH: Array[int] = [2, 4, 7]
const LINES: Array[String] = [
	"Change of plans! I need to be on %s instead. Can we go there next?",
	"I just got a call. Can you take me straight to %s?",
	"Wrong planet, my mistake. Make %s the next stop, please!",
]

## Where they want to go instead.
var planet: Planet
## The direct trip there in seconds, and the fare for it before the type's multiplier.
var trip_seconds := 0.0
var base_fare := 0.0
var _line := ""


## Makes it [param who]'s quest as things stand. False when no planet suits: it goes to
## one of [param planets] that is a detour ([method Quest.get_detours]). [param waiting]
## prices and times the trip from where the bus is, to where the planet will be when the
## bus could reach it.
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
	var flying := bus.state == FrameshiftBus.State.FLYING
	var distance := get_chase_distance(bus, planet)
	trip_seconds = waiting.get_trip_seconds(distance, flying) + PARK_SECONDS
	base_fare = distance * waiting.get_fare_per_unit()
	reward_credits = get_reward(REWARD_CREDITS)
	reward_research = get_reward(REWARD_RESEARCH)
	_line = LINES[rng.randi_range(0, LINES.size() - 1)]
	return true


## Makes it the quest [method to_save] gave, about [param who], who already goes where it
## sent them.
func restore(saved: Dictionary, who: Passenger, _planets: Dictionary[String, Planet]) -> bool:
	passenger = who
	planet = who.destination
	goal = ExpressGoal.new(who)
	load_save(saved)
	return true


func get_kind() -> String:
	return KIND


func get_ask() -> String:
	return "Go straight to"


func get_planet() -> Planet:
	return planet


func get_transmission() -> Transmission:
	var transmission := super()
	transmission.text = _line % _planet_name()
	transmission.quest = "Make the next stop"
	transmission.quest_planet = planet
	return transmission


func accept() -> void:
	passenger.reroute(planet, trip_seconds, base_fare)
	goal = ExpressGoal.new(passenger)


func _planet_name() -> String:
	return planet.display_name if planet.display_name else String(planet.name)
