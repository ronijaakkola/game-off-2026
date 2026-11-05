extends GdUnitTestSuite

const SCENE := "res://phase_miner/phase_miner.tscn"

var _window_size: Vector2i


func before() -> void:
	# Headless, the window is 64×64, and the canvas_items stretch would scale every
	# simulated pointer position. At the base size it scales by 1.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)


func after() -> void:
	get_tree().root.size = _window_size


func test_an_arrow_key_phases_the_ship_through_the_items_in_that_line() -> void:
	var runner := scene_runner(SCENE)
	var field := _empty_field(runner)
	field.set_item(Vector2i(2, 4), PhaseField.Item.SCRAP)
	field.set_item(Vector2i(3, 4), PhaseField.Item.CRYSTAL)
	await runner.simulate_frames(1)

	_press_key(KEY_RIGHT)
	await assert_func(self, "_ship_of", [field]).wait_until(2000).is_equal(Vector2i(4, 4))
	assert_int(field.get_item(Vector2i(3, 4))).is_equal(PhaseField.Item.NONE)
	await assert_func(self, "_text_of", [runner, "ScoreLabel"]).wait_until(2000).is_equal(
		"Score  70"
	)


func test_dragging_a_row_slides_it_and_carries_the_ship() -> void:
	var runner := scene_runner(SCENE)
	var field := _empty_field(runner)
	field.set_item(Vector2i(6, 4), PhaseField.Item.ROCK)
	await runner.simulate_frames(1)

	# Drag the ship's row two cells right, from the ship's cell.
	var camera := runner.scene().get_viewport().get_camera_3d()
	var from := Vector3(-3.5, 0.4, 0.5)
	_mouse(camera.unproject_position(from), true)
	_move(camera.unproject_position(from + Vector3(1.0, 0.0, 0.0)))
	_move(camera.unproject_position(from + Vector3(2.0, 0.0, 0.0)))
	_mouse(camera.unproject_position(from + Vector3(2.0, 0.0, 0.0)), false)
	await runner.simulate_frames(1)

	assert_that(field.ship).is_equal(Vector2i(2, 4))
	assert_int(field.get_item(Vector2i(0, 4))).is_equal(PhaseField.Item.ROCK)
	assert_int(field.fuel).is_equal(PhaseField.START_FUEL - 2)


# Clears the scene's field to an empty board with the ship at column 0, row 4: the board point
# (-3.5, 0.4, 0.5). One scrap is left out of the way, at column 6, row 0, so the field isn't
# mined out after a move and replaced.
func _empty_field(runner: GdUnitSceneRunner) -> PhaseField:
	var field := runner.get_property("field") as PhaseField
	for row: int in PhaseField.SIZE:
		for column: int in PhaseField.SIZE:
			field.set_item(Vector2i(column, row), PhaseField.Item.NONE)
	field.set_item(Vector2i(6, 0), PhaseField.Item.SCRAP)
	field.ship = Vector2i(0, 4)
	return field


func _ship_of(field: PhaseField) -> Vector2i:
	return field.ship


func _text_of(runner: GdUnitSceneRunner, label: String) -> String:
	return (runner.find_child(label) as Label).text


# The runner's own input calls also hand each event straight to the root's _unhandled_input,
# so one key press would phase twice. Send through Input alone.
func _press_key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _move(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	Input.flush_buffered_events()
