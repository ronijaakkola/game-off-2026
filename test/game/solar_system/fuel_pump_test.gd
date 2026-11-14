extends GdUnitTestSuite
## The fuel pump, run from the solar system: holding the dock panel's fuel button at the
## planet the bus is docked at.

const SCENE := "res://game/solar_system/solar_system.tscn"


func test_the_pump_sound_plays_while_the_button_is_held_and_stops_after_it_is_let_go() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var system := runner.scene() as SolarSystem
	var bus := runner.find_child("Bus") as FrameshiftBus
	var tank := bus.get_fuel_tank()
	tank.fuel = tank.capacity * 0.2
	system.get_ledger().credits = 100
	await await_millis(500)
	var player := (
		runner.find_child("FuelPump").find_children("*", "AudioStreamPlayer", false, false)[0]
		as AudioStreamPlayer
	)
	var camera := runner.find_child("Camera") as Camera3D
	var button := runner.find_child("FuelButton") as Button
	var at := _to_window(camera, button.get_global_rect().get_center())
	assert_bool(player.playing).is_false()

	_send_click(MOUSE_BUTTON_LEFT, at)
	await runner.simulate_frames(10, 30)
	assert_bool(player.playing).is_true()
	var early_pitch := player.pitch_scale
	assert_float(early_pitch).is_greater_equal(0.6)
	# The pitch keeps rising the longer the pump runs.
	await runner.simulate_frames(20, 30)
	assert_float(player.pitch_scale).is_greater(early_pitch)

	_send_release(MOUSE_BUTTON_LEFT, at)
	await runner.simulate_frames(20, 30)
	assert_bool(player.playing).is_false()


func test_the_fuel_button_is_off_without_credits() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var button := runner.find_child("FuelButton") as Button
	bus.get_fuel_tank().fuel = 10.0
	var ledger := (runner.scene() as SolarSystem).get_ledger()

	ledger.credits = 0
	await runner.simulate_frames(2)
	assert_bool(button.disabled).is_true()
	ledger.credits = 100
	await runner.simulate_frames(2)
	assert_bool(button.disabled).is_false()


func test_holding_fuel_in_the_dock_panel_buys_fuel_until_let_go() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var tank := bus.get_fuel_tank()
	tank.fuel = tank.capacity * 0.5
	var ledger := (runner.scene() as SolarSystem).get_ledger()
	ledger.credits = 100
	await await_millis(500)
	var button := runner.find_child("FuelButton") as FuelButton
	var label := button.find_child("Label") as Label
	assert_bool(button.is_visible_in_tree()).is_true()
	var cost := ceili(tank.capacity * 0.5 * bus.get_docked_planet().fuel_price)
	assert_str(label.text).is_equal("Hold to fuel (%d credits)" % cost)
	assert_float(button.get_fill()).is_equal_approx(0.5, 0.01)
	var camera := runner.find_child("Camera") as Camera3D
	var at := _to_window(camera, button.get_global_rect().get_center())

	_send_click(MOUSE_BUTTON_LEFT, at)
	await runner.simulate_frames(30, 30)
	# The label shows the fuel while held, at most a morph behind it, and the bill waits.
	assert_str(label.text).ends_with("%")
	assert_int(ledger.credits).is_equal(100)
	_send_release(MOUSE_BUTTON_LEFT, at)
	await runner.simulate_frames(2)

	var bought := tank.fuel - tank.capacity * 0.5
	assert_float(bought).is_greater(5.0)
	assert_int(ledger.credits).is_less(100)
	var held_to := tank.fuel
	await runner.simulate_frames(20, 30)
	assert_float(tank.fuel).is_equal(held_to)
	assert_str(label.text).starts_with("Hold to fuel (")
	assert_float(button.get_fill()).is_equal_approx(tank.get_fraction(), 0.01)
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
	assert_bool(button.is_visible_in_tree()).is_false()
	assert_bool((runner.find_child("FuelRule") as Control).visible).is_false()


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
