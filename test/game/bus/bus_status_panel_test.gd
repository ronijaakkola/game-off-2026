extends GdUnitTestSuite
## The bus status panel in the solar system: it says what the bus is doing and how much
## fuel is left, and holding its Frameshift key charges the drive.

const SCENE := "res://game/solar_system/solar_system.tscn"

var _window_size: Vector2i


func before() -> void:
	# Headless, the window is 64×64, and the canvas_items stretch would scale every
	# simulated click. At the base size it scales by 1.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)


func after() -> void:
	get_tree().root.size = _window_size


func test_holding_the_key_charges_and_letting_go_drains_and_keeps_the_course() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var terra := runner.find_child("Terra") as Planet
	var key := runner.find_child("FrameshiftKey") as FrameshiftKey
	assert_bool(key.disabled).is_true()
	bus.plot_course(RouteStop.at_planet(terra))
	await runner.simulate_frames(2)
	assert_int(bus.state).is_equal(FrameshiftBus.State.DOCKED)
	assert_str(_text(runner, "StateLabel")).is_equal("Hold Frameshift to leave")
	assert_bool(key.disabled).is_false()
	assert_float(key.charge).is_equal(0.0)

	runner.set_mouse_position(key.get_global_rect().get_center())
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	await runner.simulate_frames(5)

	assert_int(bus.state).is_equal(FrameshiftBus.State.CHARGING)
	assert_str(_text(runner, "StateLabel")).is_equal("Charging frameshift")
	assert_str(_text(runner, "ToLabel")).is_equal("Terra")
	assert_float(key.charge).is_greater(0.0)

	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	await assert_func(bus, "get_charge_progress").wait_until(2000).is_equal(0.0)
	await runner.simulate_frames(1)

	assert_int(bus.state).is_equal(FrameshiftBus.State.DOCKED)
	assert_float(key.charge).is_equal(0.0)
	assert_array(bus.get_route_planets()).contains_exactly([terra])
	assert_bool(key.disabled).is_false()


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


func test_the_preview_shows_the_bus_travelling_with_three_of_eight_seats_taken() -> void:
	var runner := scene_runner("res://test/previews/bus_status_panel_preview.tscn")
	await runner.simulate_frames(10)
	assert_str(_text(runner, "StateLabel")).is_equal("Travelling to Terra")
	assert_str(_text(runner, "SeatLabel")).is_equal("3/8")
	var key := runner.find_child("FrameshiftKey") as FrameshiftKey
	assert_bool(key.disabled).is_false()
	assert_bool(key.stop).is_true()
