extends GdUnitTestSuite

const RINGTONE := preload("res://game/solar_system/ringtone.ogg")


func test_a_clip_with_an_entry_gets_its_level() -> void:
	assert_float(ClipLevels.of(RINGTONE)).is_equal(0.15)


func test_a_clip_with_no_entry_plays_as_recorded() -> void:
	var stream := AudioStreamWAV.new()
	assert_float(ClipLevels.of(stream)).is_equal(ClipLevels.DEFAULT)
	assert_float(ClipLevels.of(null)).is_equal(ClipLevels.DEFAULT)


# A renamed or deleted clip leaves its level behind, quietly applying to nothing.
func test_every_entry_names_a_clip_that_exists() -> void:
	for path: String in ClipLevels.LEVELS:
		assert_bool(ResourceLoader.exists("res://" + path)).override_failure_message(path).is_true()


func test_every_level_is_in_range() -> void:
	for path: String in ClipLevels.LEVELS:
		assert_float(ClipLevels.LEVELS[path]).override_failure_message(path).is_between(
			0.0, ClipLevels.MAX
		)
