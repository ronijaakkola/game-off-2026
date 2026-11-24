class_name FlybyQuest
extends Quest
## A quest: the passenger wants to see a planet from the window, so the bus flies past it
## before their stop ([FlybyGoal]), without stopping there. The planet is a detour
## ([method Quest.get_detours]) the bus isn't near already and won't come near by docking
## where it is going anyway, as at a planet's moon, and never one that orbits inside the
## heat zone. Accepting it gives them the time the detour takes.

const KIND := "flyby"
## What it pays in each star system, in the order they open: credits and research points.
const REWARD_CREDITS: Array[int] = [100, 230, 460]
const REWARD_RESEARCH: Array[int] = [2, 3, 7]
const LINES: Array[String] = [
	"I've never seen %s up close. Could we fly past it so I can take a picture?",
	"My gran lives on %s. Fly past it and I'll wave to her!",
	"They say %s is lovely this time of year. Can we fly past for a look?",
	"My kids won't believe I saw %s. Fly past it so I can get a photo?",
]

## The planet they want to see.
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
	var stops := bus.get_route_planets()
	stops.append(who.destination)
	var others: Array[Planet] = []
	for other: Planet in get_detours(who, bus, planets):
		var near := _is_near(bus.global_position, other) or _is_near_any(stops, other)
		if not near and not _is_in_heat(bus, other):
			others.append(other)
	if others.is_empty():
		return false
	passenger = who
	planet = others[rng.randi_range(0, others.size() - 1)]
	detour_seconds = get_detour_seconds(who, bus, planet, waiting, _stops())
	reward_credits = get_reward(_get_reward_credits())
	reward_research = get_reward(_get_reward_research())
	var lines := _get_lines()
	_line = lines[rng.randi_range(0, lines.size() - 1)]
	return true


func restore(saved: Dictionary, who: Passenger, planets: Dictionary[String, Planet]) -> bool:
	planet = planets.get(saved.get("planet", ""))
	if not planet:
		return false
	passenger = who
	goal = _make_goal()
	load_save(saved)
	return true


func get_kind() -> String:
	return KIND


func get_ask() -> String:
	return "Fly past"


func get_planet() -> Planet:
	return planet


func get_transmission() -> Transmission:
	var transmission := super()
	transmission.text = _line % planet.display_name
	transmission.quest = get_ask()
	transmission.quest_planet = planet
	return transmission


func accept() -> void:
	passenger.ride.extend(detour_seconds, passenger.type.slack)
	goal = _make_goal()


# What tracks it, about [member passenger] and [member planet].
func _make_goal() -> FlybyGoal:
	return FlybyGoal.new(passenger, planet)


# Whether the bus stops on the way for it, as a photo stop's does, so the detour counts the
# time to stop and charge again.
func _stops() -> bool:
	return false


func _get_lines() -> Array[String]:
	return LINES


func _get_reward_credits() -> Array[int]:
	return REWARD_CREDITS


func _get_reward_research() -> Array[int]:
	return REWARD_RESEARCH


# Whether [param point] is within the flyby's reach of [param other].
static func _is_near(point: Vector3, other: Planet) -> bool:
	var distance := point.distance_to(other.get_body_global_position())
	return distance <= other.get_body_radius() + FlybyGoal.REACH


# Whether docking at any of [param stops] brings the bus within the flyby's reach of
# [param other], as things stand.
static func _is_near_any(stops: Array[Planet], other: Planet) -> bool:
	for stop: Planet in stops:
		var gap := stop.get_body_global_position().distance_to(other.get_body_global_position())
		if gap <= other.get_body_radius() + FlybyGoal.REACH + stop.get_body_radius():
			return true
	return false


# Whether [param other] orbits its star inside the heat zone. A moon goes by its planet.
static func _is_in_heat(bus: FrameshiftBus, other: Planet) -> bool:
	var parent := other.get_parent() as Planet
	var orbits := parent if parent else other
	return orbits.orbit_radius <= bus.temperature.zone_radius
