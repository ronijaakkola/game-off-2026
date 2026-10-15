extends GdUnitTestSuite

const SettingsScript := preload("res://core/settings/settings.gd")
const PATH := "user://settings.cfg"


func before_test() -> void:
	DirAccess.remove_absolute(PATH)


func after() -> void:
	# Fresh instances overwrote the buses and the developer's own settings file.
	# The live Settings still holds what it loaded at boot, so write that back.
	for key: String in ["master_volume", "music_volume", "sfx_volume", "reduce_motion"]:
		Settings.set(key, Settings.get(key))


func test_defaults_without_a_saved_file() -> void:
	var settings := _new_session()
	assert_float(settings.master_volume).is_equal_approx(0.8, 0.001)
	assert_float(settings.music_volume).is_equal_approx(0.6, 0.001)
	assert_float(settings.sfx_volume).is_equal_approx(0.8, 0.001)
	assert_bool(settings.reduce_motion).is_false()


func test_defaults_reach_the_buses() -> void:
	_new_session()
	assert_float(_bus_volume("Master")).is_equal_approx(0.8, 0.001)
	assert_float(_bus_volume("Music")).is_equal_approx(0.6, 0.001)
	assert_float(_bus_volume("SFX")).is_equal_approx(0.8, 0.001)


func test_changes_last_into_the_next_session() -> void:
	var settings := _new_session()
	settings.master_volume = 0.5
	settings.music_volume = 0.25
	settings.sfx_volume = 0.0
	settings.reduce_motion = true

	var next := _new_session()
	assert_float(next.master_volume).is_equal_approx(0.5, 0.001)
	assert_float(next.music_volume).is_equal_approx(0.25, 0.001)
	assert_float(next.sfx_volume).is_equal_approx(0.0, 0.001)
	assert_bool(next.reduce_motion).is_true()


func test_volume_change_reaches_its_bus() -> void:
	var settings := _new_session()
	settings.music_volume = 0.3
	assert_float(_bus_volume("Music")).is_equal_approx(0.3, 0.001)


func _bus_volume(bus: String) -> float:
	return AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus))


func _new_session() -> SettingsScript:
	var settings: SettingsScript = auto_free(SettingsScript.new())
	add_child(settings)
	return settings
