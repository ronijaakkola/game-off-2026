class_name SaunaQuest
extends Quest
## A quest, a sauna: the passenger misses a proper sauna, so the bus flies near the star
## until it runs past its comfortable temperature with them on board ([SaunaGoal]). For the
## rest of their ride the heat lifts them rather than wearing them down
## ([method Cabin.get_comfort]), while everyone else takes it as ever. Only where the star
## has a heat zone, and not while the bus is hot already. Accepting it gives them the time
## it takes to reach the hot zone's edge, heat up there and come back.

const KIND := "sauna"
## What it pays in each star system, in the order they open: credits and research points.
## As an errand: the heat costs the time and everyone else's mood.
const REWARD_CREDITS: Array[int] = [140, 320, 640]
const REWARD_RESEARCH: Array[int] = [2, 4, 7]
const LINES: Array[String] = [
	"Back home every office has a sauna. Could you take us near the star and heat it up?",
	"These meetings leave me ice cold. Turn the heat up, I want to sweat!",
	"My doctor prescribed a good sweat. Fly us close to the star until it's properly hot?",
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
	var heat := bus.temperature
	if planets.is_empty() or heat.zone_radius <= 0.0 or heat.is_uncomfortable():
		return false
	passenger = who
	var star := planets[0].light_source
	var flat := Vector2(bus.global_position.x - star.x, bus.global_position.z - star.z)
	var gap := maxf(flat.length() - heat.hot_zone_radius, 0.0)
	# There and back, and the time to heat up at the hot zone's edge.
	var warming := (heat.comfortable_temperature - heat.temperature) / heat.hot_rate
	detour_seconds = waiting.get_trip_seconds(2.0 * gap, true) + maxf(warming, 0.0)
	reward_credits = get_reward(REWARD_CREDITS)
	reward_research = get_reward(REWARD_RESEARCH)
	_line = LINES[rng.randi_range(0, LINES.size() - 1)]
	return true


func restore(saved: Dictionary, who: Passenger, _planets: Dictionary[String, Planet]) -> bool:
	passenger = who
	goal = SaunaGoal.new(who)
	load_save(saved)
	return true


func get_kind() -> String:
	return KIND


func get_ask() -> String:
	return "Heat the bus"


func get_transmission() -> Transmission:
	var transmission := super()
	transmission.text = _line
	transmission.quest = get_ask()
	return transmission


func accept() -> void:
	passenger.ride.extend(detour_seconds, passenger.type.slack)
	goal = SaunaGoal.new(passenger)
