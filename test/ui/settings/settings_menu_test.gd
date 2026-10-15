extends GdUnitTestSuite

const SCENE := "res://ui/settings/settings_menu.tscn"
const KEYS: Array[String] = ["master_volume", "music_volume", "sfx_volume", "reduce_motion"]

# The panel binds to the live Settings, which saves the developer's own settings file.
var _saved: Dictionary[String, Variant] = {}


func before() -> void:
	for key: String in KEYS:
		_saved[key] = Settings.get(key)


func after() -> void:
	for key: String in KEYS:
		Settings.set(key, _saved[key])


func test_open_shows_the_current_settings() -> void:
	Settings.music_volume = 0.25
	Settings.reduce_motion = true
	var runner := scene_runner(SCENE)
	runner.invoke("open")
	assert_bool(runner.scene().visible).is_true()
	assert_float((runner.find_child("MusicSlider") as HSlider).value).is_equal_approx(0.25, 0.001)
	assert_bool((runner.find_child("ReduceMotionButton") as CheckButton).button_pressed).is_true()


func test_moving_a_slider_is_heard_at_once() -> void:
	Settings.sfx_volume = 0.8
	var runner := scene_runner(SCENE)
	runner.invoke("open")
	var slider := runner.find_child("SfxSlider") as HSlider

	slider.drag_started.emit()
	slider.value = 0.3
	assert_float(Settings.sfx_volume).is_equal_approx(0.3, 0.001)
	assert_float(_bus_volume("SFX")).is_equal_approx(0.3, 0.001)


func test_reduce_motion_toggles_the_setting() -> void:
	Settings.reduce_motion = false
	var runner := scene_runner(SCENE)
	runner.invoke("open")
	(runner.find_child("ReduceMotionButton") as CheckButton).button_pressed = true
	assert_bool(Settings.reduce_motion).is_true()


func test_back_hides_the_panel() -> void:
	var runner := scene_runner(SCENE)
	runner.invoke("open")
	(runner.find_child("BackButton") as Button).pressed.emit()
	assert_bool(runner.scene().visible).is_false()


func _bus_volume(bus: String) -> float:
	return AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus))
