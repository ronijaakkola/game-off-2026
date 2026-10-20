extends GdUnitTestSuite

const SettingsScript := preload("res://core/settings/settings.gd")
const PATH := "user://settings.cfg"


func before_test() -> void:
	DirAccess.remove_absolute(PATH)


func after_test() -> void:
	get_tree().paused = false


func after() -> void:
	# Fresh instances overwrote the buses and the developer's own settings file.
	# The live Settings still holds what it loaded at boot, so write that back.
	for key: String in Settings.get_names():
		Settings.set(key, Settings.get(key))


func test_defaults_without_a_saved_file() -> void:
	var settings := _new_session()
	assert_float(settings.master_volume).is_equal_approx(0.8, 0.001)
	assert_float(settings.music_volume).is_equal_approx(0.6, 0.001)
	assert_float(settings.sfx_volume).is_equal_approx(0.8, 0.001)
	assert_bool(settings.reduce_motion).is_false()


func test_defaults_reach_the_buses() -> void:
	_new_session()
	assert_float(Audio.get_volume(Audio.Bus.MASTER)).is_equal_approx(0.8, 0.001)
	assert_float(Audio.get_volume(Audio.Bus.MUSIC)).is_equal_approx(0.6, 0.001)
	assert_float(Audio.get_volume(Audio.Bus.SFX)).is_equal_approx(0.8, 0.001)


func test_every_public_var_is_a_setting() -> void:
	var names := _new_session().get_names()
	assert_array(names).contains(["master_volume", "music_volume", "sfx_volume", "reduce_motion"])
	assert_array(names).not_contains(["_loaded", "_save_timer"])


# One setting at a time, so a setter that forgets to queue the save fails here even
# when the others save.
func test_each_setting_lasts_into_the_next_session() -> void:
	for setting: String in _new_session().get_names():
		var settings := _new_session()
		var changed: Variant = _other_value(settings.get(setting))
		settings.set(setting, changed)
		await _wait_for_save()
		var message := "%s didn't last into the next session" % setting
		assert_that(_new_session().get(setting)).override_failure_message(message).is_equal(changed)


func test_volume_change_reaches_its_bus() -> void:
	var settings := _new_session()
	settings.music_volume = 0.3
	assert_float(Audio.get_volume(Audio.Bus.MUSIC)).is_equal_approx(0.3, 0.001)


func test_a_burst_of_changes_saves_once_it_stops() -> void:
	var settings := _new_session()
	settings.master_volume = 0.5
	await get_tree().create_timer(SettingsScript.SAVE_DELAY / 2).timeout
	settings.master_volume = 0.4
	await get_tree().create_timer(SettingsScript.SAVE_DELAY / 2).timeout
	assert_bool(FileAccess.file_exists(PATH)).is_false()

	await _wait_for_save()
	assert_float(_new_session().master_volume).is_equal_approx(0.4, 0.001)


func test_a_waiting_change_is_saved_on_quit() -> void:
	var settings := _new_session()
	settings.music_volume = 0.25
	remove_child(settings)
	assert_float(_new_session().music_volume).is_equal_approx(0.25, 0.001)


func test_a_change_while_paused_is_saved() -> void:
	var settings := _new_session()
	get_tree().paused = true
	settings.sfx_volume = 0.1
	await _wait_for_save()
	assert_float(_new_session().sfx_volume).is_equal_approx(0.1, 0.001)


# A value unlike the default, so a setting that isn't saved comes back different.
func _other_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_BOOL:
			return not value
		TYPE_FLOAT:
			return 0.25 if value != 0.25 else 0.5
	fail("No other value for a setting of type %s. Add one here." % type_string(typeof(value)))
	return value


func _wait_for_save() -> void:
	await get_tree().create_timer(SettingsScript.SAVE_DELAY + 0.1).timeout


func _new_session() -> SettingsScript:
	var settings: SettingsScript = auto_free(SettingsScript.new())
	add_child(settings)
	return settings
