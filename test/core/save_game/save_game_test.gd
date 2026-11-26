extends GdUnitTestSuite
## Deleting the save data forgets everything the save game keeps, and a test's files never
## touch another's or the player's.

const SAVE_GAME := preload("res://core/save_game/save_game.gd")


func before() -> void:
	SaveGame.use_test_files("save_game")


func after() -> void:
	SaveGame.use_test_files("save_game_other")
	SaveGame.use_player_files()
	SaveGame.use_test_files("save_game")
	SaveGame.use_player_files()


func before_test() -> void:
	SaveGame.use_test_files("save_game")
	SaveGame.delete()


func test_deleting_forgets_the_run_the_tutorial_and_the_hints() -> void:
	SaveGame.write({"credits": 1})
	SaveGame.mark_tutorial_done()
	SaveGame.mark_hint_seen(&"heat_zone")
	SaveGame.delete()
	assert_bool(SaveGame.has_save()).is_false()
	assert_bool(SaveGame.is_tutorial_done()).is_false()
	assert_bool(SaveGame.has_seen_hint(&"heat_zone")).is_false()


func test_every_file_the_save_game_names_is_one_delete_forgets() -> void:
	# A file kept but missing from FILES would outlive Delete save and a test's clean-up.
	var files: Array[String] = SAVE_GAME.FILES
	for value: Variant in (SAVE_GAME as Script).get_script_constant_map().values():
		if value is String and (value as String).begins_with("user://") and value != "user://":
			(
				assert_array(files)
				. override_failure_message(
					"%s is kept by SaveGame but not in SaveGame.FILES" % value
				)
				. contains([value])
			)


func test_a_test_reads_only_its_own_files() -> void:
	SaveGame.write({"credits": 1})
	SaveGame.mark_tutorial_done()
	SaveGame.use_test_files("save_game_other")
	assert_bool(SaveGame.has_save()).is_false()
	assert_bool(SaveGame.is_tutorial_done()).is_false()
	SaveGame.use_test_files("save_game")
	assert_bool(SaveGame.has_save()).is_true()


func test_a_run_and_a_record_saved_by_an_older_version_count_as_none() -> void:
	# Version 1 named Level 1's star system "Sol", which is now Level 3's: read as it
	# stands, a first-level save would open the last level.
	for path: String in [SaveGame.PATH, SaveGame.CAMPAIGN_PATH]:
		var file := FileAccess.open(
			path.replace("user://", "user://test_save_game_"), FileAccess.WRITE
		)
		file.store_string(JSON.stringify({"version": 1, "done": 1, "star_map": {"system": "Sol"}}))
		file.close()

	assert_bool(SaveGame.has_save()).is_false()
	assert_dict(SaveGame.read_campaign()).is_empty()
