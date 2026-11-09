extends GdUnitTestSuite
## The bus status panel in the solar system: it says what the bus is doing and how many
## seats are taken and how much fuel is left, and its button cancels the course.

const SCENE := "res://game/solar_system/solar_system.tscn"

var _window_size: Vector2i


func before() -> void:
	# Headless, the window is 64×64, and the canvas_items stretch would scale every
	# simulated click. At the base size it scales by 1.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)


func after() -> void:
	get_tree().root.size = _window_size


func test_cancel_while_charging_keeps_the_bus_docked() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	bus.plot_course(RouteStop.at_planet(runner.find_child("Terra") as Planet))
	await runner.simulate_frames(2)
	assert_str(_text(runner, "StateLabel")).is_equal("Charging frameshift")
	assert_str(_text(runner, "ToLabel")).is_equal("Terra")
	var button := runner.find_child("CancelButton") as Button
	assert_bool(button.visible).is_true()

	runner.set_mouse_position(button.get_global_rect().get_center())
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	await runner.simulate_frames(1)

	assert_int(bus.state).is_equal(FrameshiftBus.State.DOCKED)
	assert_str(_text(runner, "StateLabel")).is_equal("Docked")
	assert_bool(button.visible).is_false()


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
	var runner := scene_runner("res://test/previews/bus_status_panel_preview.tscn")
	await runner.simulate_frames(10)
	assert_str(_text(runner, "StateLabel")).is_equal("Travelling to Terra")
	assert_str(_text(runner, "SeatLabel")).is_equal("3/8 seats")
	assert_bool((runner.find_child("CancelButton") as Button).visible).is_true()
