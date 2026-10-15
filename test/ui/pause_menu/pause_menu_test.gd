extends GdUnitTestSuite

const SCENE := "res://ui/pause_menu/pause_menu.tscn"


func after_test() -> void:
	# A failed test must not leave the rest of the suite paused.
	get_tree().paused = false


func test_esc_opens_and_closes_the_menu() -> void:
	var runner := scene_runner(SCENE)
	runner.scene().hide()

	_press_pause()
	assert_bool(runner.scene().visible).is_true()
	assert_bool(get_tree().paused).is_true()

	_press_pause()
	assert_bool(runner.scene().visible).is_false()
	assert_bool(get_tree().paused).is_false()


func test_resume_closes_the_settings_panel_too() -> void:
	var runner := scene_runner(SCENE)
	runner.invoke("open")
	(runner.find_child("SettingsButton") as Button).pressed.emit()
	var settings := runner.find_child("SettingsMenu") as Control
	assert_bool(settings.visible).is_true()

	(runner.find_child("ResumeButton") as Button).pressed.emit()
	assert_bool(settings.visible).is_false()
	assert_bool(runner.scene().visible).is_false()
	assert_bool(get_tree().paused).is_false()


func _press_pause() -> void:
	# The runner's simulate_key_pressed also calls the root's _unhandled_input
	# directly, so the menu would toggle twice. Send Esc through Input alone.
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()
