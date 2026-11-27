extends GdUnitTestSuite
## The star chart: opening pulls the camera back until the planets are gone and the bus sits
## beside its star, and closing puts the map back as it was.

const SCENE := "res://game/solar_system/solar_system.tscn"


func test_opening_leaves_the_stars_with_the_bus_beside_its_own() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(3)
	var chart := runner.find_child("StarChart") as StarChart
	var rig := runner.find_child("CameraRig") as CameraRig
	var bus := runner.find_child("Bus") as FrameshiftBus
	var planet := bus.get_docked_planet()
	var star_map := runner.find_child("StarMap") as StarMap
	var star := star_map.get_nearest_system(bus.global_position).global_position

	chart.open()
	await await_signal_on(chart, "opened", [], 4000)

	assert_bool(chart.is_open()).is_true()
	assert_bool(rig.locked).is_true()
	assert_float(rig.distance).is_equal_approx(chart.chart_distance, 0.01)
	assert_float(planet.body_scale).is_less(0.01)
	var sky := runner.find_child("SpaceSky") as SpaceSky
	assert_bool(sky.background_color.is_equal_approx(chart.background_color)).is_true()
	assert_float(chart.get_orbit_share()).is_equal(0.0)
	var model := bus.get_model()
	var beside := model.global_position.distance_to(star)
	assert_float(beside).is_equal_approx(chart.bus_star_distance, 0.01)
	# The bus's own animation leaves the model where the chart put it.
	await runner.simulate_frames(30)
	assert_float(model.global_position.distance_to(star)).is_equal_approx(beside, 0.01)
	# The HUD stays, without the planet's dock panel.
	assert_bool((runner.find_child("GoalPanel") as Control).visible).is_true()
	assert_bool((runner.find_child("PassengerPanel") as Control).visible).is_true()
	assert_object((runner.find_child("DockPanel") as DockPanel).planet).is_null()


func test_closing_puts_the_map_back() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(3)
	var chart := runner.find_child("StarChart") as StarChart
	var rig := runner.find_child("CameraRig") as CameraRig
	var sky := runner.find_child("SpaceSky") as SpaceSky
	var bus := runner.find_child("Bus") as FrameshiftBus
	var planet := bus.get_docked_planet()
	var place := rig.position
	var distance := rig.distance
	var color := sky.background_color
	chart.open()
	await await_signal_on(chart, "opened", [], 4000)

	chart.close()
	await await_signal_on(chart, "closed", [], 4000)
	await runner.simulate_frames(3)

	assert_bool(chart.is_open()).is_false()
	assert_bool(rig.locked).is_false()
	assert_vector(rig.position).is_equal_approx(place, Vector3.ONE * 0.01)
	assert_float(rig.distance).is_equal_approx(distance, 0.01)
	assert_bool(sky.background_color.is_equal_approx(color)).is_true()
	assert_float(planet.body_scale).is_equal(1.0)
	assert_float(chart.get_orbit_share()).is_equal(1.0)
	var model := bus.get_model()
	assert_float(model.global_position.distance_to(bus.global_position)).is_less(3.0)
	assert_vector(model.scale).is_equal(Vector3.ONE)
	assert_object((runner.find_child("DockPanel") as DockPanel).planet).is_same(planet)


func test_opening_closes_the_open_planet() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(3)
	var system := runner.scene() as SolarSystem
	var bus := runner.find_child("Bus") as FrameshiftBus
	system.open_planet(bus.get_docked_planet())
	var chart := runner.find_child("StarChart") as StarChart

	chart.open()
	await await_signal_on(chart, "opened", [], 4000)

	assert_object(system.get_open_planet()).is_null()
	assert_bool((runner.find_child("CameraRig") as CameraRig).is_focused()).is_false()
	assert_bool((runner.find_child("PlanetPanel") as Control).visible).is_false()
