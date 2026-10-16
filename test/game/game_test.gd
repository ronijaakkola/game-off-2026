extends GdUnitTestSuite

const SCENE := "res://game/game.tscn"
## The centre of the board cell two cells right of and two cells in front of the middle.
const CELL := Vector3(1.6, 0.0, 1.6)
## The centre of the top of a piece placed in the middle cell. A piece is 0.4 m tall.
const TOP := Vector3(0.0, 0.4, 0.0)

var _window_size: Vector2i
var _placed: Array[Vector3] = []


func before() -> void:
	# Headless, the window is 64×64, and the canvas_items stretch would scale every
	# simulated click by 18. At the base size it scales by 1.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)


func after() -> void:
	get_tree().root.size = _window_size


func before_test() -> void:
	_placed.clear()
	Events.piece_placed.connect(_on_piece_placed)


func after_test() -> void:
	Events.piece_placed.disconnect(_on_piece_placed)


func test_click_on_the_board_places_a_piece_in_that_cell() -> void:
	var runner := scene_runner(SCENE)
	await _click(runner, CELL)
	await assert_func(self, "_placed_count").wait_until(2000).is_equal(1)
	assert_vector(_placed[0]).is_equal_approx(CELL, Vector3.ONE * 0.001)
	assert_str((runner.find_child("PlacedLabel") as Label).text).is_equal("Placed: 1")


func test_click_on_a_piece_stacks_one_on_top() -> void:
	var runner := scene_runner(SCENE)
	await _click(runner, Vector3.ZERO)
	await assert_func(self, "_placed_count").wait_until(2000).is_equal(1)
	await _click(runner, TOP)
	await assert_func(self, "_placed_count").wait_until(2000).is_equal(2)
	assert_vector(_placed[1]).is_equal_approx(TOP, Vector3.ONE * 0.001)


func test_click_off_the_board_places_nothing() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(1)
	_press_at(Vector2(10, 10))
	for i: int in 3:
		await get_tree().physics_frame
	assert_int(_placed_count()).is_equal(0)


func _click(runner: GdUnitSceneRunner, at: Vector3) -> void:
	await runner.simulate_frames(1)
	_press_at(runner.scene().get_viewport().get_camera_3d().unproject_position(at))


func _press_at(position: Vector2) -> void:
	# The runner's mouse calls also hand each event straight to the root's _unhandled_input,
	# so one click would place two pieces. Send it through Input alone.
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _placed_count() -> int:
	return _placed.size()


func _on_piece_placed(position: Vector3) -> void:
	_placed.append(position)
