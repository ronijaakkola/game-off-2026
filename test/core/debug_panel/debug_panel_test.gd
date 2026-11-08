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


func test_a_groups_buttons_go_on_their_own_card_that_its_toggle_opens() -> void:
	var runner := scene_runner(SCENE)
	var panel := runner.scene()
	var buttons := runner.find_child("Buttons") as Container
	var cards := runner.find_child("Cards") as Container
	var scene := Node.new()
	add_child(scene)

	panel.call(&"add_button", "General", func() -> void: pass, scene)
	panel.call(&"add_button", "+1 seat", func() -> void: pass, scene, "Stats")
	panel.call(&"add_button", "-1 seat", func() -> void: pass, scene, "Stats")

	# The main card has the general button and the group's toggle; the group's own card
	# sits to its right, shut.
	assert_int(buttons.get_child_count()).is_equal(2)
	var toggle := buttons.get_child(1) as Button
	assert_str(toggle.text).is_equal("Stats")
	assert_int(cards.get_child_count()).is_equal(2)
	var stats_card := cards.get_child(1) as Control
	assert_bool(stats_card.visible).is_false()
	assert_bool(panel.call(&"is_group_open", "Stats")).is_false()

	toggle.button_pressed = true
	assert_bool(stats_card.visible).is_true()
	assert_bool(panel.call(&"is_group_open", "Stats")).is_true()
	toggle.button_pressed = false
	assert_bool(stats_card.visible).is_false()

	scene.free()
	await runner.simulate_frames(2)
	assert_int(buttons.get_child_count()).is_equal(0)
	assert_int(cards.get_child_count()).is_equal(1)


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
