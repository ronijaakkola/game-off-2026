extends GdUnitTestSuite

const MENU := "res://ui/main_menu/main_menu.tscn"
const GAME := "res://game/game.tscn"
const MUSIC := preload("res://shared/audio/menu_music.ogg")

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
	# A failed transition must not leave input off for the rest of the suite.
	get_tree().root.set_disable_input(false)
	get_tree().unload_current_scene()
	Audio.stop_music(0.0)


func test_play_goes_to_the_game_and_back() -> void:
	var runner := scene_runner(MENU)
	await _click(runner, runner.find_child("PlayButton"))
	await await_signal_on(get_tree(), "scene_changed", [], 2000)
	assert_str(get_tree().current_scene.scene_file_path).is_equal(GAME)
	await assert_func(get_tree().root, "is_input_disabled").wait_until(2000).is_false()

	# The game isn't in the runner, so press its pause menu's button directly. The button
	# belongs to the pause menu's own scene, so find_child must search unowned nodes.
	var game := get_tree().current_scene
	(game.find_child("MainMenuButton", true, false) as Button).pressed.emit()
	await await_signal_on(get_tree(), "scene_changed", [], 2000)
	assert_str(get_tree().current_scene.scene_file_path).is_equal(MENU)
	await assert_func(get_tree().root, "is_input_disabled").wait_until(2000).is_false()


func test_settings_button_opens_the_settings_panel() -> void:
	var runner := scene_runner(MENU)
	await _click(runner, runner.find_child("SettingsButton"))
	assert_bool((runner.find_child("SettingsMenu") as Control).visible).is_true()


func test_start_overlay_click_starts_the_music() -> void:
	# Outside the web build the menu starts the music itself, so stop it first.
	var runner := scene_runner(MENU)
	Audio.stop_music(0.0)
	await runner.simulate_frames(2)
	assert_bool(_music_playing()).is_false()

	var overlay := runner.find_child("StartOverlay") as Control
	overlay.show()
	await _click(runner, overlay)
	assert_bool(overlay.visible).is_false()
	assert_bool(_music_playing()).is_true()


func _click(runner: GdUnitSceneRunner, control: Control) -> void:
	# Containers place their children a frame after entering the tree.
	await runner.simulate_frames(1)
	runner.set_mouse_position(control.get_global_rect().get_center())
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()


func _music_playing() -> bool:
	for player: AudioStreamPlayer in Audio.find_children("*", "AudioStreamPlayer", false, false):
		if player.playing and player.stream == MUSIC:
			return true
	return false
