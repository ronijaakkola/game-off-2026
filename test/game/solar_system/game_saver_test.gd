extends GdUnitTestSuite
## Continuing a saved run puts its research back: the upgrades, whether the save keys them
## by their tree or, from before trees left their planets, by the planet their tree was at,
## and the research stages that were open.

const SCENE := "res://game/solar_system/solar_system.tscn"
# The suite saves to a file of its own, never the player's.
const TEST_SAVE := "user://test_game_saver_save.json"


func before() -> void:
	SaveGame.path = TEST_SAVE


func after() -> void:
	SaveGame.delete()
	SaveGame.path = SaveGame.PATH


func test_continuing_puts_back_the_research_and_its_open_stages() -> void:
	# Speed 1 by its tree, and Door chime by Terra, where the green tree used to be.
	SaveGame.write({"research": ["blue_tree/0/0", "Terra/0/1"], "research_stages": 2})
	SaveGame.continue_saved()

	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)

	var lab := runner.find_child("ResearchLab") as ResearchLab
	var research := lab.get_research()
	assert_bool(research.is_researched(_upgrade_at(lab, "Performance", 0, 0))).is_true()
	assert_bool(research.is_researched(_upgrade_at(lab, "Stops", 0, 1))).is_true()
	assert_bool(research.is_researched(_upgrade_at(lab, "Comfort", 0, 0))).is_false()
	assert_int(research.get_open_stages()).is_equal(2)


func _upgrade_at(lab: ResearchLab, tree_title: String, tier: int, column: int) -> Upgrade:
	for tree: ResearchTree in lab.trees:
		if tree.title != tree_title:
			continue
		for upgrade: Upgrade in tree.upgrades:
			if upgrade.tier == tier and upgrade.column == column:
				return upgrade
	return null
