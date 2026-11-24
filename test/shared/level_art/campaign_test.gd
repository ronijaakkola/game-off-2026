extends GdUnitTestSuite
## How far the player has got through the levels, and where starting one begins the run.
## Saved runs are built through [SavedStarMap], as the game saves them.

const LEVEL_1 := preload("res://shared/level_art/level_1.tres")
const LEVEL_2 := preload("res://shared/level_art/level_2.tres")
const LEVEL_3 := preload("res://shared/level_art/level_3.tres")


func before() -> void:
	SaveGame.use_test_files("campaign")


func after() -> void:
	SaveGame.use_player_files()


func before_test() -> void:
	SaveGame.delete()
	SaveGame.claim_run()


func test_a_first_visit_has_only_level_1_open_and_nothing_in_progress() -> void:
	assert_object(Campaign.get_in_progress()).is_null()
	assert_bool(Campaign.is_open(LEVEL_1)).is_true()
	assert_bool(Campaign.is_open(LEVEL_2)).is_false()
	assert_bool(Campaign.is_done(LEVEL_1)).is_false()
	assert_bool(Campaign.has_progress()).is_false()


# A level finds its system by name, and counts as done by where that system is in the order
# they open, so a renamed or reordered system would put a save in the wrong level.
func test_the_levels_are_the_solar_systems_star_systems_in_the_order_they_open() -> void:
	var runner := scene_runner(Campaign.GAME_SCENE)
	await runner.simulate_frames(1)
	var systems := (runner.find_child("StarMap") as StarMap).get_systems()
	var names: Array[String] = []
	for system: StarSystem in systems:
		names.append(String(system.name))
	var levels: Array[String] = []
	for level: Level in Campaign.LEVELS:
		levels.append(level.star_system)
	assert_array(levels).is_equal(names)


func test_a_saved_run_counts_the_levels_its_star_map_did() -> void:
	SaveGame.write({SavedStarMap.KEY: SavedStarMap.make(3, true, "Draco")})
	assert_int(Campaign.count_done()).is_equal(Campaign.LEVELS.size())


func test_the_saved_run_is_in_its_star_systems_level() -> void:
	SaveGame.write({SavedStarMap.KEY: SavedStarMap.make(2, false, "Lyra")})
	assert_object(Campaign.get_in_progress()).is_same(LEVEL_2)
	assert_bool(Campaign.is_done(LEVEL_1)).is_true()
	assert_bool(Campaign.is_open(LEVEL_3)).is_false()


func test_levels_done_stay_done_when_an_earlier_level_starts_over() -> void:
	Campaign.record({SavedStarMap.KEY: SavedStarMap.make(2, false, "Lyra")}, "Lyra", 2, true)
	SaveGame.write({SavedStarMap.KEY: SavedStarMap.make(1, false, "Sol")})
	Campaign.record({SavedStarMap.KEY: SavedStarMap.make(1, false, "Sol")}, "Sol", 0, false)
	assert_int(Campaign.count_done()).is_equal(2)
	assert_bool(Campaign.is_open(LEVEL_3)).is_true()


func test_a_levels_start_is_kept_as_the_run_enters_it_and_only_then() -> void:
	Campaign.record({"credits": 50}, "Lyra", 1, true)
	Campaign.record({"credits": 80}, "Lyra", 1, false)
	var starts: Dictionary = SaveGame.read_campaign().get("starts", {})
	assert_int(int((starts["2"] as Dictionary)["credits"])).is_equal(50)
	# Coming into Lyra again, as after replaying Level 1, keeps the new start.
	Campaign.record({"credits": 20}, "Lyra", 1, true)
	starts = SaveGame.read_campaign().get("starts", {})
	assert_int(int((starts["2"] as Dictionary)["credits"])).is_equal(20)


func test_restarting_level_2_starts_the_run_as_level_2_began_and_saves_it() -> void:
	SaveGame.write({"credits": 999, SavedStarMap.KEY: SavedStarMap.make(2, false, "Lyra")})
	Campaign.record({"credits": 50}, "Lyra", 1, true)
	Campaign._start(LEVEL_2, false)
	assert_bool(SaveGame.has_started_run()).is_true()
	assert_int(int(SaveGame.claim_run()["credits"])).is_equal(50)
	# Quitting straight after never brings the replaced run back.
	assert_int(int(SaveGame.get_saved_run()["credits"])).is_equal(50)


func test_only_a_level_that_would_replace_the_run_in_progress_asks_first() -> void:
	assert_bool(Campaign.replaces_run(LEVEL_1)).override_failure_message("No run").is_false()
	SaveGame.write({SavedStarMap.KEY: SavedStarMap.make(1, false, "Sol")})
	assert_bool(Campaign.replaces_run(LEVEL_1)).override_failure_message("Continues").is_false()
	# Level 2 reached once, then Level 1 replayed: Level 2 starts from its kept start.
	Campaign.record({SavedStarMap.KEY: SavedStarMap.make(2, false, "Lyra")}, "Lyra", 1, true)
	assert_bool(Campaign.replaces_run(LEVEL_2)).is_true()
	SaveGame.write({SavedStarMap.KEY: SavedStarMap.make(2, false, "Lyra")})
	assert_bool(Campaign.replaces_run(LEVEL_1)).is_true()
	assert_bool(Campaign.replaces_run(LEVEL_2)).is_false()


func test_starting_level_1_begins_a_new_run_with_the_tutorial_as_asked() -> void:
	SaveGame.mark_tutorial_done()
	Campaign._start(LEVEL_1, true)
	assert_bool(SaveGame.wants_tutorial()).is_true()
	assert_bool(SaveGame.claim_run().is_empty()).is_true()

	Campaign._start(LEVEL_1, false)
	assert_bool(SaveGame.wants_tutorial()).is_false()


func test_resetting_forgets_the_run_and_the_record() -> void:
	SaveGame.write({SavedStarMap.KEY: SavedStarMap.make(2, false, "Lyra")})
	Campaign.record({}, "Lyra", 1, true)
	Campaign.reset()
	assert_bool(Campaign.has_progress()).is_false()
	assert_bool(Campaign.is_open(LEVEL_2)).is_false()
