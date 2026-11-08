extends GdUnitTestSuite
## Passengers in the solar system, and the clicks that set the bus's course. The bus starts
## empty, docking lets off those going there, and the player picks up those waiting from
## the dock panel above the bus status. Opening a planet is in
## planet_panel_test.gd.

const SCENE := "res://game/solar_system/solar_system.tscn"


func test_starts_with_the_bus_empty() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var cabin := runner.find_child("Cabin") as Cabin
	assert_int(cabin.get_passengers().size()).is_equal(0)
	assert_int((runner.find_child("Cards") as Control).get_child_count()).is_equal(0)


func test_docking_lets_them_off_and_pays_and_nobody_boards_by_themselves() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var cabin := runner.find_child("Cabin") as Cabin
	var bus := runner.find_child("Bus") as FrameshiftBus
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	var passenger := waiting.create(bus.get_docked_planet())
	cabin.board(passenger)
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
	var gain := counter.find_child("GainLabel", true, false) as Label
	assert_str(gain.text).is_equal("+%d" % payout)
	# Once they are off, the total counts up to include the fare.
	await await_millis(1600)
	var total := (runner.find_child("TotalLabel") as Label).text
	assert_str(total).is_equal("%d credits" % payout)
	var rating := runner.find_child("RatingCounter") as RatingCounter
	assert_int(rating.get_count()).is_equal(1)
	assert_float(rating.get_average()).is_equal(passenger.get_rating())
	# Once they are off, the average shows their rating too.
	var average := (runner.find_child("AverageLabel") as Label).text
	assert_str(average).is_equal("%.1f" % passenger.get_rating())


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
	assert_str((panel.find_child("NameLabel", true, false) as Label).text).is_equal("Ember")
	assert_int(markers.count_at(ember)).is_equal(1)
	var cabin := runner.find_child("Cabin") as Cabin
	monitor_signals(cabin)
	# Slid in from the right by now.
	await await_millis(500)
	var camera := runner.find_child("Camera") as Camera3D
	var row := panel.find_child("BoardingRow", true, false) as BoardingRow
	var button := row.find_child("BoardButton", true, false) as Button

	_send_button_click(_to_window(camera, button.get_global_rect().get_center()))

	await assert_signal(cabin).wait_until(2000).is_emitted("stop_finished")
	assert_array(cabin.get_passengers()).contains([picked])
	assert_int(waiting.count_at(ember)).is_equal(0)
	assert_int(markers.count_at(ember)).is_equal(0)
	assert_bool((panel.find_child("EmptyLabel", true, false) as Control).visible).is_true()
	# The row slid out and closed up while they got on.
	assert_bool(is_instance_valid(row)).is_false()


func test_the_dock_panel_shrinks_with_its_bottom_edge_and_board_all_in_place() -> void:
	var runner := scene_runner(SCENE)
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	waiting.set_process(false)
	var ember := (runner.find_child("Bus") as FrameshiftBus).get_docked_planet()
	for i: int in 3:
		waiting.add(ember)
	await runner.simulate_frames(3)
	await await_millis(500)
	var card := runner.find_child("Card", true, false) as Control
	var bottom := card.get_global_rect().end.y
	var top := card.get_global_rect().position.y
	var camera := runner.find_child("Camera") as Camera3D
	var button := runner.find_child("BoardAllButton", true, false) as Button
	var button_at := button.get_global_rect().position.y

	_send_button_click(_to_window(camera, button.get_global_rect().get_center()))

	# Every frame while the rows slide out and the card shrinks: the bottom edge and Board
	# all stay, and the top edge only ever moves down.
	for frame: int in 90:
		await runner.simulate_frames(1)
		var rect := card.get_global_rect()
		assert_float(rect.end.y).is_equal_approx(bottom, 0.01)
		assert_float(button.get_global_rect().position.y).is_equal_approx(button_at, 0.01)
		assert_float(rect.position.y).is_greater_equal(top - 0.01)
		top = rect.position.y
	assert_float(top).is_greater(bottom - 200.0)


func test_board_all_picks_up_everyone_that_fits_and_then_says_the_bus_is_full() -> void:
	var runner := scene_runner(SCENE)
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	waiting.set_process(false)
	waiting.max_per_planet = 4
	var bus := runner.find_child("Bus") as FrameshiftBus
	var ember := bus.get_docked_planet()
	for i: int in 4:
		waiting.add(ember)
	var line := waiting.get_waiting(ember)
	await runner.simulate_frames(3)
	await await_millis(500)
	var cabin := runner.find_child("Cabin") as Cabin
	var panel := runner.find_child("DockPanel") as DockPanel
	var button := panel.find_child("BoardAllButton", true, false) as Button
	assert_str(button.text).is_equal("Board all")
	var camera := runner.find_child("Camera") as Camera3D

	monitor_signals(cabin)

	_send_button_click(_to_window(camera, button.get_global_rect().get_center()))
	await assert_func(button, "is_disabled").wait_until(1000).is_true()

	# The bus starts empty, so all four fit.
	assert_array(waiting.get_waiting(ember)).is_empty()
	assert_int(cabin.get_free_seats()).is_equal(0)
	assert_str(button.text).is_equal("Bus full %d/%d" % [cabin.seats, cabin.seats])
	# They get on one at a time, longest waiting first.
	await assert_signal(cabin).wait_until(4000).is_emitted("stop_finished")
	assert_array(cabin.get_passengers()).contains_exactly(line)


func test_the_dock_panel_slides_out_once_the_bus_leaves() -> void:
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
	await assert_func(panel, "is_visible").wait_until(2000).is_false()


func test_runs_after_the_camera_host_so_labels_follow_this_frame() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	# Phantom Camera's host sets its own priority; this fails if an upgrade changes it.
	var host := runner.find_child("PhantomCameraHost") as Node
	assert_int(host.process_priority).is_equal(SolarSystem.CAMERA_HOST_PRIORITY)
	var system := runner.scene() as SolarSystem
	assert_int(system.process_priority).is_greater(host.process_priority)


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
