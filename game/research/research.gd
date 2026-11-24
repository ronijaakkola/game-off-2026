class_name Research
extends RefCounted
## Which [Upgrade]s the player has researched, whether research is open, which of the
## three stages are open, and the state each upgrade shows in its tree. Each tree splits
## into stages by row ([method get_stage]). Research opens every tree at once, on the first
## stage ([method open]), and each next stage opens in every tree at once, opening research
## with it ([method open_next_stage]). An upgrade is open once research and its stage both
## are. The mechanic's calls open both ([MechanicCall]).
## [method research] applies an upgrade's modifiers and traits to the bus's [BusStats];
## whoever calls it takes the cost off first.

## [param upgrade] was researched, and its effects are on the bus.
signal researched(upgrade: Upgrade)
## [param stage] opened, counting from 0.
signal stage_opened(stage: int)
## Research opened, every tree on the open stages.
signal opened

## How an upgrade shows in its tree.
enum State {
	## Marked hidden, and nothing it requires is researched: a silhouette.
	HIDDEN,
	## Nothing it requires is researched.
	LOCKED,
	## One of the upgrades it requires is researched, and the player can pay for it.
	AVAILABLE,
	## One of the upgrades it requires is researched, but the player can't pay for it.
	UNAFFORDABLE,
	## Researched: its effects are on the bus.
	RESEARCHED,
	## Research or its stage isn't open yet: the research screen leaves it out.
	SHUT,
}

## How many stages each tree splits into.
const STAGES := 3
## How many rows of a tree each stage holds; the last stage holds the rest.
const ROWS_PER_STAGE := 2

var _stats: BusStats
# One more on the bus's UPGRADES stat, added for every upgrade researched that does anything.
var _upgrade_count := StatModifier.new(BusStats.Type.UPGRADES, StatModifier.Kind.FLAT, 1.0)
var _researched: Dictionary[Upgrade, bool] = {}
var _open_stages := 1
var _opened := false


## The bus's [param stats].
func _init(stats: BusStats) -> void:
	_stats = stats


## The stage [param upgrade] is in, counting from 0, by its row in its tree.
static func get_stage(upgrade: Upgrade) -> int:
	return get_stage_of_row(upgrade.tier)


## The stage the row [param tier] of a tree is in, counting both from 0.
static func get_stage_of_row(tier: int) -> int:
	return mini(tier / ROWS_PER_STAGE, STAGES - 1)


## Whether any upgrade is researched.
func has_researched_any() -> bool:
	return not _researched.is_empty()


## Whether [param upgrade] is researched.
func is_researched(upgrade: Upgrade) -> bool:
	return _researched.has(upgrade)


## Whether [param upgrade] can be reached: it requires nothing, or one of the upgrades it
## requires is researched. Each is a path to it, and one is enough.
func is_unlocked(upgrade: Upgrade) -> bool:
	if upgrade.requires.is_empty():
		return true
	for required: Upgrade in upgrade.requires:
		if is_researched(required):
			return true
	return false


## Whether [param stage], counting from 0, is open.
func is_stage_open(stage: int) -> bool:
	return stage < _open_stages


## How many stages are open, counting the first.
func get_open_stages() -> int:
	return _open_stages


## Whether research is open: every tree, on the open stages.
func is_opened() -> bool:
	return _opened


## Whether research and [param upgrade]'s stage are both open.
func is_open(upgrade: Upgrade) -> bool:
	return _opened and is_stage_open(get_stage(upgrade))


## Opens research: every tree, on the open stages. Open already, it does nothing.
func open() -> void:
	if _opened:
		return
	_opened = true
	opened.emit()


## Opens the next stage in every tree, and research if it isn't open yet. With every stage
## open, it does nothing.
func open_next_stage() -> void:
	if _open_stages >= STAGES:
		return
	open()
	_open_stages += 1
	stage_opened.emit(_open_stages - 1)


## How [param upgrade] shows, with [param credits] and [param points], research points, to
## pay with.
func get_state(upgrade: Upgrade, credits: int, points: int) -> State:
	if is_researched(upgrade):
		return State.RESEARCHED
	if not is_open(upgrade):
		return State.SHUT
	if not is_unlocked(upgrade):
		return State.HIDDEN if upgrade.hidden else State.LOCKED
	if not upgrade.can_afford(credits, points):
		return State.UNAFFORDABLE
	return State.AVAILABLE


## Marks [param upgrade] researched and puts its modifiers and traits on the bus, and one
## more on its UPGRADES stat if it does anything yet. It doesn't check the cost, the stage
## or what it requires: [method get_state] does. Researched already, it does nothing.
func research(upgrade: Upgrade) -> void:
	if is_researched(upgrade):
		return
	_researched[upgrade] = true
	for modifier: StatModifier in upgrade.modifiers:
		_stats.add_modifier(modifier)
	for type: BusTraits.Type in upgrade.traits:
		_stats.get_traits().add(type)
	if upgrade.is_built():
		_stats.add_modifier(_upgrade_count)
	researched.emit(upgrade)
