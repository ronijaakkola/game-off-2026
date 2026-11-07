extends GdUnitTestSuite
## The bus's route rules, driven frame by frame with a fixed step on still planets, so
## each test is quick and doesn't depend on the machine's speed.

const BUS := "res://game/bus/bus.tscn"
const STEP := 0.05
# Long enough for any trip in these tests.
const MAX_STEPS := 2000

var _bus: FrameshiftBus
var _home: Planet
var _near: Planet
var _far: Planet
var _reduce_motion: bool


func before_test() -> void:
	_reduce_motion = Settings.reduce_motion
	Settings.reduce_motion = true
	var space := auto_free(Node3D.new()) as Node3D
	add_child(space)
	_home = _planet(space, Vector3(0.0, 0.0, 0.0))
	_near = _planet(space, Vector3(6.0, 0.0, 0.0))
	_far = _planet(space, Vector3(6.0, 0.0, 6.0))
	_bus = (load(BUS) as PackedScene).instantiate() as FrameshiftBus
	_bus.start_planet = _home
	space.add_child(_bus)
	# The test steps the bus itself.
	_bus.set_process(false)


func after_test() -> void:
	# Assigning re-saves the developer's own settings file with their value.
	Settings.reduce_motion = _reduce_motion


func test_a_course_from_a_planet_charges_then_flies_and_docks() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(_bus.charge_time - 0.5)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.CHARGING)
	assert_object(_bus.get_docked_planet()).is_same(_home)
	_step_for(1.0)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.FLYING)
	assert_object(_bus.get_docked_planet()).is_null()
	assert_bool(_step_until_docked()).is_true()
	assert_object(_bus.get_docked_planet()).is_same(_near)
	assert_array(_bus.get_route_planets()).is_empty()


func test_each_planet_on_the_route_docks_and_charges_again() -> void:
	var docked_at: Array[Planet] = []
	_bus.docked.connect(func(planet: Planet) -> void: docked_at.append(planet))
	_bus.plot_course(RouteStop.at_planet(_near))
	_bus.plot_course(RouteStop.at_planet(_far), true)
	assert_array(_bus.get_route_planets()).contains_exactly([_near, _far])
	_step_for(_bus.charge_time + STEP)
	assert_bool(_step_until(FrameshiftBus.State.CHARGING)).is_true()
	assert_object(_bus.get_docked_planet()).is_same(_near)
	assert_array(_bus.get_route_planets()).contains_exactly([_far])
	assert_bool(_step_until_docked()).is_true()
	assert_object(_bus.get_docked_planet()).is_same(_far)
	assert_array(docked_at).contains_exactly([_near, _far])


func test_a_course_set_while_boarding_charges_once_boarding_is_done() -> void:
	_bus.boarding = true
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(_bus.charge_time + 1.0)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.DOCKED)
	assert_array(_bus.get_route_planets()).contains_exactly([_near])

	_bus.boarding = false

	assert_int(_bus.state).is_equal(FrameshiftBus.State.CHARGING)


func test_boarding_set_on_docking_holds_the_charge_to_the_next_stop() -> void:
	_bus.docked.connect(func(_planet: Planet) -> void: _bus.boarding = true)
	_bus.plot_course(RouteStop.at_planet(_near))
	_bus.plot_course(RouteStop.at_planet(_far), true)
	assert_bool(_step_until_docked()).is_true()
	assert_object(_bus.get_docked_planet()).is_same(_near)
	_step_for(_bus.charge_time + 1.0)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.DOCKED)

	_bus.boarding = false

	assert_int(_bus.state).is_equal(FrameshiftBus.State.CHARGING)


func test_removing_the_last_stop_keeps_the_rest() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	_bus.plot_course(RouteStop.at_planet(_far), true)
	_bus.remove_last_stop()
	assert_array(_bus.get_route_planets()).contains_exactly([_near])
	assert_int(_bus.state).is_equal(FrameshiftBus.State.CHARGING)


func test_removing_the_only_stop_stops_the_charge() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	_bus.remove_last_stop()
	assert_object(_bus.get_last_stop()).is_null()
	assert_int(_bus.state).is_equal(FrameshiftBus.State.DOCKED)


func test_a_point_in_space_ends_the_route_holding_there() -> void:
	var point := Vector3(-4.0, 0.0, 3.0)
	_bus.plot_course(RouteStop.at_point(Vector3(-2.0, 0.0, 4.0)))
	_bus.plot_course(RouteStop.at_point(point), true)
	_step_for(_bus.charge_time + STEP)
	assert_bool(_step_until(FrameshiftBus.State.HOLDING)).is_true()
	assert_vector(_bus.global_position).is_equal_approx(point, Vector3.ONE * 0.1)


func test_a_course_from_space_leaves_without_charging() -> void:
	_bus.plot_course(RouteStop.at_point(Vector3(-3.0, 0.0, 0.0)))
	_step_for(_bus.charge_time + STEP)
	assert_bool(_step_until(FrameshiftBus.State.HOLDING)).is_true()
	_bus.plot_course(RouteStop.at_planet(_near))
	assert_int(_bus.state).is_equal(FrameshiftBus.State.FLYING)


func test_cancel_while_charging_stays_docked() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(1.0)
	_bus.cancel_course()
	_step_for(_bus.charge_time)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.DOCKED)
	assert_object(_bus.get_docked_planet()).is_same(_home)


func test_cancel_while_flying_slows_to_a_stop_in_space() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(_bus.charge_time + 2.0)
	_bus.cancel_course()
	assert_bool(_step_until(FrameshiftBus.State.HOLDING)).is_true()
	assert_object(_bus.get_docked_planet()).is_null()


func test_a_course_to_the_docked_planet_cancels() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	_bus.plot_course(RouteStop.at_planet(_home))
	assert_int(_bus.state).is_equal(FrameshiftBus.State.DOCKED)
	assert_array(_bus.get_route_planets()).is_empty()


func test_the_time_estimate_matches_a_trip_to_a_still_planet() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	var estimate := _bus.estimate_time_to_next_planet()
	var took := 0.0
	for i: int in MAX_STEPS:
		_bus._process(STEP)
		took += STEP
		if _bus.state == FrameshiftBus.State.DOCKED:
			break
	assert_object(_bus.get_docked_planet()).is_same(_near)
	assert_float(estimate).is_between(took * 0.9, took * 1.1)


func test_the_next_planet_skips_points_in_space() -> void:
	_bus.plot_course(RouteStop.at_point(Vector3(3.0, 0.0, 3.0)))
	assert_object(_bus.get_next_planet()).is_null()
	assert_float(_bus.estimate_time_to_next_planet()).is_equal(-1.0)
	_bus.plot_course(RouteStop.at_planet(_far), true)
	assert_object(_bus.get_next_planet()).is_same(_far)
	assert_float(_bus.estimate_time_to_next_planet()).is_greater(_bus.charge_time)


func test_docking_is_only_the_end_of_the_flight() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(_bus.charge_time + 1.0)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.FLYING)
	assert_bool(_bus.is_docking()).is_false()
	var docking_seen := false
	for i: int in MAX_STEPS:
		_bus._process(STEP)
		if _bus.state == FrameshiftBus.State.DOCKED:
			break
		docking_seen = docking_seen or _bus.is_docking()
	assert_bool(docking_seen).is_true()
	assert_bool(_bus.is_docking()).is_false()


func test_a_cancelled_flight_is_stopping_until_it_holds() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(_bus.charge_time + 2.0)
	assert_bool(_bus.is_stopping()).is_false()
	_bus.cancel_course()
	assert_bool(_bus.is_stopping()).is_true()
	assert_bool(_step_until(FrameshiftBus.State.HOLDING)).is_true()
	assert_bool(_bus.is_stopping()).is_false()


# A planet that stays where it is put.
func _planet(parent: Node3D, at: Vector3) -> Planet:
	var planet := Planet.new()
	planet.orbit_radius = 0.0
	planet.orbit_period = 0.0
	planet.show_orbit = false
	planet.position = at
	parent.add_child(planet)
	return planet


func _step_for(seconds: float) -> void:
	for i: int in roundi(seconds / STEP):
		_bus._process(STEP)


func _step_until(state: FrameshiftBus.State) -> bool:
	for i: int in MAX_STEPS:
		_bus._process(STEP)
		if _bus.state == state:
			return true
	return false


func _step_until_docked() -> bool:
	return _step_until(FrameshiftBus.State.DOCKED)
