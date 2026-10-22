extends GdUnitTestSuite

const SCENE := "res://ui/settings/settings_menu.tscn"

# The panel binds to the live Settings, which saves the developer's own settings file.
var _saved: Dictionary[String, Variant] = {}


func before() -> void:
	for key: String in Settings.get_names():
		_saved[key] = Settings.get(key)


func after() -> void:
	for key: String in Settings.get_names():
		Settings.set(key, _saved[key])


func test_open_shows_the_current_settings() -> void:
	Settings.music_volume = 1.0
	Settings.reduce_motion = false
	var runner := scene_runner(SCENE)
	# Changed after the panel's _ready, so only open() can show them.
	Settings.music_volume = 0.25
	Settings.reduce_motion = true
	runner.invoke("open", _covered(runner))
	assert_bool(runner.scene().visible).is_true()
	assert_float((runner.find_child("MusicSlider") as HSlider).value).is_equal_approx(0.25, 0.001)
	assert_bool((runner.find_child("ReduceMotionButton") as CheckButton).button_pressed).is_true()


func test_moving_a_slider_is_heard_at_once() -> void:
	Settings.sfx_volume = 0.8
	var runner := scene_runner(SCENE)
	runner.invoke("open", _covered(runner))
	var slider := runner.find_child("SfxSlider") as HSlider

	slider.drag_started.emit()
	slider.value = 0.3
	assert_float(Settings.sfx_volume).is_equal_approx(0.3, 0.001)
	assert_float(Audio.get_volume(Audio.Bus.SFX)).is_equal_approx(0.3, 0.001)


func test_reduce_motion_toggles_the_setting() -> void:
	Settings.reduce_motion = false
	var runner := scene_runner(SCENE)
	runner.invoke("open", _covered(runner))
	(runner.find_child("ReduceMotionButton") as CheckButton).button_pressed = true
	assert_bool(Settings.reduce_motion).is_true()


func test_back_hides_the_panel() -> void:
	var runner := scene_runner(SCENE)
	runner.invoke("open", _covered(runner))
	(runner.find_child("BackButton") as Button).pressed.emit()
	assert_bool(runner.scene().visible).is_false()


func test_focus_stays_in_the_panel_and_goes_back_to_its_opener() -> void:
	var runner := scene_runner(SCENE)
	var covered := _covered(runner)
	var opener := covered.get_child(0) as Button
	opener.grab_focus()
	runner.invoke("open", covered)
	# Tab from the panel's last control wraps inside the panel, not to the menu under it.
	var back := runner.find_child("BackButton") as Button
	assert_object(back.find_next_valid_focus()).is_same(runner.find_child("MasterSlider"))

	back.pressed.emit()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(opener)


# The pause menu's Resume hides the panel from outside. The menu under it must not stay
# unfocusable.
func test_hidden_by_its_menu_gives_focus_back_too() -> void:
	var runner := scene_runner(SCENE)
	var covered := _covered(runner)
	var opener := covered.get_child(0) as Button
	opener.grab_focus()
	runner.invoke("open", covered)
	runner.scene().hide()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(opener)


# A menu's controls with one focusable button, standing in for the menu that opens the panel.
func _covered(runner: GdUnitSceneRunner) -> Control:
	var covered := VBoxContainer.new()
	covered.add_child(Button.new())
	runner.scene().add_sibling(covered)
	return auto_free(covered)
