extends GdUnitTestSuite
## Holding the fuel button.

const SCENE := "res://game/solar_system/fuel_button.tscn"

var _window_size: Vector2i


func before() -> void:
	# Headless, the window is 64×64, and the canvas_items stretch would scale every
	# simulated click by 18. At the base size it scales by 1.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)


func after() -> void:
	get_tree().root.size = _window_size


# A pan key lets go of the focus a click left hidden, and an arrow key moves the focus on;
# the fuel button held down keeps both, so the camera pans while the tank fills.
func test_the_fuel_button_stays_held_while_a_pan_key_moves_the_camera() -> void:
	# With a button to its right for the right arrow key to move the focus to, as in the
	# station panel.
	var row := HBoxContainer.new()
	var button := (load(SCENE) as PackedScene).instantiate() as FuelButton
	var neighbour := Button.new()
	neighbour.text = "Research"
	row.add_child(button)
	row.add_child(neighbour)
	var runner := scene_runner(row)
	button.show_fuel(0.5, 8, true, "")
	await runner.simulate_frames(2)
	runner.set_mouse_position(button.get_global_rect().get_center())
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2)
	assert_bool(button.is_held()).is_true()

	FocusRing.drop_hidden()
	await runner.simulate_frames(2)
	assert_bool(button.is_held()).is_true()

	runner.simulate_key_press(KEY_RIGHT)
	await runner.simulate_frames(2)
	assert_bool(button.is_held()).is_true()
	assert_bool(neighbour.has_focus()).is_false()

	runner.simulate_key_release(KEY_RIGHT)
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2)
	assert_bool(button.is_held()).is_false()
