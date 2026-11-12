class_name Research
extends RefCounted
## Which [Upgrade]s the player has researched, from every research tree, which of the
## three stages are open, and the state each upgrade shows in its tree. Each tree splits
## into stages by row ([method get_stage]); the first is open from the start, and each
## promotion opens the next ([method open_next_stage]). [method research] applies an
## upgrade's modifiers and traits to the bus's [BusStats]; whoever calls it takes the cost
## off first.

## [param upgrade] was researched, and its effects are on the bus.
signal researched(upgrade: Upgrade)
## [param stage] opened, counting from 0.
signal stage_opened(stage: int)

## How an upgrade shows in its tree.
enum State {
	## Marked hidden, and something it requires isn't researched: a silhouette.
	HIDDEN,
	## Something it requires isn't researched.
	LOCKED,
	## Everything it requires is researched, and the player can pay for it.
	AVAILABLE,
	## Everything it requires is researched, but the player can't pay for it.
	UNAFFORDABLE,
	## Researched: its effects are on the bus.
	RESEARCHED,
	## In a stage that isn't open yet: it needs a promotion. A silhouette, as a hidden one.
	NEEDS_PROMOTION,
}

## How many stages each tree splits into.
const STAGES := 3
## How many rows of a tree each stage holds; the last stage holds the rest.
const ROWS_PER_STAGE := 2

var _stats: BusStats
var _researched: Dictionary[Upgrade, bool] = {}
var _open_stages := 1


func _init(stats: BusStats) -> void:
	_stats = stats


## The stage [param upgrade] is in, counting from 0, by its row in its tree.
static func get_stage(upgrade: Upgrade) -> int:
	return get_stage_of_row(upgrade.tier)


## The stage the row [param tier] of a tree is in, counting both from 0.
static func get_stage_of_row(tier: int) -> int:
	return mini(tier / ROWS_PER_STAGE, STAGES - 1)


## Whether [param upgrade] is researched.
func is_researched(upgrade: Upgrade) -> bool:
	return _researched.has(upgrade)


## Whether everything [param upgrade] requires is researched.
func is_unlocked(upgrade: Upgrade) -> bool:
	for required: Upgrade in upgrade.requires:
		if not is_researched(required):
			return false
	return true


## Whether [param stage], counting from 0, is open.
func is_stage_open(stage: int) -> bool:
	return stage < _open_stages


## How many stages are open, counting the first.
func get_open_stages() -> int:
	return _open_stages


## Opens the next stage, as a promotion does. With every stage open, it does nothing.
func open_next_stage() -> void:
	if _open_stages >= STAGES:
		return
	_open_stages += 1
	stage_opened.emit(_open_stages - 1)


## How [param upgrade] shows, with [param credits] and [param points], research points by
## race, to pay with.
func get_state(upgrade: Upgrade, credits: int, points: Dictionary[Race.Type, int]) -> State:
	if is_researched(upgrade):
		return State.RESEARCHED
	if not is_stage_open(get_stage(upgrade)):
		return State.NEEDS_PROMOTION
	if not is_unlocked(upgrade):
		return State.HIDDEN if upgrade.hidden else State.LOCKED
	if not upgrade.can_afford(credits, points):
		return State.UNAFFORDABLE
	return State.AVAILABLE


## Marks [param upgrade] researched and puts its modifiers and traits on the bus. It doesn't
## check the cost, the stage or what it requires: [method get_state] does. Researched
## already, it does nothing.
func research(upgrade: Upgrade) -> void:
	if is_researched(upgrade):
		return
	_researched[upgrade] = true
	for modifier: StatModifier in upgrade.modifiers:
		_stats.add_modifier(modifier)
	for type: BusTraits.Type in upgrade.traits:
		_stats.get_traits().add(type)
	researched.emit(upgrade)
