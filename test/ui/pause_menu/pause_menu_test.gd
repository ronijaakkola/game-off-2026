extends GdUnitTestSuite

const SCENE := "res://ui/pause_menu/pause_menu.tscn"
const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"
const PauseMenuScript := preload("res://ui/pause_menu/pause_menu.gd")
const PauseProofWait := preload("res://test/support/pause_proof_wait.gd")
# Headless, the window is 64×64, and the canvas_items stretch would scale every
# simulated click by 18. At the base size it scales by 1.
const BASE_SIZE := Vector2i(1152, 648)

var _window_size: Vector2i
var _runner_scene: Node


func before() -> void:
	# Restart level reads the saved run, so the player's own save stays out of it.
	SaveGame.use_test_files("pause_menu")
	# In the editor, gdUnit's runner is the current scene, and changing scenes would free
	# it mid-run. Headless, there is no current scene.
	_runner_scene = get_tree().current_scene
	get_tree().current_scene = null
	_window_size = get_tree().root.size
	get_tree().root.size = BASE_SIZE


func after() -> void:
	SaveGame.use_player_files()
	get_tree().root.size = _window_size
	get_tree().current_scene = _runner_scene


func after_test() -> void:
	# Back to the base size first: from a larger window that's a shrink, which pauses
	# through a menu still in the tree.
	get_tree().root.size = BASE_SIZE
	# A failed test must not leave the rest of the suite paused, or input off. Unpause
	# before waiting for SceneFlow: gdUnit's timeouts stall while the tree is paused.
	get_tree().paused = false
	await assert_func(get_tree().root, "is_input_disabled").wait_until(5000).is_false()
	get_tree().root.set_disable_input(false)
	get_tree().unload_current_scene()
	Audio.stop_music(0.0)


func test_esc_opens_and_closes_the_menu() -> void:
	var runner := scene_runner(SCENE)
	assert_bool(runner.scene().visible).is_false()
	assert_bool(get_tree().paused).is_false()

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


func test_skip_tutorial_shows_last_only_when_offered_and_skips_from_a_closed_menu() -> void:
	var runner := scene_runner(SCENE)
	runner.invoke("open")
	var skip := runner.find_child("SkipTutorialButton") as Button
	assert_bool(skip.is_visible_in_tree()).is_false()

	runner.set_property("offers_skip_tutorial", true)
	assert_bool(skip.is_visible_in_tree()).is_true()
	# It sits under the others, a step further apart.
	await runner.simulate_frames(1)
	var main_menu := runner.find_child("MainMenuButton") as Button
	assert_float(skip.get_global_rect().position.y).is_greater(
		main_menu.get_global_rect().end.y + 16
	)
	monitor_signals(runner.scene())
	skip.pressed.emit()
	assert_bool(runner.scene().visible).is_false()
	assert_bool(get_tree().paused).is_false()
	await assert_signal(runner.scene()).is_emitted("skip_tutorial_pressed")


func test_esc_in_settings_goes_back_to_the_paused_menu() -> void:
	var runner := scene_runner(SCENE)
	runner.invoke("open")
	(runner.find_child("SettingsButton") as Button).pressed.emit()

	_press_pause()
	assert_bool((runner.find_child("SettingsMenu") as Control).visible).is_false()
	assert_bool(runner.scene().visible).is_true()
	assert_bool(get_tree().paused).is_true()


func test_keyboard_focus_follows_the_open_panel() -> void:
	var runner := scene_runner(SCENE)
	_press_pause()
	assert_object(_focused()).is_same(runner.find_child("ResumeButton"))

	# A player presses Settings with focus on it, by keyboard or by a click.
	var settings_button := runner.find_child("SettingsButton") as Button
	settings_button.grab_focus()
	settings_button.pressed.emit()
	assert_object(_focused()).is_same(runner.find_child("MasterVolume"))
	# Tab from the screen's last control wraps inside the screen, not to the buttons under it.
	var back := runner.find_child("SettingsMenu").find_child("BackButton") as Button
	assert_object(back.find_next_valid_focus()).is_same(runner.find_child("MasterVolume"))

	back.pressed.emit()
	assert_object(_focused()).is_same(settings_button)


# Leaving browser fullscreen shows only as the window shrinking. The menu opens on that only
# on the web, so each test sets it.
func test_leaving_fullscreen_opens_the_menu() -> void:
	var runner := scene_runner(SCENE)
	runner.set_property("opens_when_window_shrinks", true)
	get_tree().root.size = BASE_SIZE - Vector2i(0, 40)
	assert_bool(runner.scene().visible).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_object(_focused()).is_same(runner.find_child("ResumeButton"))


func test_a_window_growing_or_changing_shape_keeps_playing() -> void:
	var runner := scene_runner(SCENE)
	runner.set_property("opens_when_window_shrinks", true)
	get_tree().root.size = BASE_SIZE + Vector2i(200, 100)
	get_tree().root.size = Vector2i(BASE_SIZE.x + 300, BASE_SIZE.y)
	assert_bool(runner.scene().visible).is_false()
	assert_bool(get_tree().paused).is_false()


func test_the_window_shrinking_off_the_web_keeps_playing() -> void:
	var runner := scene_runner(SCENE)
	runner.set_property("opens_when_window_shrinks", false)
	get_tree().root.size = BASE_SIZE - Vector2i(200, 100)
	assert_bool(runner.scene().visible).is_false()
	assert_bool(get_tree().paused).is_false()


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func test_main_menu_leaves_the_paused_game() -> void:
	var runner := scene_runner(SCENE)
	runner.invoke("open")
	var button := runner.find_child("MainMenuButton") as Button
	await runner.simulate_frames(1)
	runner.set_mouse_position(button.get_global_rect().get_center())
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	var changed := await PauseProofWait.for_signal(get_tree().scene_changed, 2000)
	assert_bool(changed).override_failure_message("SceneFlow never left the paused game").is_true()
	if is_failure():
		return
	assert_str(get_tree().current_scene.scene_file_path).is_equal(MAIN_MENU)
	assert_bool(get_tree().paused).is_false()
	if is_failure():
		return
	await assert_func(get_tree().root, "is_input_disabled").wait_until(2000).is_false()


# A game scene can be freed with its menu open: a restart, or a test's scene runner at the
# end of a test that opened it. The next scene must not start paused.
func test_freeing_the_open_menu_resumes_the_game() -> void:
	var menu: PauseMenuScript = load(SCENE).instantiate()
	add_child(menu)
	menu.open()
	menu.free()
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


func test_controls_opens_its_screen_and_esc_goes_back() -> void:
	var runner := scene_runner(SCENE)
	runner.invoke("open")
	(runner.find_child("ControlsButton") as Button).pressed.emit()
	var controls := runner.find_child("ControlsScreen") as Control
	assert_bool(controls.visible).is_true()
	assert_bool((runner.find_child("Content") as Control).visible).is_false()

	_press_pause()
	assert_bool(controls.visible).is_false()
	assert_bool(runner.scene().visible).is_true()
	assert_bool(get_tree().paused).is_true()


func test_restart_level_asks_first_and_cancel_keeps_playing_paused() -> void:
	var runner := scene_runner(SCENE)
	runner.invoke("open")
	(runner.find_child("RestartButton") as Button).pressed.emit()
	var dialog := runner.find_child("RestartDialog") as Control
	assert_bool(dialog.visible).is_true()
	assert_str((dialog.find_child("Title") as Label).text).is_equal("Restart Level 1?")

	(dialog.find_child("CancelButton") as Button).pressed.emit()
	assert_bool(dialog.visible).is_false()
	assert_bool(runner.scene().visible).is_true()
	assert_bool(get_tree().paused).is_true()
