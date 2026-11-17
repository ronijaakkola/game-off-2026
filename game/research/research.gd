class_name Research
extends RefCounted
## Which [Upgrade]s the player has researched, from every research tree, which trees and
## which of the three stages are open, and the state each upgrade shows in its tree. Each
## tree splits into stages by row ([method get_stage]). An upgrade is open once its tree
## and its stage both are: the trees open one at a time, in order, on the first stage
## ([method open_next_tree]), and each next stage opens in every tree at once, opening
## every tree with it ([method open_next_stage]). The mechanic's calls open both
## ([MechanicCall]). An upgrade in no tree it was given counts as in an open tree.
## [method research] applies an upgrade's modifiers and traits to the bus's [BusStats];
## whoever calls it takes the cost off first.

## [param upgrade] was researched, and its effects are on the bus.
signal researched(upgrade: Upgrade)
## [param stage] opened, counting from 0.
signal stage_opened(stage: int)
## [param tree] opened.
signal tree_opened(tree: ResearchTree)

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
	## Its tree or its stage isn't open yet: the research screen leaves it out.
	SHUT,
}

## How many stages each tree splits into.
const STAGES := 3
## How many rows of a tree each stage holds; the last stage holds the rest.
const ROWS_PER_STAGE := 2

var _stats: BusStats
var _trees: Array[ResearchTree] = []
# Each upgrade's tree, by its place in [member _trees].
var _tree_of: Dictionary[Upgrade, int] = {}
var _researched: Dictionary[Upgrade, bool] = {}
var _open_stages := 1
var _open_trees := 0


## The bus's [param stats], and every tree, in the order they open.
func _init(stats: BusStats, trees: Array[ResearchTree] = []) -> void:
	_stats = stats
	_trees = trees.duplicate()
	for i: int in _trees.size():
		for upgrade: Upgrade in _trees[i].upgrades:
			_tree_of[upgrade] = i


## The stage [param upgrade] is in, counting from 0, by its row in its tree.
static func get_stage(upgrade: Upgrade) -> int:
	return get_stage_of_row(upgrade.tier)


## The stage the row [param tier] of a tree is in, counting both from 0.
static func get_stage_of_row(tier: int) -> int:
	return mini(tier / ROWS_PER_STAGE, STAGES - 1)


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


## Whether [param tree] is open.
func is_tree_open(tree: ResearchTree) -> bool:
	var index := _trees.find(tree)
	return index < 0 or index < _open_trees


## How many trees are open, from the first.
func get_open_trees() -> int:
	return _open_trees


## The tree that opens next, or null with every tree open.
func get_next_tree() -> ResearchTree:
	return _trees[_open_trees] if _open_trees < _trees.size() else null


## Whether [param upgrade]'s tree and its stage are both open.
func is_open(upgrade: Upgrade) -> bool:
	if _tree_of.get(upgrade, -1) >= _open_trees:
		return false
	return is_stage_open(get_stage(upgrade))


## Opens the next tree on the open stages. With every tree open, it does nothing.
func open_next_tree() -> void:
	if _open_trees >= _trees.size():
		return
	_open_trees += 1
	tree_opened.emit(_trees[_open_trees - 1])


## Opens the next stage in every tree, and every tree not open yet. With every stage open,
## it does nothing.
func open_next_stage() -> void:
	if _open_stages >= STAGES:
		return
	while _open_trees < _trees.size():
		open_next_tree()
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
