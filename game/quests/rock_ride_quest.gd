class_name RockRideQuest
extends Quest
## A quest, a rock ride: the passenger wants a thrill, so the bus flies among an asteroid
## field's rocks for [constant RockRideGoal.SECONDS] with them on board ([RockRideGoal]).
## The rocks' knocks lift them rather than shake them for the rest of their ride
## ([method Cabin.thrill]), while everyone else takes them as ever. Only where
## [member field] shows. Accepting it gives them the time it takes to reach the rocks, ride
## them and come back.

const KIND := "rock_ride"
## What it pays in each star system, in the order they open: credits and research points.
## As an errand: the rocks cost the time and everyone else's mood.
const REWARD_CREDITS: Array[int] = [140, 320, 640]
const REWARD_RESEARCH: Array[int] = [2, 4, 7]
const LINES: Array[String] = [
	"Board meetings bore me to tears. Fly us through the asteroid field, I want a thrill!",
	"I need some excitement before my presentation. Take us through those rocks!",
	"My therapist says I need more adventure. Can we fly through the asteroids?",
]

## The field whose rocks they want. Whoever plans the quest sets it first.
var field: AsteroidField
## Seconds the detour adds to their ride.
var detour_seconds := 0.0
var _line := ""


func plan(
	who: Passenger,
	bus: FrameshiftBus,
	_planets: Array[Planet],
	waiting: WaitingPassengers,
	rng: RandomNumberGenerator
) -> bool:
	if not field or not field.is_visible_in_tree() or not field.belt:
		return false
	passenger = who
	var flat := field.to_local(bus.global_position)
	var middle := (field.belt.inner_radius + field.belt.outer_radius) * 0.5
	var gap := absf(Vector2(flat.x, flat.z).length() - middle)
	# There and back, and the seconds among the rocks, which crawl at a third of the speed.
	detour_seconds = waiting.get_trip_seconds(2.0 * gap, true) + RockRideGoal.SECONDS
	reward_credits = get_reward(REWARD_CREDITS)
	reward_research = get_reward(REWARD_RESEARCH)
	_line = LINES[rng.randi_range(0, LINES.size() - 1)]
	return true


func restore(saved: Dictionary, who: Passenger, _planets: Dictionary[String, Planet]) -> bool:
	passenger = who
	goal = RockRideGoal.new(who)
	load_save(saved)
	return true


func get_kind() -> String:
	return KIND


func get_ask() -> String:
	return "Fly through the rocks"


func get_transmission() -> Transmission:
	var transmission := super()
	transmission.text = _line
	transmission.quest = get_ask()
	return transmission


func accept() -> void:
	passenger.ride.extend(detour_seconds, passenger.type.slack)
	goal = RockRideGoal.new(passenger)
