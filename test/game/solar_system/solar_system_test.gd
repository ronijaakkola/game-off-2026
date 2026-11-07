extends GdUnitTestSuite
## Passengers in the solar system, the clicks that set the bus's course, and the left
## clicks that open and close a planet. One passenger is on board at the start, and docking
## lets off those going there and takes on those waiting.

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
	# Once they are off, the total counts up to include the fare.
	await await_millis(1600)
	var total := (runner.find_child("TotalLabel") as Label).text
	assert_str(total).is_equal("%d credits" % payout)


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
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, giant), true)

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, giant))

	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_array(bus.get_route_planets()).contains_exactly([terra])


func test_shift_right_click_on_the_last_planet_also_removes_it() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var giant := runner.find_child("Giant") as Planet
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, giant), true)

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, giant), true)

	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_array(bus.get_route_planets()).contains_exactly([terra])


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
	_send_click(MOUSE_BUTTON_RIGHT, _to_window(camera, on_screen), true)
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
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra), true)
	var bus := runner.find_child("Bus") as FrameshiftBus

	_send_motion(_to_window(camera, on_screen))
	await runner.simulate_frames(1)

	assert_object(bus.hovered_stop).is_null()


func test_left_click_on_a_planet_opens_it_and_again_closes_it() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var system := runner.scene() as SolarSystem
	var terra := runner.find_child("Terra") as Planet
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	waiting.add(terra)
	waiting.add(terra)
	var rig := runner.find_child("CameraRig") as CameraRig

	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, terra))

	assert_object(system.get_open_planet()).is_same(terra)
	assert_bool(rig.is_focused()).is_true()
	assert_bool((runner.find_child("PlanetPanel") as Control).visible).is_true()
	assert_str((runner.find_child("PlanetNameLabel") as Label).text).is_equal("Terra")
	var rows := runner.find_child("WaitingRows") as Node
	assert_int(rows.get_child_count()).is_equal(waiting.count_at(terra))
	await runner.simulate_frames(1)
	assert_bool((runner.find_child("HintBox") as Control).visible).is_false()

	await runner.simulate_frames(2)
	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, terra))

	assert_object(system.get_open_planet()).is_null()
	assert_bool(rig.is_focused()).is_false()
	await runner.simulate_frames(1)
	assert_bool((runner.find_child("HintBox") as Control).visible).is_true()


func test_open_planet_sits_left_of_the_panel_and_left_click_on_space_closes_it() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var system := runner.scene() as SolarSystem
	var terra := runner.find_child("Terra") as Planet
	var camera := runner.find_child("Camera") as Camera3D
	var panel := runner.find_child("PlanetPanel") as PlanetPanel
	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, terra))
	await await_millis(1200)

	var on_screen := camera.unproject_position(terra.get_body_global_position())
	assert_float(on_screen.x).is_less(panel.get_global_rect().position.x)
	var rig := runner.find_child("CameraRig") as CameraRig
	assert_float(on_screen.x).is_equal_approx(rig.focus_screen_x, 2.0)

	# Above the planet, clear of it and of the panel.
	_send_click(MOUSE_BUTTON_LEFT, _to_window(camera, Vector2(on_screen.x, 40.0)))

	assert_object(system.get_open_planet()).is_null()


func test_left_click_on_the_panel_keeps_it_open_and_its_close_button_closes_it() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var system := runner.scene() as SolarSystem
	var terra := runner.find_child("Terra") as Planet
	var camera := runner.find_child("Camera") as Camera3D
	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, terra))
	await await_millis(500)
	var sheet := runner.find_child("Sheet") as Control

	_send_click(MOUSE_BUTTON_LEFT, _to_window(camera, sheet.get_global_rect().get_center()))
	_send_release(MOUSE_BUTTON_LEFT, _to_window(camera, sheet.get_global_rect().get_center()))
	assert_object(system.get_open_planet()).is_same(terra)

	var button := runner.find_child("CloseButton") as Button
	_send_click(MOUSE_BUTTON_LEFT, _to_window(camera, button.get_global_rect().get_center()))
	_send_release(MOUSE_BUTTON_LEFT, _to_window(camera, button.get_global_rect().get_center()))

	assert_object(system.get_open_planet()).is_null()
	assert_bool((runner.find_child("CameraRig") as CameraRig).is_focused()).is_false()


func test_left_click_on_another_planet_opens_that_one() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var system := runner.scene() as SolarSystem
	var terra := runner.find_child("Terra") as Planet
	var ember := runner.find_child("Ember") as Planet
	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, terra))
	await runner.simulate_frames(1)

	# The camera has barely moved, and the panel is still sliding in at the right edge.
	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, ember))

	assert_object(system.get_open_planet()).is_same(ember)
	assert_str((runner.find_child("PlanetNameLabel") as Label).text).is_equal("Ember")
	assert_bool((runner.find_child("CameraRig") as CameraRig).is_focused()).is_true()


func test_right_click_still_sets_course_while_a_planet_is_open() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	_send_click(MOUSE_BUTTON_LEFT, _screen_point(runner, terra))
	await runner.simulate_frames(1)

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))

	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_array(bus.get_route_planets()).contains_exactly([terra])
	assert_object((runner.scene() as SolarSystem).get_open_planet()).is_same(terra)


func test_the_preview_opens_terra_with_three_waiting() -> void:
	var runner := scene_runner("res://test/previews/solar_system_preview.tscn")
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var system := runner.find_child("SolarSystem") as SolarSystem
	assert_object(system.get_open_planet()).is_same(terra)
	assert_int((runner.find_child("WaitingRows") as Node).get_child_count()).is_equal(3)


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
func _send_click(button: MouseButton, at: Vector2, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.shift_pressed = shift
	event.position = at
	event.global_position = at
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _send_release(button: MouseButton, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.global_position = at
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _send_motion(to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	Input.parse_input_event(event)
	Input.flush_buffered_events()
