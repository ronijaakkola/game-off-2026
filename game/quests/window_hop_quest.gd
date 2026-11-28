class_name WindowHopQuest
extends HopQuest
## The [Castaway]'s quest in the second star system: a hop ([HopQuest]) whose hop location
## follows a moon and is only open while that moon is close to the star, inside the hot
## zone ([WindowHopGoal]). The moon is the one that swings deepest into the hot zone
## ([method find_moon]). They hop out as the bus halts near it or at it while the window
## is open, and a halt outside the window costs nothing but the wait for the next.

const WINDOW_KIND := "window_hop"
const WINDOW_LINES: Array[String] = [
	"Oh, hello. I'm going nowhere, really. But %s skims the star so prettily. Stop by it then?",
	"Ground control went quiet ages ago. I'd love to see %s right by the star. Stop there then?",
	"A lift? How kind. Drop me beside %s when it swings in close to the star, would you?",
]
## What the [Castaway] says once the player has taken them on board before.
const WINDOW_RETURNING_LINES: Array[String] = [
	"Ah, it's you. I drifted off again. This time I want %s, right as it grazes the star.",
	"We must stop meeting like this. Could you stop by %s when it swings in close to the star?",
]

## The moon they want to hop out near.
var planet: Planet


func plan(
	who: Passenger,
	_bus: FrameshiftBus,
	planets: Array[Planet],
	_waiting: WaitingPassengers,
	rng: RandomNumberGenerator
) -> bool:
	planet = find_moon(planets)
	if not planet:
		return false
	passenger = who
	who.destination = null
	who.fare = 0.0
	who.ride = RideProgress.new(FOREVER, FOREVER, who.type.stop_tolerance)
	reward_credits = get_reward(HOP_REWARD_CREDITS)
	reward_research = get_reward(HOP_REWARD_RESEARCH)
	var lines := WINDOW_RETURNING_LINES if who.returning else WINDOW_LINES
	_line = lines[rng.randi_range(0, lines.size() - 1)] % planet.display_name
	return true


func restore(saved: Dictionary, who: Passenger, planets: Dictionary[String, Planet]) -> bool:
	planet = planets.get(saved.get("planet", ""))
	if not planet:
		return false
	passenger = who
	goal = WindowHopGoal.new(who, planet)
	load_save(saved)
	return true


func get_kind() -> String:
	return WINDOW_KIND


func get_ask() -> String:
	return "Stop near"


func get_planet() -> Planet:
	return planet


func get_condition() -> String:
	return "when hot enough"


func get_transmission() -> Transmission:
	var transmission := super()
	transmission.quest_condition = get_condition()
	return transmission


func accept() -> void:
	goal = WindowHopGoal.new(passenger, planet)


func to_save() -> Dictionary:
	var saved := super()
	saved.erase("spot")
	return saved


## The moon among [param planets] that comes nearest its star, when that is inside the
## star's hot zone, or null when none does.
static func find_moon(planets: Array[Planet]) -> Planet:
	var found: Planet
	var nearest := INF
	for moon: Planet in planets:
		var orbits := moon.get_parent() as Planet
		if not orbits or not moon.star_system:
			continue
		var closest := orbits.orbit_radius - moon.orbit_radius
		if closest < minf(nearest, moon.star_system.get_hot_zone_radius()):
			found = moon
			nearest = closest
	return found
