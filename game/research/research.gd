class_name Research
extends RefCounted
## Which [Upgrade]s the player has researched, from every planet's research tree, and the
## state each one shows in its tree. [method research] applies an upgrade's modifiers and
## traits to the bus's [BusStats]; whoever calls it takes the cost off first.

## [param upgrade] was researched, and its effects are on the bus.
signal researched(upgrade: Upgrade)

## How an upgrade shows in its tree.
enum State {
	## Marked hidden, and something it requires isn't researched: a "?" tile.
	HIDDEN,
	## Something it requires isn't researched.
	LOCKED,
	## Everything it requires is researched, and the player can pay for it.
	AVAILABLE,
	## Everything it requires is researched, but the player can't pay for it.
	UNAFFORDABLE,
	## Researched: its effects are on the bus.
	RESEARCHED,
}

var _stats: BusStats
var _researched: Dictionary[Upgrade, bool] = {}


func _init(stats: BusStats) -> void:
	_stats = stats


## Whether [param upgrade] is researched.
func is_researched(upgrade: Upgrade) -> bool:
	return _researched.has(upgrade)


## Whether everything [param upgrade] requires is researched.
func is_unlocked(upgrade: Upgrade) -> bool:
	for required: Upgrade in upgrade.requires:
		if not is_researched(required):
			return false
	return true


## How [param upgrade] shows, with [param credits] and [param points], research points by
## race, to pay with.
func get_state(upgrade: Upgrade, credits: int, points: Dictionary[Race.Type, int]) -> State:
	if is_researched(upgrade):
		return State.RESEARCHED
	if not is_unlocked(upgrade):
		return State.HIDDEN if upgrade.hidden else State.LOCKED
	if not upgrade.can_afford(credits, points):
		return State.UNAFFORDABLE
	return State.AVAILABLE


## Marks [param upgrade] researched and puts its modifiers and traits on the bus. It doesn't
## check the cost or what it requires: [method get_state] does. Researched already, it does
## nothing.
func research(upgrade: Upgrade) -> void:
	if is_researched(upgrade):
		return
	_researched[upgrade] = true
	for modifier: StatModifier in upgrade.modifiers:
		_stats.add_modifier(modifier)
	for type: BusTraits.Type in upgrade.traits:
		_stats.get_traits().add(type)
	researched.emit(upgrade)
