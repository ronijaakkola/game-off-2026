extends GdUnitTestSuite
## The fuel forecast over the route's last stop: the fuel the course burns, shown only
## while the bus has the fuel forecast trait, and red when the bus hasn't that much left.

const BUS := "res://game/bus/bus.tscn"
const SCENE := "res://game/solar_system/solar_system.tscn"


func test_the_estimate_is_the_distance_to_each_stop_short_of_parking_times_the_burn() -> void:
	var bus := auto_free((load(BUS) as PackedScene).instantiate()) as FrameshiftBus
	add_child(bus)
	var start := bus.global_position
	var planet := auto_free(Planet.new()) as Planet
	planet.orbit_radius = 0.0
	planet.orbit_period = 0.0
	planet.show_orbit = false
	add_child(planet)
	# Where the bus starts to park at it, 3 past the checkpoint.
	var park := planet.get_body_radius() + bus.dock_gap + FrameshiftBus.DOCK_DISTANCE
	planet.position = start + Vector3(4.0, 0.0, 3.0 + park)
	bus.plot_course(RouteStop.at_planet(planet))
	bus.plot_course(RouteStop.at_point(start + Vector3(4.0, 0.0, 0.0)), true)

	var burn := bus.get_fuel_tank().burn_per_unit
	assert_float(FuelForecast.estimate(bus)).is_equal_approx(7.0 * burn, 0.001)


func test_shows_over_the_last_stop_only_while_the_bus_has_the_trait() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var label := (runner.find_child("FuelForecast") as Node).find_child("Label") as Label
	var terra := runner.find_child("Terra") as Planet
	bus.plot_course(RouteStop.at_planet(terra))
	await runner.simulate_frames(1)
	assert_bool(label.visible).is_false()

	bus.get_stats().get_traits().add(BusTraits.Type.FUEL_FORECAST)
	await runner.simulate_frames(1)

	assert_bool(label.visible).is_true()
	var percent := roundi(FuelForecast.estimate(bus) / bus.get_fuel_tank().capacity * 100.0)
	assert_str(label.text).is_equal("-%d%% fuel" % percent)
	assert_object(label.get_theme_color(&"font_color")).is_equal(FuelForecast.COLOR)
	# Above Terra on screen.
	var camera := runner.find_child("Camera") as Camera3D
	var center := camera.unproject_position(terra.get_body_global_position())
	assert_float(label.get_global_rect().get_center().x).is_equal_approx(center.x, 2.0)
	assert_float(label.get_global_rect().end.y).is_less(center.y)

	bus.cancel_course()
	await runner.simulate_frames(1)
	assert_bool(label.visible).is_false()


func test_turns_red_when_the_course_burns_more_than_the_fuel_left() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var label := (runner.find_child("FuelForecast") as Node).find_child("Label") as Label
	bus.get_stats().get_traits().add(BusTraits.Type.FUEL_FORECAST)
	bus.plot_course(RouteStop.at_planet(runner.find_child("Terra") as Planet))
	bus.get_fuel_tank().fuel = 1.0
	await runner.simulate_frames(1)

	assert_object(label.get_theme_color(&"font_color")).is_equal(FuelForecast.SHORT_COLOR)
