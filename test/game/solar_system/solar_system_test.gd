extends GdUnitTestSuite
## Passengers in the solar system, and the clicks that set the bus's course. One passenger
## is on board at the start, and docking lets off those going there and takes on those
## waiting.

const SCENE := "res://game/solar_system/solar_system.tscn"


func test_starts_with_one_passenger_on_board() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var cabin := runner.find_child("Cabin") as Cabin
	assert_int(cabin.get_passengers().size()).is_equal(1)
	assert_int((runner.find_child("Cards") as Control).get_child_count()).is_equal(1)


func test_docking_lets_them_off_and_pays_then_boards_before_the_bus_can_charge() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var cabin := runner.find_child("Cabin") as Cabin
	var bus := runner.find_child("Bus") as FrameshiftBus
	var passenger := cabin.get_passengers()[0]
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	waiting.take(passenger.destination, 99)
	waiting.add(passenger.destination)
	var payout := passenger.get_payout()

	bus.docked.emit(passenger.destination)

	assert_array(cabin.get_passengers()).not_contains([passenger])
	assert_bool(bus.boarding).is_true()
	await assert_signal(cabin).wait_until(3000).is_emitted("stop_finished")
	assert_bool(bus.boarding).is_false()
	assert_int(cabin.get_passengers().size()).is_equal(1)
	var counter := runner.find_child("CreditsCounter") as CreditsCounter
	assert_int(counter.credits).is_equal(payout)
	assert_str((runner.find_child("GainLabel") as Label).text).is_equal("+%d" % payout)


func test_right_click_on_a_planet_sets_course_and_hides_the_hint() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var hint := runner.find_child("CourseHint") as Label
	assert_bool(hint.visible).is_true()

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))

	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_array(bus.get_route_planets()).contains_exactly([terra])
	assert_bool(hint.visible).is_false()


func test_left_click_on_a_planet_sets_no_course() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet

	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, terra))

	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_array(bus.get_route_planets()).is_empty()
	assert_bool((runner.find_child("CourseHint") as Label).visible).is_true()


func test_shift_right_click_on_the_last_planet_removes_it() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var giant := runner.find_child("Giant") as Planet
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, giant), true)

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, giant), true)

	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_array(bus.get_route_planets()).contains_exactly([terra])


func test_shift_right_click_on_the_last_point_in_space_removes_it() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var giant := runner.find_child("Giant") as Planet
	var camera := runner.find_child("Camera") as Camera3D
	# Halfway from Terra to Giant, clear of every planet.
	var between := terra.get_body_global_position().lerp(giant.get_body_global_position(), 0.5)
	var on_screen := camera.unproject_position(between)
	var point := _to_window(camera, on_screen)
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))
	_send_click(MOUSE_BUTTON_RIGHT, point, true)
	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_object(bus.get_last_stop().planet).is_null()

	# A few pixels off the point still hits its diamond.
	_send_click(MOUSE_BUTTON_RIGHT, _to_window(camera, on_screen + Vector2(4, 4)), true)

	assert_object(bus.get_last_stop().planet).is_same(terra)


func _screen_point(runner: GdUnitSceneRunner, planet: Planet) -> Vector2:
	var camera := runner.find_child("Camera") as Camera3D
	return _to_window(camera, camera.unproject_position(planet.get_body_global_position()))


# Where a viewport point is in window pixels, which a sent event carries: the viewport's
# own pixels differ by the window's stretch.
func _to_window(camera: Camera3D, viewport_point: Vector2) -> Vector2:
	return camera.get_viewport().get_final_transform() * viewport_point


# Through Input alone: the runner's own calls deliver each event twice to the root.
func _send_click(button: MouseButton, at: Vector2, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.shift_pressed = shift
	event.position = at
	event.global_position = at
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
