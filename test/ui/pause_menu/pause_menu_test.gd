extends GdUnitTestSuite

const SCENE := "res://ui/pause_menu/pause_menu.tscn"
const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"

var _window_size: Vector2i
var _runner_scene: Node


func before() -> void:
	# In the editor, gdUnit's runner is the current scene, and changing scenes would free
	# it mid-run. Headless, there is no current scene.
	_runner_scene = get_tree().current_scene
	get_tree().current_scene = null
	# Headless, the window is 64×64, and the canvas_items stretch would scale every
	# simulated click by 18. At the base size it scales by 1.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)


func after() -> void:
	get_tree().root.size = _window_size
	get_tree().current_scene = _runner_scene


func after_test() -> void:
	# A failed test must not leave the rest of the suite paused, or input off.
	get_tree().paused = false
	get_tree().root.set_disable_input(false)
	get_tree().unload_current_scene()
	Audio.stop_music(0.0)


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


func test_main_menu_leaves_the_paused_game() -> void:
	var runner := scene_runner(SCENE)
	runner.invoke("open")
	var button := runner.find_child("MainMenuButton") as Button
	await runner.simulate_frames(1)
	runner.set_mouse_position(button.get_global_rect().get_center())
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	# SceneFlow turns input off as soon as it starts. Check that before any timed wait:
	# gdUnit's timeouts stall while the tree stays paused, so a dead button would hang.
	assert_bool(get_tree().root.is_input_disabled()).is_true()
	if is_failure():
		return

	await await_signal_on(get_tree(), "scene_changed", [], 2000)
	assert_str(get_tree().current_scene.scene_file_path).is_equal(MAIN_MENU)
	assert_bool(get_tree().paused).is_false()
	await assert_func(get_tree().root, "is_input_disabled").wait_until(2000).is_false()


func _press_pause() -> void:
	# The runner's simulate_key_pressed also calls the root's _unhandled_input
	# directly, so the menu would toggle twice. Send Esc through Input alone.
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()
