extends GdUnitTestSuite
## The fuel pump, run from the solar system: holding the dock panel's fuel button, or the
## open planet's refuel button, at the planet the bus is docked at.

const SCENE := "res://game/solar_system/solar_system.tscn"


func test_holding_refuel_at_the_docked_planet_buys_fuel_until_let_go() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var system := runner.scene() as SolarSystem
	var bus := runner.find_child("Bus") as FrameshiftBus
	var ember := bus.get_docked_planet()
	var tank := bus.get_fuel_tank()
	tank.fuel = tank.capacity * 0.5
	var counter := runner.find_child("CreditsCounter") as CreditsCounter
	counter.credits = 100
	system.open_planet(ember)
	await await_millis(500)
	var camera := runner.find_child("Camera") as Camera3D
	var button := runner.find_child("RefuelButton") as Button
	var at := _to_window(camera, button.get_global_rect().get_center())

	_send_click(MOUSE_BUTTON_LEFT, at)
	await runner.simulate_frames(30, 30)
	_send_release(MOUSE_BUTTON_LEFT, at)
	await runner.simulate_frames(1)

	var bought := tank.fuel - tank.capacity * 0.5
	assert_float(bought).is_greater(5.0)
	assert_float(tank.fuel).is_less(tank.capacity)
	# Whole credits go as they add up; the rest waits for the next drop.
	assert_int(counter.credits).is_equal(100 - floori(bought * ember.fuel_price))
	var held_to := tank.fuel
	await runner.simulate_frames(20, 30)
	assert_float(tank.fuel).is_equal(held_to)


func test_refuel_is_off_away_from_the_docked_planet_without_credits_or_with_a_full_tank() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var system := runner.scene() as SolarSystem
	var bus := runner.find_child("Bus") as FrameshiftBus
	var button := runner.find_child("RefuelButton") as Button
	var note := runner.find_child("FuelNote") as Label
	bus.get_fuel_tank().fuel = 10.0

	system.open_planet(runner.find_child("Terra") as Planet)
	await runner.simulate_frames(2)
	assert_bool(button.disabled).is_true()
	assert_str(note.text).is_equal("Dock here to refuel.")

	var counter := runner.find_child("CreditsCounter") as CreditsCounter
	counter.credits = 0
	system.open_planet(bus.get_docked_planet())
	await runner.simulate_frames(2)
	assert_bool(button.disabled).is_true()
	assert_str(note.text).is_equal("Not enough credits.")
	counter.credits = 100
	await runner.simulate_frames(2)
	assert_bool(button.disabled).is_false()
	bus.get_fuel_tank().fill()
	await runner.simulate_frames(2)
	assert_bool(button.disabled).is_true()
	assert_str(note.text).is_equal("Tank full.")


func test_holding_fuel_in_the_dock_panel_buys_fuel_until_let_go() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var tank := bus.get_fuel_tank()
	tank.fuel = tank.capacity * 0.5
	var counter := runner.find_child("CreditsCounter") as CreditsCounter
	counter.credits = 100
	await await_millis(500)
	var button := runner.find_child("FuelButton") as Button
	var label := button.find_child("Label") as Label
	var fill := button.find_child("Fill") as Control
	assert_bool(button.is_visible_in_tree()).is_true()
	var cost := ceili(tank.capacity * 0.5 * bus.get_docked_planet().fuel_price)
	assert_str(label.text).is_equal("Hold to fuel (%d cr)" % cost)
	assert_float(fill.size.x).is_equal_approx(button.size.x * 0.5, 1.0)
	var camera := runner.find_child("Camera") as Camera3D
	var at := _to_window(camera, button.get_global_rect().get_center())

	_send_click(MOUSE_BUTTON_LEFT, at)
	await runner.simulate_frames(30, 30)
	# The label shows the fuel while held, at most a morph behind it.
	assert_str(label.text).ends_with("%")
	_send_release(MOUSE_BUTTON_LEFT, at)
	await runner.simulate_frames(1)

	var bought := tank.fuel - tank.capacity * 0.5
	assert_float(bought).is_greater(5.0)
	assert_int(counter.credits).is_less(100)
	var held_to := tank.fuel
	await runner.simulate_frames(20, 30)
	assert_float(tank.fuel).is_equal(held_to)
	assert_str(label.text).starts_with("Hold to fuel (")
	assert_float(fill.size.x).is_equal_approx(button.size.x * tank.get_fraction(), 1.0)
	tank.fill()
	await runner.simulate_frames(2)
	assert_bool(button.disabled).is_true()
	assert_str(label.text).is_equal("Tank full")


func test_the_dock_panel_has_no_fuel_button_where_no_fuel_is_sold() -> void:
	var runner := scene_runner(SCENE)
	var bus := runner.find_child("Bus") as FrameshiftBus
	bus.get_docked_planet().sells_fuel = false
	await runner.simulate_frames(3)
	var button := runner.find_child("FuelButton") as Button
	assert_bool((runner.find_child("DockPanel") as Control).visible).is_true()
	assert_bool(button.visible).is_false()


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


func _send_release(button: MouseButton, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.global_position = at
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
