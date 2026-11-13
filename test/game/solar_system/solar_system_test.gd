extends GdUnitTestSuite
## Passengers in the solar system, and the clicks that set the bus's course. The bus starts
## empty, docking lets off those going there, and the player picks up those waiting from
## the dock panel above the bus status. Opening a planet is in
## planet_panel_test.gd.

const SCENE := "res://game/solar_system/solar_system.tscn"


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
	var ledger := (runner.scene() as SolarSystem).get_ledger()
	assert_int(ledger.credits).is_equal(payout)
	var counter := runner.find_child("CreditsCounter") as CreditsCounter
	var gain := counter.find_child("GainLabel", true, false) as Label
	assert_str(gain.text).is_equal("+%d" % payout)
	# Once they are off, the total counts up to include the fare.
	await await_millis(1600)
	var total := (runner.find_child("TotalLabel") as Label).text
	assert_str(total).is_equal(CreditsCounter.format_credits(payout))
	assert_int(ledger.get_rating_count()).is_equal(1)
	assert_float(ledger.get_average_rating()).is_equal(passenger.get_rating())
	# Once they are off, the average shows their rating too.
	var average := (runner.find_child("AverageLabel") as Label).text
	assert_str(average).is_equal("%.1f" % passenger.get_rating())


func test_the_dock_panel_lists_who_waits_and_board_picks_up() -> void:
	var runner := scene_runner(SCENE)
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	waiting.set_process(false)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var ember := bus.get_docked_planet()
	# The game starts with some waiting at Ember: keep one.
	var picked := waiting.get_waiting(ember)[0]
	for passenger: Passenger in waiting.get_waiting(ember).slice(1):
		waiting.take(ember, passenger)
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


func test_the_pointer_on_a_waiting_row_shows_their_trip_and_a_click_pins_it() -> void:
	var runner := scene_runner(SCENE)
	var row := await _wait_for_a_boarding_row(runner)
	var camera := runner.find_child("Camera") as Camera3D
	var arc := runner.find_child("TripArc") as TripArc
	var name_label := row.find_child("NameLabel", true, false) as Control
	var on_row := _to_window(camera, name_label.get_global_rect().get_center())
	var away := _to_window(camera, _between_screen_point(runner))

	_send_motion(on_row)
	await runner.simulate_frames(2)
	assert_object(arc.get_destination()).is_same(row.passenger.destination)
	assert_bool(row.highlighted).is_true()
	# Both in their race's colour, not the destination's, which can come close to another
	# race's.
	var race_color := Race.SKIN_COLORS[row.passenger.race]
	var arc_material := arc.mesh.surface_get_material(0) as ShaderMaterial
	assert_object(arc_material.get_shader_parameter(&"color")).is_equal(race_color)
	var panel := row.find_child("Panel", true, false) as Control
	var style := panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_object(style.border_color).is_equal(race_color)
	_send_motion(away)
	await runner.simulate_frames(2)
	assert_object(arc.get_destination()).is_null()
	assert_bool(row.highlighted).is_false()

	# Clicked, it stays once the pointer leaves, until a second click.
	_send_button_click(on_row)
	_send_motion(away)
	await runner.simulate_frames(2)
	assert_object(arc.get_destination()).is_same(row.passenger.destination)
	assert_bool(row.highlighted).is_true()
	_send_button_click(on_row)
	_send_motion(away)
	await runner.simulate_frames(2)
	assert_object(arc.get_destination()).is_null()
	assert_bool(row.highlighted).is_false()


func test_boarding_a_pinned_passenger_hides_their_trip() -> void:
	var runner := scene_runner(SCENE)
	var row := await _wait_for_a_boarding_row(runner)
	var camera := runner.find_child("Camera") as Camera3D
	var arc := runner.find_child("TripArc") as TripArc
	var name_label := row.find_child("NameLabel", true, false) as Control
	_send_button_click(_to_window(camera, name_label.get_global_rect().get_center()))
	await runner.simulate_frames(2)
	assert_object(arc.get_destination()).is_not_null()
	var button := row.find_child("BoardButton", true, false) as Button

	_send_button_click(_to_window(camera, button.get_global_rect().get_center()))
	await runner.simulate_frames(2)

	assert_object(arc.get_destination()).is_null()


func test_waiting_markers_show_only_while_the_bus_has_the_trait() -> void:
	var runner := scene_runner(SCENE)
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	waiting.set_process(false)
	var terra := runner.find_child("Terra") as Planet
	waiting.add(terra)
	await runner.simulate_frames(2)
	var markers := runner.find_child("WaitingMarkers") as WaitingMarkers
	var traits := (runner.find_child("Bus") as FrameshiftBus).get_stats().get_traits()
	assert_bool(markers.is_shown(terra)).is_false()

	traits.add(BusTraits.Type.WAITING_MARKERS)
	await runner.simulate_frames(1)
	assert_bool(markers.is_shown(terra)).is_true()

	traits.remove(BusTraits.Type.WAITING_MARKERS)
	await runner.simulate_frames(1)
	assert_bool(markers.is_shown(terra)).is_false()


func test_a_right_click_on_the_bus_bar_sets_no_course() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var camera := runner.find_child("Camera") as Camera3D
	var bar := runner.find_child("BusBar", true, false) as Control
	var at := _to_window(camera, bar.get_global_rect().position + Vector2(8.0, 8.0))
	_send_motion(at)
	await runner.simulate_frames(1)

	_send_click(MOUSE_BUTTON_RIGHT, at)
	await runner.simulate_frames(1)

	assert_array((runner.find_child("Bus") as FrameshiftBus).get_route_stops()).is_empty()


func test_the_dock_panel_shrinks_with_its_top_edge_in_place() -> void:
	var runner := scene_runner(SCENE)
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	waiting.set_process(false)
	var ember := (runner.find_child("Bus") as FrameshiftBus).get_docked_planet()
	for i: int in 3:
		waiting.add(ember)
	await runner.simulate_frames(3)
	await await_millis(500)
	var card := runner.find_child("Card", true, false) as Control
	var top := card.get_global_rect().position.y
	var bottom := card.get_global_rect().end.y
	var camera := runner.find_child("Camera") as Camera3D
	var button := runner.find_child("BoardAllButton", true, false) as Button

	_send_button_click(_to_window(camera, button.get_global_rect().get_center()))

	# Every frame while the rows slide out and the card shrinks: the top edge stays, and the
	# bottom edge only ever moves up.
	for frame: int in 90:
		await runner.simulate_frames(1)
		var rect := card.get_global_rect()
		assert_float(rect.position.y).is_equal_approx(top, 0.01)
		assert_float(rect.end.y).is_less_equal(bottom + 0.01)
		bottom = rect.end.y
	assert_float(bottom).is_less(top + 200.0)


func test_the_dock_panel_shows_nobody_waiting_whole() -> void:
	var runner := scene_runner(SCENE)
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	waiting.set_process(false)
	var ember := (runner.find_child("Bus") as FrameshiftBus).get_docked_planet()
	for passenger: Passenger in waiting.get_waiting(ember).duplicate():
		waiting.take(ember, passenger)
	await runner.simulate_frames(3)
	await await_millis(800)
	var label := runner.find_child("EmptyLabel", true, false) as Control
	var clip := runner.find_child("Clip", true, false) as Control

	assert_bool(label.visible).is_true()
	var text_bottom := label.get_global_rect().position.y + (label as Label).get_line_height()
	assert_float(text_bottom).is_less_equal(clip.get_global_rect().end.y + 0.01)


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


func test_the_cabin_has_as_many_seats_as_the_bus_seats_stat() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var cabin := runner.find_child("Cabin") as Cabin
	var stats := (runner.find_child("Bus") as FrameshiftBus).get_stats()
	assert_int(stats.get_seats()).is_equal(cabin.seats)
	var before := cabin.seats

	stats.add_modifier(StatModifier.new(BusStats.Type.SEATS, StatModifier.Kind.FLAT, 2.0))

	assert_int(cabin.seats).is_equal(before + 2)


func test_the_dock_panel_slides_out_once_the_bus_leaves() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var panel := runner.find_child("DockPanel") as DockPanel
	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_bool(panel.visible).is_true()

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, runner.find_child("Terra") as Planet))
	bus.frameshift_held = true

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
	var hint := (runner.find_child("Notices") as NoticeStack).get_notices()[0]
	assert_str(hint.get_text()).is_equal(SolarSystem.COURSE_HINT % QueueKey.get_label())
	assert_bool(hint.is_leaving()).is_false()

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))

	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_array(bus.get_route_planets()).contains_exactly([terra])
	assert_bool(hint.is_leaving()).is_true()


func test_right_click_sets_the_route_and_with_the_queue_key_adds_to_it() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var giant := runner.find_child("Giant") as Planet
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))
	_queued_click(_screen_point(runner, giant))
	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_array(bus.get_route_planets()).contains_exactly([terra, giant])

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, giant))

	assert_array(bus.get_route_planets()).contains_exactly([giant])


func test_right_click_on_the_docked_planet_with_a_route_makes_a_round_trip() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var bus := runner.find_child("Bus") as FrameshiftBus
	var home := bus.get_docked_planet()
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))

	_queued_click(_screen_point(runner, home))

	assert_array(bus.get_route_planets()).contains_exactly([terra, home])


func test_right_click_on_the_docked_planet_with_no_route_does_nothing() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus

	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, bus.get_docked_planet()))

	assert_object(bus.get_last_stop()).is_null()
	assert_float(bus.get_charge_progress()).is_equal(0.0)


func test_clear_route_takes_the_last_stop_off() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var giant := runner.find_child("Giant") as Planet
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))
	_queued_click(_screen_point(runner, giant))

	var key := InputEventKey.new()
	key.keycode = KEY_BACKSPACE
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()

	var bus := runner.find_child("Bus") as FrameshiftBus
	assert_array(bus.get_route_planets()).contains_exactly([terra])


func test_right_click_on_space_with_the_queue_key_adds_a_point_after_the_planet() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var terra := runner.find_child("Terra") as Planet
	var camera := runner.find_child("Camera") as Camera3D
	var on_screen := _between_screen_point(runner)
	_send_click(MOUSE_BUTTON_RIGHT, _screen_point(runner, terra))

	_queued_click(_to_window(camera, on_screen))

	var stops := (runner.find_child("Bus") as FrameshiftBus).get_route_stops()
	assert_int(stops.size()).is_equal(2)
	assert_object(stops[0].planet).is_same(terra)
	assert_object(stops[1].planet).is_null()
	assert_vector(camera.unproject_position(stops[1].point)).is_equal_approx(on_screen, Vector2.ONE)


# A right click at [param at] with the queue key held.
func _queued_click(at: Vector2) -> void:
	Input.action_press(&"queue_stop")
	_send_click(MOUSE_BUTTON_RIGHT, at)
	Input.action_release(&"queue_stop")


# One passenger waiting at the planet the bus is docked at, and their row in the dock
# panel once it has slid in.
func _wait_for_a_boarding_row(runner: GdUnitSceneRunner) -> BoardingRow:
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	waiting.set_process(false)
	waiting.add((runner.find_child("Bus") as FrameshiftBus).get_docked_planet())
	# Half a second of game time at the 60 fps the tests run at, not of the wall clock, so
	# the dock panel has slid in however slowly a machine draws the frames.
	await runner.simulate_frames(33)
	return runner.find_child("BoardingRow", true, false) as BoardingRow


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


func test_requesting_a_tow_costs_its_fee_even_into_debt() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var notices := runner.find_child("Notices") as NoticeStack
	var ledger := (runner.scene() as SolarSystem).get_ledger()
	ledger.credits = 50

	bus.ran_out_of_fuel.emit()
	notices.get_notices()[0].action_pressed.emit()
	assert_int(ledger.credits).is_equal(50 - TowDispatch.TOW_FEE)
	var loss := runner.find_child("LossLabel") as Label
	assert_str(loss.text).is_equal("-%d" % TowDispatch.TOW_FEE)

	ledger.credits = TowDispatch.TOW_FEE - 5
	bus.ran_out_of_fuel.emit()
	notices.get_notices()[0].action_pressed.emit()
	assert_int(ledger.credits).is_equal(-5)


func test_running_dry_in_space_offers_a_tow_and_sends_one_ship_once_requested() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var dispatch := runner.find_child("TowDispatch") as TowDispatch
	var bus := runner.find_child("Bus") as FrameshiftBus
	var notices := runner.find_child("Notices") as NoticeStack
	var is_tow := func(notice: Notice) -> bool: return notice.get_text() == "You ran out of fuel"
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	var passenger := waiting.create(bus.get_docked_planet())
	(runner.find_child("Cabin") as Cabin).board(passenger)
	bus.plot_course(RouteStop.at_point(bus.global_position + Vector3(0.0, 0.0, 30.0)))
	bus.frameshift_held = true
	await assert_func(bus, "is_at_planet").wait_until(5000).is_false()
	assert_array(notices.get_notices().filter(is_tow)).is_empty()

	var before := passenger.happiness
	bus.get_fuel_tank().drain()
	assert_float(passenger.happiness).is_equal(before + TowDispatch.OUT_OF_FUEL_SHOCK)
	await runner.simulate_frames(1)

	var is_ship := func(node: Node) -> bool: return node is TowShip
	var offer := notices.get_notices().filter(is_tow)[0] as Notice
	var button := offer.find_child("ActionButton") as Button
	assert_str(button.text).is_equal("Tow (%d credits)" % TowDispatch.TOW_FEE)
	assert_int(dispatch.get_children().filter(is_ship).size()).is_equal(0)

	button.pressed.emit()
	await runner.simulate_frames(1)

	assert_bool(offer.is_leaving()).is_true()
	assert_int(dispatch.get_children().filter(is_ship).size()).is_equal(1)
