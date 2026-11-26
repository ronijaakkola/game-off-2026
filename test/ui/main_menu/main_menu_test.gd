extends GdUnitTestSuite

const MENU := "res://ui/main_menu/main_menu.tscn"
const GAME := "res://game/solar_system/solar_system.tscn"
const MUSIC := preload("res://ui/audio/bgm1.ogg")
const PauseProofWait := preload("res://test/support/pause_proof_wait.gd")

var _window_size: Vector2i
var _runner_scene: Node


func before() -> void:
	SaveGame.use_test_files("main_menu")
	# In the editor, gdUnit's runner is the current scene, and changing scenes would free
	# it mid-run. Headless, there is no current scene.
	_runner_scene = get_tree().current_scene
	get_tree().current_scene = null
	# Headless, the window is 64×64, and the canvas_items stretch would scale every
	# simulated click by 18. At the base size it scales by 1.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)


func after() -> void:
	SaveGame.use_player_files()
	get_tree().root.size = _window_size
	get_tree().current_scene = _runner_scene


func before_test() -> void:
	# Play saves the new run at once, and a save turns Play into Continue.
	SaveGame.delete()


func after_test() -> void:
	# Let SceneFlow finish first: its scene change would land after the unload, and it
	# ignores go_to calls until it ends, so the next suite would fail instead of this one.
	await assert_func(get_tree().root, "is_input_disabled").wait_until(5000).is_false()
	get_tree().root.set_disable_input(false)
	get_tree().unload_current_scene()
	Audio.stop_music(0.0)


func test_play_opens_the_campaign_whose_play_goes_to_the_game_and_back() -> void:
	SaveGame.mark_tutorial_done()
	var runner := scene_runner(MENU)
	await _click(runner, runner.find_child("PlayButton"))
	var campaign := runner.find_child("CampaignScreen") as Control
	assert_bool(campaign.visible).is_true()
	# The menu's rows stagger out first.
	await assert_func(runner.find_child("Home"), "is_visible").wait_until(2000).is_false()
	await _click(runner, campaign.find_child("PlayButton") as Control)
	await await_signal_on(get_tree(), "scene_changed", [], 2000)
	assert_str(get_tree().current_scene.scene_file_path).is_equal(GAME)
	# The level waits, paused, for Start on its loading screen.
	var start := SceneFlow.find_child("StartButton", true, false) as Button
	assert_bool(await PauseProofWait.for_condition(start.is_visible_in_tree, 5000)).is_true()
	start.pressed.emit()
	await assert_func(get_tree().root, "is_input_disabled").wait_until(2000).is_false()

	# The game isn't in the runner, so press its pause menu's button directly. The button
	# belongs to the pause menu's own scene, so find_child must search unowned nodes.
	var game := get_tree().current_scene
	(game.find_child("MainMenuButton", true, false) as Button).pressed.emit()
	await await_signal_on(get_tree(), "scene_changed", [], 2000)
	assert_str(get_tree().current_scene.scene_file_path).is_equal(MENU)
	await assert_func(get_tree().root, "is_input_disabled").wait_until(2000).is_false()


func test_level_1_offers_the_tutorial_box_only_once_the_tutorial_is_done() -> void:
	var runner := scene_runner(MENU)
	await _click(runner, runner.find_child("PlayButton"))
	var chip := runner.find_child("TutorialChip") as Control
	assert_bool(chip.visible).override_failure_message("Offered on a first run").is_false()

	SaveGame.mark_tutorial_done()
	var campaign := runner.find_child("CampaignScreen") as MenuScreen
	await _click(runner, campaign.find_child("BackButton") as Control)
	await assert_func(campaign, "is_visible").wait_until(2000).is_false()
	await _click(runner, runner.find_child("PlayButton"))
	assert_bool(chip.visible).is_true()
	assert_bool((chip.find_child("PlayTutorial") as CheckBox).button_pressed).is_false()


func test_settings_button_opens_the_settings_panel() -> void:
	var runner := scene_runner(MENU)
	await _click(runner, runner.find_child("SettingsButton"))
	assert_bool((runner.find_child("SettingsMenu") as Control).visible).is_true()


func test_keyboard_focus_follows_the_open_panel() -> void:
	var runner := scene_runner(MENU)
	await runner.simulate_frames(1)
	assert_object(_focused()).is_same(runner.find_child("PlayButton"))

	# A player presses Settings with focus on it, by keyboard or by a click.
	var settings_button := runner.find_child("SettingsButton") as Button
	settings_button.grab_focus()
	settings_button.pressed.emit()
	assert_object(_focused()).is_same(runner.find_child("MasterVolume"))
	# Tab from the screen's last control wraps inside the screen, not to the buttons under it.
	var back := runner.find_child("SettingsMenu").find_child("BackButton") as Button
	assert_object(back.find_next_valid_focus()).is_same(runner.find_child("MasterVolume"))

	back.pressed.emit()
	# The screen's rows stagger out first.
	var settings := runner.find_child("SettingsMenu")
	await assert_func(settings, "is_visible").wait_until(2000).is_false()
	assert_object(_focused()).is_same(settings_button)


func test_focus_ring_shows_only_when_opened_by_a_key() -> void:
	var runner := scene_runner(MENU)
	await runner.simulate_frames(1)
	var settings_button := runner.find_child("SettingsButton") as Button
	await _click(runner, settings_button)
	var volume := runner.find_child("MasterVolume") as Control
	assert_object(_focused()).is_same(volume)
	assert_bool(volume.has_focus(true)).is_false()

	var settings := runner.find_child("SettingsMenu")
	(settings.find_child("BackButton") as Button).pressed.emit()
	await assert_func(settings, "is_visible").wait_until(2000).is_false()
	assert_object(_focused()).is_same(settings_button)
	assert_bool(settings_button.has_focus(true)).is_false()

	runner.simulate_key_pressed(KEY_ENTER)
	await runner.await_input_processed()
	assert_object(_focused()).is_same(volume)
	assert_bool(volume.has_focus(true)).is_true()


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
	assert_object(_focused()).is_same(runner.find_child("PlayButton"))


func _click(runner: GdUnitSceneRunner, control: Control) -> void:
	# Containers place their children a frame after entering the tree.
	await runner.simulate_frames(1)
	runner.set_mouse_position(control.get_global_rect().get_center())
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _music_playing() -> bool:
	for player: AudioStreamPlayer in Audio.find_children("*", "AudioStreamPlayer", false, false):
		if player.playing and player.stream == MUSIC:
			return true
	return false


func test_a_level_in_progress_shows_continue_naming_it_and_levels() -> void:
	SaveGame.write({SavedStarMap.KEY: SavedStarMap.make(2, false, "Lyra")})
	var runner := scene_runner(MENU)
	await runner.simulate_frames(1)
	assert_bool((runner.find_child("PlayButton") as Control).visible).is_false()
	assert_bool((runner.find_child("LevelsButton") as Control).visible).is_true()
	assert_str((runner.find_child("Where") as Label).text).is_equal("Rough ride")
	assert_object(_focused()).is_same(runner.find_child("ContinueButton"))
