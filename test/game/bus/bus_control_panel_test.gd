extends GdUnitTestSuite
## The bus control panel in the solar system: it says what the bus is doing and how many
## seats are taken and how much fuel is left; its button, held, charges the drive, and in
## flight is the Emergency stop.

const SCENE := "res://game/solar_system/solar_system.tscn"

var _window_size: Vector2i


func before() -> void:
	# Headless, the window is 64×64, and the canvas_items stretch would scale every
	# simulated click. At the base size it scales by 1.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)


func after() -> void:
	get_tree().root.size = _window_size


func test_holding_the_button_charges_and_letting_go_keeps_the_route() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var button := runner.find_child("FrameshiftButton") as Button
	assert_bool(button.disabled).is_true()
	bus.plot_course(RouteStop.at_planet(runner.find_child("Terra") as Planet))
	await runner.simulate_frames(2)
	assert_int(bus.state).is_equal(FrameshiftBus.State.DOCKED)
	assert_bool(button.disabled).is_false()
	assert_str(_text(runner, "ButtonLabel")).is_equal("Hold to frameshift")

	runner.set_mouse_position(button.get_global_rect().get_center())
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	await runner.simulate_frames(2)
	assert_int(bus.state).is_equal(FrameshiftBus.State.CHARGING)
	assert_str(_text(runner, "StateLabel")).is_equal("Charging frameshift")

	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	await runner.simulate_frames(2)

	assert_int(bus.state).is_equal(FrameshiftBus.State.DOCKED)
	assert_object(bus.get_last_stop()).is_not_null()


func test_the_emergency_stop_cancels_the_course_in_flight() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	bus.hold_to_charge = false
	bus.charge_time = 0.0
	bus.plot_course(RouteStop.at_planet(runner.find_child("Terra") as Planet))
	await assert_func(bus, "is_at_planet").wait_until(2000).is_false()
	await runner.simulate_frames(2)
	var button := runner.find_child("FrameshiftButton") as Button
	assert_str(_text(runner, "ButtonLabel")).is_equal("Emergency stop")

	runner.set_mouse_position(button.get_global_rect().get_center())
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	await runner.simulate_frames(1)

	assert_object(bus.get_last_stop()).is_null()
	assert_str(_text(runner, "StateLabel")).is_not_equal("Travelling to Terra")


func test_shows_the_fuel_left_and_says_when_it_runs_out_at_a_planet() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var tank := (runner.find_child("Bus") as FrameshiftBus).get_fuel_tank()
	assert_str(_text(runner, "FuelAmount")).is_equal("100%")
	tank.fuel = tank.capacity * 0.4
	await runner.simulate_frames(1)
	assert_str(_text(runner, "FuelAmount")).is_equal("40%")

	tank.drain()
	await runner.simulate_frames(1)

	assert_str(_text(runner, "FuelAmount")).is_equal("0%")
	assert_str(_text(runner, "StateLabel")).is_equal("Out of fuel: refuel here")


func _text(runner: GdUnitSceneRunner, label: String) -> String:
	return (runner.find_child(label) as Label).text


func test_the_preview_shows_the_bus_travelling_with_three_of_eight_seats() -> void:
	var runner := scene_runner("res://test/previews/bus_control_panel_preview.tscn")
	await runner.simulate_frames(10)
	assert_str(_text(runner, "StateLabel")).is_equal("Travelling to Terra")
	assert_str(_text(runner, "SeatLabel")).is_equal("3/8 seats")
	assert_str(_text(runner, "ButtonLabel")).is_equal("Emergency stop")
