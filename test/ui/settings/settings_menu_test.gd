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
	assert_float((runner.find_child("MusicVolume") as HSlider).value).is_equal_approx(0.25, 0.001)
	assert_bool((runner.find_child("ReduceMotion") as CheckButton).button_pressed).is_true()


func test_moving_a_slider_is_heard_at_once() -> void:
	Settings.sfx_volume = 0.8
	var runner := scene_runner(SCENE)
	runner.invoke("open", _covered(runner))
	var slider := runner.find_child("SfxVolume") as HSlider

	slider.drag_started.emit()
	slider.value = 0.3
	assert_float(Settings.sfx_volume).is_equal_approx(0.3, 0.001)
	assert_float(Audio.get_volume(Audio.Bus.SFX)).is_equal_approx(0.3, 0.001)


# Every setting, so a control wired to the wrong setting, or a setting with no control,
# fails here.
func test_each_control_changes_only_its_own_setting() -> void:
	var runner := scene_runner(SCENE)
	runner.invoke("open", _covered(runner))
	for setting: String in Settings.get_names():
		var before := _current_settings()
		var control := runner.find_child(setting.to_pascal_case()) as Control
		assert_object(control).override_failure_message("No control for %s" % setting).is_not_null()
		if is_failure():
			return
		if control is Range:
			var slider := control as Range
			slider.value = 0.25 if slider.value != 0.25 else 0.5
		else:
			var button := control as BaseButton
			button.button_pressed = not button.button_pressed
		var after := _current_settings()
		var changed: Array[String] = []
		for key: String in after:
			if after[key] != before[key]:
				changed.append(key)
		var message := "Changing %s changed %s" % [control.name, changed]
		assert_array(changed).override_failure_message(message).contains_exactly([setting])


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
	assert_object(back.find_next_valid_focus()).is_same(runner.find_child("MasterVolume"))

	back.pressed.emit()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(opener)


func test_opening_it_again_still_gives_focus_back_to_the_opener() -> void:
	var runner := scene_runner(SCENE)
	var covered := _covered(runner)
	var opener := covered.get_child(0) as Button
	opener.grab_focus()
	runner.invoke("open", covered)
	runner.invoke("open", covered)
	(runner.find_child("BackButton") as Button).pressed.emit()
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


func _current_settings() -> Dictionary[String, Variant]:
	var values: Dictionary[String, Variant] = {}
	for key: String in Settings.get_names():
		values[key] = Settings.get(key)
	return values


# A menu's controls with one focusable button, standing in for the menu that opens the panel.
func _covered(runner: GdUnitSceneRunner) -> Control:
	var covered := VBoxContainer.new()
	covered.add_child(Button.new())
	runner.scene().add_sibling(covered)
	return auto_free(covered)
