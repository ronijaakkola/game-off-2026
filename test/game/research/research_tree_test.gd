extends GdUnitTestSuite
## The research trees the game ships with hold together: each upgrade requires only
## upgrades from its own tree, sits below them, has a slot of its own and costs something,
## and the tree starts with at least one upgrade that requires nothing.

const TREES: Array[ResearchTree] = [
	preload("res://game/research/trees/blue_tree.tres"),
	preload("res://game/research/trees/green_tree.tres"),
	preload("res://game/research/trees/orange_tree.tres"),
]


func test_every_tree_holds_together() -> void:
	var problems: Array[String] = []
	for tree: ResearchTree in TREES:
		problems.append_array(_problems(tree))
	assert_array(problems).is_empty()


func _problems(tree: ResearchTree) -> Array[String]:
	var name := tree.resource_path.get_file()
	var problems: Array[String] = []
	var slots: Dictionary[Vector2i, Upgrade] = {}
	var roots := 0
	for upgrade: Upgrade in tree.upgrades:
		var label := "%s: %s" % [name, upgrade.title]
		var slot := Vector2i(upgrade.tier, upgrade.column)
		if slots.has(slot):
			problems.append("%s shares a slot with %s" % [label, slots[slot].title])
		slots[slot] = upgrade
		var cost := upgrade.credits
		for amount: int in upgrade.points.values():
			cost += amount
		if cost <= 0:
			problems.append("%s costs nothing" % label)
		if upgrade.requires.is_empty():
			roots += 1
		for required: Upgrade in upgrade.requires:
			if required not in tree.upgrades:
				problems.append("%s requires %s from another tree" % [label, required.title])
			elif required.tier >= upgrade.tier:
				problems.append("%s doesn't sit below %s" % [label, required.title])
	if roots == 0:
		problems.append("%s has no upgrade to start" % name)
	return problems
