class_name Quest
extends RefCounted
## What a passenger asks of the player in a transmission, for a reward: the [member goal]
## that tracks it, what it pays once that is completed, and the transmission that offers
## it. The [QuestGiver] offers it, and tracks and pays it once the player accepts. Each
## kind of quest extends this with what it asks, and is listed in [QuestKinds] so a save
## can put it back.

## Seconds the bus takes to park, on top of a flight.
const PARK_SECONDS := 2.0

## Which star system the bus works in, counted from 0 in the order they open: a quest pays
## by it. Whoever plans the quest sets it first.
var level := 0
## Who asks.
var passenger: Passenger
## What tracks it once it is accepted.
var goal: Goal
## What it pays when it is done.
var reward_credits := 0
var reward_research := 0


## Makes it a passenger's quest as things stand, on the bus among the run's planets. False
## when it can't be asked now, as when no planet suits.
## Not a static constructor: one that builds its own class, in a script that extends
## another, keeps both scripts in use when Godot 4.7.2 quits, which fails the checks.
func plan(
	_who: Passenger,
	_bus: FrameshiftBus,
	_planets: Array[Planet],
	_waiting: WaitingPassengers,
	_rng: RandomNumberGenerator
) -> bool:
	return false


## Makes it the quest [method to_save] gave, about a passenger on board, with its planet
## found by name. False when it can't be put back.
func restore(_saved: Dictionary, _who: Passenger, _planets: Dictionary[String, Planet]) -> bool:
	return false


## Which kind of quest it is, for a save game.
func get_kind() -> String:
	return ""


## What it asks, as a short line such as "Rush to", which [method get_planet]'s name
## follows when there is one.
func get_ask() -> String:
	return ""


## The planet it is about, or null.
func get_planet() -> Planet:
	return null


## The transmission that offers it: the passenger, what they say, what they ask and the
## reward.
func get_transmission() -> Transmission:
	var transmission := Transmission.from_passenger(passenger)
	transmission.reward_credits = reward_credits
	transmission.reward_research = reward_research
	transmission.accept_text = "Yes"
	transmission.decline_text = "No"
	return transmission


## The player took it on: makes whatever change it asks for and builds [member goal].
func accept() -> void:
	pass


## It is under way, its passenger in [param _cabin], as taken on or put back from a save:
## makes any change it leaves on the cabin for the rest of their ride, as a rock ride's love
## of the rocks. A kind with one overrides this.
func begin(_cabin: Cabin) -> void:
	pass


## The quest under way, for a save game. The passenger is kept by whoever saves it.
func to_save() -> Dictionary:
	return {
		"kind": get_kind(),
		"credits": reward_credits,
		"research": reward_research,
		"planet": String(get_planet().name) if get_planet() else "",
		"goal": goal.to_save() if goal else {},
	}


## Puts back the reward [method to_save] gave. A kind of quest builds its goal first, then
## calls this, which puts its progress back.
func load_save(saved: Dictionary) -> void:
	reward_credits = int(saved.get("credits", 0))
	reward_research = Ledger.count_research(saved.get("research", 0))
	if goal:
		goal.load_save(saved.get("goal", {}))


## What a quest pays in the star system the bus works in ([member level]), from
## [param by_level], which has one amount for each system in the order they open. Past its
## end, the last one.
func get_reward(by_level: Array[int]) -> int:
	return by_level[mini(level, by_level.size() - 1)]


## The planets among [param planets] going to which is a detour for [param who] and for
## [param bus]: not where they are going, where they boarded, where the bus is docked, or
## on its route.
static func get_detours(
	who: Passenger, bus: FrameshiftBus, planets: Array[Planet]
) -> Array[Planet]:
	var on_route := bus.get_route_planets()
	var others: Array[Planet] = []
	for other: Planet in planets:
		var known := other in [who.destination, who.origin, bus.get_docked_planet()]
		if not known and other not in on_route:
			others.append(other)
	return others


## How far [param bus] flies to catch [param planet], which moves meanwhile: the straight
## distance to where it will be by then, taking its speed now as steady.
static func get_chase_distance(bus: FrameshiftBus, planet: Planet) -> float:
	var from := bus.global_position
	var at := planet.get_body_global_position()
	var velocity := planet.get_body_velocity()
	var distance := from.distance_to(at)
	for i: int in 3:
		distance = from.distance_to(at + velocity * (distance / bus.max_speed))
	return distance


## How many seconds going by [param planet] adds to [param who]'s ride on [param bus], over
## flying straight to where they are going from here: the flight, and with [param stops],
## the time to park there and charge again.
static func get_detour_seconds(
	who: Passenger, bus: FrameshiftBus, planet: Planet, waiting: WaitingPassengers, stops: bool
) -> float:
	var from := bus.global_position
	var via := planet.get_body_global_position()
	var to := who.destination.get_body_global_position()
	var extra := get_chase_distance(bus, planet) + via.distance_to(to) - from.distance_to(to)
	var seconds := waiting.get_trip_seconds(maxf(extra, 0.0), not stops)
	return seconds + PARK_SECONDS if stops else seconds
