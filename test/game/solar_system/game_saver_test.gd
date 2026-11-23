extends GdUnitTestSuite
## Continuing a saved run puts its research back: the upgrades, whether the save keys them
## by their tree or, from before trees left their planets, by the planet their tree was at,
## and the research stages that were open. A New game after the tutorial starts at Terra.
## The first save in another star system keeps the run as that level began, and starting
## the level from it starts there.

const SCENE := "res://game/solar_system/solar_system.tscn"


func before() -> void:
	SaveGame.use_test_files("game_saver")


func after() -> void:
	SaveGame.use_player_files()


func test_continuing_puts_back_the_research_and_its_open_stages() -> void:
	# Speed 1 by its tree, and Door chime by Terra, where the green tree used to be.
	SaveGame.write({"research": ["blue_tree/0/0", "Terra/0/1"], "research_stages": 2})
	SaveGame.continue_saved()

	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)

	var lab := runner.find_child("ResearchLab") as ResearchLab
	var research := lab.get_research()
	assert_bool(research.is_researched(_upgrade_at(lab, "Performance", 0, 0))).is_true()
	assert_bool(research.is_researched(_upgrade_at(lab, "Planets", 0, 1))).is_true()
	assert_bool(research.is_researched(_upgrade_at(lab, "Comfort", 0, 0))).is_false()
	assert_int(research.get_open_stages()).is_equal(2)


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


func test_the_first_save_in_a_new_system_keeps_the_run_as_its_level_began() -> void:
	SaveGame.delete()
	SaveGame.write({"star_map": {"opened": 2, "joined": false, "system": "Sol"}})
	SaveGame.continue_saved()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var saver := runner.find_child("GameSaver") as GameSaver
	var star_map := runner.find_child("StarMap") as StarMap
	saver._write()
	assert_dict(_kept_starts()).is_empty()

	star_map.enter(runner.find_child("Lyra") as StarSystem)
	saver._write()
	assert_dict(_kept_starts()).contains_keys(["2"])
	assert_int(int(SaveGame.read_campaign()["done"])).is_equal(1)
	var kept: Dictionary = _kept_starts()["2"]
	# Later saves in the same system leave the start as it was.
	SaveGame.write_campaign({"done": 1, "starts": {"2": {"marker": true}}})
	saver._write()
	assert_bool(bool((_kept_starts()["2"] as Dictionary).get("marker", false))).is_true()
	assert_str(str(kept["star_map"]["system"])).is_equal("Lyra")


# A save from before saves kept their system says nothing of where its run was.
func test_continuing_a_save_without_its_system_keeps_no_start() -> void:
	SaveGame.delete()
	SaveGame.write({"star_map": {"opened": 2, "joined": false}, "bus_planet": "Hither"})
	SaveGame.continue_saved()
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	(runner.find_child("GameSaver") as GameSaver)._write()
	assert_dict(_kept_starts()).is_empty()


func test_starting_level_2_from_its_kept_start_docks_in_lyra() -> void:
	SaveGame.delete()
	var start := {"star_map": {"opened": 2, "joined": false, "system": "Lyra"}}
	start["bus_planet"] = "Hither"
	SaveGame.write_campaign({"done": 1, "starts": {"2": start}})
	SaveGame.write({"star_map": {"opened": 1, "joined": false, "system": "Sol"}})
	Campaign._start(load("res://shared/level_art/level_2.tres"), false)
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_str(String(bus.get_docked_planet().name)).is_equal("Hither")
	var star_map := runner.find_child("StarMap") as StarMap
	assert_str(String(star_map.get_current().name)).is_equal("Lyra")


func _kept_starts() -> Dictionary:
	return SaveGame.read_campaign().get("starts", {})
