extends GdUnitTestSuite
## Passengers in the solar system, and the clicks that set the bus's course. One passenger
## is on board at the start, docking lets off those going there, and the player picks
## up those waiting from the dock panel above the bus status. Opening a planet is in
## planet_panel_test.gd.

const SCENE := "res://game/solar_system/solar_system.tscn"


func test_starts_with_one_passenger_on_board() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var cabin := runner.find_child("Cabin") as Cabin
	assert_int(cabin.get_passengers().size()).is_equal(1)
	assert_int((runner.find_child("Cards") as Control).get_child_count()).is_equal(1)


func test_docking_lets_them_off_and_pays_and_nobody_boards_by_themselves() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var cabin := runner.find_child("Cabin") as Cabin
	var bus := runner.find_child("Bus") as FrameshiftBus
	var passenger := cabin.get_passengers()[0]
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	waiting.add(passenger.destination)
	var count := waiting.count_at(passenger.destination)
	var payout := passenger.get_payout()

	bus.docked.emit(passenger.destination)

	assert_array(cabin.get_passengers()).not_contains([passenger])
	assert_bool(bus.boarding).is_true()
	await assert_signal(cabin).wait_until(3000).is_emitted("stop_finished")
	assert_bool(bus.boarding).is_false()
	assert_int(cabin.get_passengers().size()).is_equal(0)
	assert_int(waiting.count_at(passenger.destination)).is_equal(count)
	var counter := runner.find_child("CreditsCounter") as CreditsCounter
	assert_int(counter.credits).is_equal(payout)
	assert_str((runner.find_child("GainLabel") as Label).text).is_equal("+%d" % payout)
	# Once they are off, the total counts up to include the fare.
	await await_millis(1600)
	var total := (runner.find_child("TotalLabel") as Label).text
	assert_str(total).is_equal("%d credits" % payout)


func test_the_dock_panel_lists_who_waits_and_board_picks_up() -> void:
	var runner := scene_runner(SCENE)
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	waiting.set_process(false)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var ember := bus.get_docked_planet()
	waiting.add(ember)
	var picked := waiting.get_waiting(ember)[0]
	await runner.simulate_frames(3)
	var panel := runner.find_child("DockPanel") as DockPanel
	var markers := runner.find_child("WaitingMarkers") as WaitingMarkers
	assert_bool(panel.visible).is_true()
	assert_str((panel.find_child("TitleLabel") as Label).text).is_equal("Waiting at Ember")
	assert_bool(markers.is_shown(ember)).is_true()
	assert_int(markers.count_at(ember)).is_equal(1)
	var cabin := runner.find_child("Cabin") as Cabin
	monitor_signals(cabin)
	var camera := runner.find_child("Camera") as Camera3D
	var button := panel.find_child("BoardButton", true, false) as Button

	_send_button_click(_to_window(camera, button.get_global_rect().get_center()))

	await assert_signal(cabin).wait_until(2000).is_emitted("stop_finished")
	assert_array(cabin.get_passengers()).contains([picked])
	assert_int(waiting.count_at(ember)).is_equal(0)
	assert_int(markers.count_at(ember)).is_equal(0)
	await runner.simulate_frames(1)
	assert_bool(panel.visible).is_true()
	assert_bool((panel.find_child("EmptyLabel") as Control).visible).is_true()


func test_the_dock_panel_hides_once_the_bus_leaves() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var panel := runner.find_child("DockPanel") as DockPanel
	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_bool(panel.visible).is_true()

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, runner.find_child("Terra") as Planet))

	# It stays while the drive charges, so the player can still pick passengers up.
	await assert_func(bus, "get_charge_progress").wait_until(2000).is_not_equal(0.0)
	await runner.simulate_frames(1)
	assert_bool(panel.visible).is_true()
	await assert_func(bus, "is_at_planet").wait_until(5000).is_false()
	await runner.simulate_frames(1)
	assert_bool(panel.visible).is_false()


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


func test_right_click_on_the_last_planet_removes_it() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var giant := runner.find_child("Giant") as Planet
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, giant))

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, giant))

	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_array(bus.get_route_planets()).contains_exactly([terra])


func test_right_clicks_add_stops_one_after_another() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var giant := runner.find_child("Giant") as Planet

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, giant))

	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_array(bus.get_route_planets()).contains_exactly([terra, giant])


func test_right_click_on_the_docked_planet_with_a_route_makes_a_round_trip() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var bus := runner.find_child("Bus") as FrameshiftBus
	var home := bus.get_docked_planet()
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, home))

	assert_array(bus.get_route_planets()).contains_exactly([terra, home])


func test_right_click_on_the_docked_planet_with_no_route_does_nothing() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, bus.get_docked_planet()))

	assert_object(bus.get_last_stop()).is_null()
	assert_float(bus.get_charge_progress()).is_equal(0.0)


func test_clear_route_clears_every_stop() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var giant := runner.find_child("Giant") as Planet
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, giant))

	var key := InputEventKey.new()
	key.keycode = KEY_BACKSPACE
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()

	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_object(bus.get_last_stop()).is_null()
	assert_float(bus.get_charge_progress()).is_equal(0.0)


func test_right_click_on_the_only_planet_cancels_the_course() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))

	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_object(bus.get_last_stop()).is_null()
	assert_float(bus.get_charge_progress()).is_equal(0.0)


func test_right_click_on_the_last_point_in_space_removes_it() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var camera := runner.find_child("Camera") as Camera3D
	var on_screen := _between_screen_point(runner)
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))
	_send_click(MOUSE_BUTTON_RIGHT, _to_window(camera, on_screen))
	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_object(bus.get_last_stop().planet).is_null()

	# A few pixels off the point still hits its diamond.
	_send_click(MOUSE_BUTTON_RIGHT, _to_window(camera, on_screen + Vector2(4, 4)))

	assert_object(bus.get_last_stop().planet).is_same(terra)


func test_hovering_the_last_point_in_space_picks_it() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var camera := runner.find_child("Camera") as Camera3D
	var on_screen := _between_screen_point(runner)
	_send_click(MOUSE_BUTTON_RIGHT, _to_window(camera, on_screen))
	var bus := runner.find_child("Bus") as FrameshiftBus
	var point := bus.get_last_stop()

	_send_motion(_to_window(camera, on_screen + Vector2(4, 4)))
	await runner.simulate_frames(1)
	assert_object(bus.hovered_stop).is_same(point)

	_send_motion(_to_window(camera, on_screen + Vector2(200, 0)))
	await runner.simulate_frames(1)
	assert_object(bus.hovered_stop).is_null()


func test_hovering_a_point_in_space_before_the_last_stop_picks_nothing() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var camera := runner.find_child("Camera") as Camera3D
	var on_screen := _between_screen_point(runner)
	_send_click(MOUSE_BUTTON_RIGHT, _to_window(camera, on_screen))
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))
	var bus := runner.find_child("Bus") as FrameshiftBus

	_send_motion(_to_window(camera, on_screen))
	await runner.simulate_frames(1)

	assert_object(bus.hovered_stop).is_null()


# Halfway from Terra to Giant on screen, in viewport pixels: clear of every planet.
func _between_screen_point(runner: GdUnitSceneRunner) -> Vector2:
	var terra := runner.find_child("Terra") as Planet
	var giant := runner.find_child("Giant") as Planet
	var camera := runner.find_child("Camera") as Camera3D
	var between := terra.get_body_global_position().lerp(giant.get_body_global_position(), 0.5)
	return camera.unproject_position(between)


func _screen_point(runner: GdUnitSceneRunner, planet: Planet) -> Vector2:
	var camera := runner.find_child("Camera") as Camera3D
	return _to_window(camera, camera.unproject_position(planet.get_body_global_position()))


# Where a viewport point is in window pixels, which a sent event carries: the viewport's
# own pixels differ by the window's stretch.
func _to_window(camera: Camera3D, viewport_point: Vector2) -> Vector2:
	return camera.get_viewport().get_final_transform() * viewport_point


# Through Input alone: the runner's own calls deliver each event twice to the root.
func _send_click(button: MouseButton, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.global_position = at
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# A press and its release, which a Button needs to count as pressed.
func _send_button_click(at: Vector2) -> void:
	_send_motion(at)
	_send_click(MOUSE_BUTTON_LEFT, at)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = at
	release.global_position = at
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _send_motion(to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	Input.parse_input_event(event)
	Input.flush_buffered_events()
