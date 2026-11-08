extends GdUnitTestSuite
## The debug panel, a fresh instance rather than the live autoload: F2 opens and closes
## it, and a scene's buttons run its actions and go when the scene does.

const SCENE := "res://core/debug_panel/debug_panel.tscn"


func test_f2_opens_and_closes_it() -> void:
	var runner := scene_runner(SCENE)
	var panel := runner.scene()
	assert_bool(panel.call(&"is_open")).is_false()

	_press_f2()
	await runner.simulate_frames(1)
	assert_bool(panel.call(&"is_open")).is_true()
	# The fresh panel takes the key, so the live one stays shut for later suites.
	assert_bool(DebugPanel.is_open()).is_false()

	_press_f2()
	await runner.simulate_frames(1)
	assert_bool(panel.call(&"is_open")).is_false()


func test_a_scenes_button_runs_its_action_and_goes_with_the_scene() -> void:
	var runner := scene_runner(SCENE)
	var panel := runner.scene()
	var empty := runner.find_child("EmptyLabel") as Control
	var buttons := runner.find_child("Buttons") as Container
	assert_bool(empty.visible).is_true()
	var scene := Node.new()
	add_child(scene)
	var presses: Array[int] = [0]

	panel.call(&"add_button", "Do it", func() -> void: presses[0] += 1, scene)

	assert_int(buttons.get_child_count()).is_equal(1)
	assert_bool(empty.visible).is_false()
	var button := buttons.get_child(0) as Button
	assert_str(button.text).is_equal("Do it")
	button.pressed.emit()
	assert_int(presses[0]).is_equal(1)

	scene.free()
	await runner.simulate_frames(2)
	assert_int(buttons.get_child_count()).is_equal(0)
	assert_bool(empty.visible).is_true()


# Through Input alone: the runner's own key calls deliver each event twice.
func _press_f2() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F2
	event.pressed = true
	Input.parse_input_event(event)
	# Let go too, so no later suite starts with F2 held.
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
