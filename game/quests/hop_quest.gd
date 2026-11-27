class_name HopQuest
extends RescueQuest
## The [Castaway]'s quest in the first star system, out of a capsule the bus collected: they
## are going nowhere, and want to hop out at a nice spot in open space ([HopGoal]). The spot
## is across the star from where they were found, just inside the outermost orbit
## ([method find_spot]). Asking it makes them a passenger with no destination, no fare and
## no time they expect, so the reward is all they pay, and such a passenger is as happy as
## can be all ride and asks for nothing ([Passenger]); accepting boards them ([QuestGiver]).
## Once the bus has come to rest at the spot they hop out of it ([CapsuleField]), rating
## nothing.

const HOP_KIND := "hop"
## What it pays in each star system, in the order they open: credits and research points.
const HOP_REWARD_CREDITS: Array[int] = [140, 320, 640]
const HOP_REWARD_RESEARCH: Array[int] = [2, 4, 7]
## How far inside the outermost orbit the spot is, in units: clear of that orbit's planet
## as it passes, and inside the edge the camera stops at.
const INSET := 1.3
## A trip time no ride outlasts, in seconds, for someone who expects to get nowhere.
const FOREVER := 1.0e6
const HOP_LINES: Array[String] = [
	"Oh, hello. I'm not going anywhere, really. But I know a lovely spot. Drop me there?",
	"Ground control stopped answering ages ago. There's a quiet spot I like. Stop there for me?",
	"A lift? How kind. Nowhere in particular. Well, one spot has a view. Could you stop there?",
]
## What the [Castaway] says once the player has taken them on board before.
const HOP_RETURNING_LINES: Array[String] = [
	"Ah, it's you. I drifted off again, in every sense. I've found a new spot. Drop me there?",
	"We must stop meeting like this. There's a spot with a better view. Would you stop there?",
]

## Where they want to hop out, in global space.
var spot := Vector3.ZERO


func plan(
	who: Passenger,
	bus: FrameshiftBus,
	planets: Array[Planet],
	_waiting: WaitingPassengers,
	rng: RandomNumberGenerator
) -> bool:
	var system: StarSystem = planets[0].star_system if not planets.is_empty() else null
	if not system:
		return false
	passenger = who
	who.destination = null
	who.fare = 0.0
	who.ride = RideProgress.new(FOREVER, FOREVER, who.type.stop_tolerance)
	spot = find_spot(system, bus.global_position)
	reward_credits = get_reward(HOP_REWARD_CREDITS)
	reward_research = get_reward(HOP_REWARD_RESEARCH)
	var lines := HOP_RETURNING_LINES if who.returning else HOP_LINES
	_line = lines[rng.randi_range(0, lines.size() - 1)]
	return true


func restore(saved: Dictionary, who: Passenger, _planets: Dictionary[String, Planet]) -> bool:
	var at: Array = saved.get("spot", [])
	if at.size() != 3:
		return false
	passenger = who
	spot = Vector3(float(at[0]), float(at[1]), float(at[2]))
	goal = HopGoal.new(who, spot)
	load_save(saved)
	return true


func get_kind() -> String:
	return HOP_KIND


func get_ask() -> String:
	return "Stop at the hop location"


func get_planet() -> Planet:
	return null


func accept() -> void:
	goal = HopGoal.new(passenger, spot)


func to_save() -> Dictionary:
	var saved := super()
	saved["spot"] = [spot.x, spot.y, spot.z]
	return saved


## Where someone found at [param found] wants to hop out in [param system]: across its star
## from there, [constant INSET] inside its outermost orbit, on the orbit plane.
static func find_spot(system: StarSystem, found: Vector3) -> Vector3:
	var star := system.global_position
	var outer := 0.0
	for planet: Planet in system.get_planets():
		outer = maxf(outer, RouteStop.flat(planet.get_body_global_position() - star).length())
	var across := RouteStop.flat(star - found)
	across = across.normalized() if across.length() > 0.01 else Vector3.RIGHT
	return star + across * maxf(outer - INSET, 0.0)


func _say() -> String:
	return _line
