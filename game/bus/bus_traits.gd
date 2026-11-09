class_name BusTraits
extends RefCounted
## The bus's traits: features an upgrade unlocks, which the bus either has or doesn't, such
## as the fuel forecast. Where a [Stat] is a number, a trait is a switch: whatever shows or
## does the feature asks [method has] first, and follows [signal changed] to show or hide it
## when it comes or goes. Upgrades hand theirs to [method add]. A trait added twice, as by
## two upgrades that both unlock it, stays until both take it back out.

## The bus gained or lost [param type]: [method has] for it changed.
signal changed(type: Type)

## A feature an upgrade unlocks. A [code].tres[/code] saves a type as its number, so add
## new ones only at the end.
enum Type {
	## Shows how much fuel the course will burn.
	FUEL_FORECAST,
	## Shows how many passengers wait at each planet, under its name.
	WAITING_MARKERS,
	## Lets passengers take short naps ([Comfort]).
	PILLOWS,
	## Lets passengers sleep long, with their clock slower still. Beats pillows.
	SLEEPING_PODS,
	## A little fun on board: happier passengers, and a slightly slower clock.
	GAMEPADS,
	## More fun, on top of the gamepads'.
	ENTERTAINMENT_SYSTEM,
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
