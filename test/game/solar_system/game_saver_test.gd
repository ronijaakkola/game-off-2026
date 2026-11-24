extends GdUnitTestSuite
## Continuing a saved run puts its research back: the upgrades, whether the save keys them
## by their tree or, from before trees left their planets, by the planet their tree was
## at, and in the trees' first layout or the one now, and the research stages that were
## open. A New game after the tutorial starts at Terra.

const SCENE := "res://game/solar_system/solar_system.tscn"


func before() -> void:
	SaveGame.use_test_files("game_saver")


func after() -> void:
	SaveGame.use_player_files()


func test_continuing_puts_back_the_research_and_its_open_stages() -> void:
	# Speed 1 by its tree where the first layout had it, and Door chime by Terra, where the
	# green tree used to be.
	SaveGame.write({"research": ["blue_tree/0/0", "Terra/0/1"], "research_stages": 2})
	SaveGame.continue_saved()

	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)

	var lab := runner.find_child("ResearchLab") as ResearchLab
	var research := lab.get_research()
	assert_str(_upgrade_at(lab, "Performance", 0, 2).title).is_equal("Speed 1")
	assert_bool(research.is_researched(_upgrade_at(lab, "Performance", 0, 2))).is_true()
	assert_bool(research.is_researched(_upgrade_at(lab, "Planets", 0, 1))).is_true()
	assert_bool(research.is_researched(_upgrade_at(lab, "Comfort", 0, 0))).is_false()
	assert_int(research.get_open_stages()).is_equal(2)


func test_a_save_in_the_layout_now_keys_upgrades_where_they_sit() -> void:
	SaveGame.write({"research": ["orange_tree/0/0"], "research_layout": GameSaver.RESEARCH_LAYOUT})
	SaveGame.continue_saved()

	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)

	var lab := runner.find_child("ResearchLab") as ResearchLab
	assert_str(_upgrade_at(lab, "Comfort", 0, 0).title).is_equal("Pillows")
	assert_bool(lab.get_research().is_researched(_upgrade_at(lab, "Comfort", 0, 0))).is_true()


func test_a_new_game_after_the_tutorial_starts_docked_at_terra() -> void:
	SaveGame.mark_tutorial_done()
	SaveGame.start_new()

	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)

	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_bool((runner.find_child("MapZoom") as MapZoom).is_zoomed()).is_false()
	assert_object(bus.get_docked_planet()).is_same(runner.find_child("Terra"))


func _upgrade_at(lab: ResearchLab, tree_title: String, tier: int, column: int) -> Upgrade:
	for tree: ResearchTree in lab.trees:
		if tree.title != tree_title:
			continue
		for upgrade: Upgrade in tree.upgrades:
			if upgrade.tier == tier and upgrade.column == column:
				return upgrade
	return null
