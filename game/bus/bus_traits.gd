class_name BusTraits
extends RefCounted
## The bus's traits: features an upgrade unlocks, which the bus either has or doesn't, such
## as the fuel forecast. Where a [Stat] is a number, a trait is a switch: whatever shows or
## does the feature asks [method has] first, and follows [signal changed] to show or hide it
## when it comes or goes. Upgrades hand theirs to [method add]. A trait added twice, as by
## two upgrades that both unlock it, stays until both take it back out.

## The bus gained or lost [param type]: [method has] for it changed.
signal changed(type: Type)

## A feature an upgrade unlocks. A [code].tres[/code] saves a type as its number, so each
## keeps its own: a new one takes the next unused number.
enum Type {
	## Shows how much fuel the course will burn.
	FUEL_FORECAST = 0,
	## Shows how many passengers wait at each planet, under its name.
	WAITING_MARKERS = 1,
	## Lets passengers take short naps ([Comfort]).
	PILLOWS = 2,
	## Lets passengers sleep long, with their clock slower still. Beats pillows.
	SLEEPING_PODS = 3,
	## Games on board: happier passengers, and longer shows on the entertainment system.
	GAMING_SYSTEM = 4,
	## Shows on board: happier passengers, who now and then watch one, their clock slower
	## while they do.
	ENTERTAINMENT_SYSTEM = 5,
	## Hungry passengers fetch their own food from it, one at a time ([Amenity]).
	FOOD_DISPENSER = 6,
	## Robots bring hungry passengers their food, several at a time ([Amenity]).
	SERVING_ROBOTS = 7,
	## The pointer over a planet shows who waits there, with the waiting markers.
	STATION_CAMERAS = 8,
	## Someone picked up rides happier the longer they waited ([WaitingPassengers]).
	WAITING_LOUNGE = 9,
	## Happy passengers tip on top of what they pay ([Cabin]).
	TIP_JAR = 10,
	## Someone picked up asks for their first things later ([Cabin]).
	FREE_COFFEE = 11,
	## Those in a line lean harder toward a destination someone in it already has
	## ([WaitingPassengers]).
	TIMETABLES = 12,
}

# How many times each trait the bus has was added and not yet taken out.
var _counts: Dictionary[Type, int] = {}


## Whether the bus has [param type].
func has(type: Type) -> bool:
	return _counts.has(type)


## Gives the bus [param type] until [method remove] takes it back out.
func add(type: Type) -> void:
	_counts[type] = _counts.get(type, 0) + 1
	if _counts[type] == 1:
		changed.emit(type)


## Takes [param type] back out. Added twice, the bus keeps it until it is taken out twice.
func remove(type: Type) -> void:
	if not _counts.has(type):
		return
	_counts[type] -= 1
	if _counts[type] > 0:
		return
	_counts.erase(type)
	changed.emit(type)
