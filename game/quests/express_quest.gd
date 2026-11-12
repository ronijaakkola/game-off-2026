class_name ExpressQuest
extends Quest
## A quest: the passenger changes their mind mid-ride and wants another planet, one that
## isn't on the route, to be the bus's next stop. Accepting it changes their destination
## ([method Passenger.reroute]), so it is always a detour for everyone else on board.

const KIND := "express"
## Seconds the bus takes to park, on top of the flight.
const PARK_SECONDS := 2.0
## What it pays: credits, and research points of the passenger's race.
const REWARD_CREDITS := 30
const REWARD_RESEARCH := 2
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
## one of [param planets] that isn't where they are going, where they boarded or on
## [param bus]'s route. [param waiting] prices and times the trip from where the bus is, to
## where the planet will be when the bus could reach it.
## Not a static constructor: one that builds its own class, in a script that extends
## another, keeps both scripts in use when Godot 4.7.2 quits, which fails the checks.
func plan(
	who: Passenger,
	bus: FrameshiftBus,
	planets: Array[Planet],
	waiting: WaitingPassengers,
	rng: RandomNumberGenerator
) -> bool:
	var on_route := bus.get_route_planets()
	var others: Array[Planet] = []
	for other: Planet in planets:
		var known := other in [who.destination, who.origin, bus.get_docked_planet()]
		if not known and other not in on_route:
			others.append(other)
	if others.is_empty():
		return false
	passenger = who
	planet = others[rng.randi_range(0, others.size() - 1)]
	var flying := bus.state == FrameshiftBus.State.FLYING
	var distance := _chase_distance(bus, planet)
	trip_seconds = waiting.get_trip_seconds(distance, flying) + PARK_SECONDS
	base_fare = distance * waiting.fare_per_unit
	reward_credits = REWARD_CREDITS
	reward_research = {who.race: REWARD_RESEARCH}
	_line = LINES[rng.randi_range(0, LINES.size() - 1)]
	return true


## Makes it the quest [method to_save] gave, about [param who], who already goes where it
## sent them.
func restore(saved: Dictionary, who: Passenger) -> void:
	passenger = who
	planet = who.destination
	goal = ExpressGoal.new(who)
	load_save(saved)


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


# How far the bus flies to catch [param planet], which moves meanwhile: the straight
# distance to where it will be by then, taking its speed now as steady.
static func _chase_distance(bus: FrameshiftBus, planet: Planet) -> float:
	var from := bus.global_position
	var at := planet.get_body_global_position()
	var velocity := planet.get_body_velocity()
	var distance := from.distance_to(at)
	for i: int in 3:
		distance = from.distance_to(at + velocity * (distance / bus.max_speed))
	return distance
