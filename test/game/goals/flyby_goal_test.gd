extends GdUnitTestSuite
## A flyby quest, told where the bus is: it completes when the bus comes back within reach
## of the planet in flight with the passenger on board, and fails when they leave first.

var _planet: Planet
var _passenger: Passenger
var _goal: FlybyGoal
var _near: Vector3
var _far: Vector3


func before_test() -> void:
	_planet = auto_free(Planet.new())
	_planet.orbit_period = 0.0
	add_child(_planet)
	_planet.set_process(false)
	_passenger = Passenger.new(PassengerType.new(), _planet, 100.0, 40.0)
	_goal = FlybyGoal.new(_passenger, _planet)
	var centre := _planet.get_body_global_position()
	var surface := _planet.get_body_radius()
	_near = centre + Vector3.RIGHT * (surface + _goal.reach * 0.5)
	_far = centre + Vector3.RIGHT * (surface + _goal.reach * 4.0)


func test_coming_back_in_flight_with_them_on_board_completes_it() -> void:
	# They board where the bus is near, so leaving isn't a flyby.
	_goal.bus_moved(_near, [_passenger], true)
	assert_bool(_goal.is_active()).is_true()
	_goal.bus_moved(_far, [_passenger], true)
	assert_bool(_goal.is_active()).is_true()

	_goal.bus_moved(_near, [_passenger], true)

	assert_int(_goal.state).is_equal(Goal.State.COMPLETED)


func test_sitting_docked_near_the_planet_is_no_flyby() -> void:
	_goal.bus_moved(_far, [_passenger], true)

	_goal.bus_moved(_near, [_passenger], false)

	assert_bool(_goal.is_active()).is_true()


func test_coming_near_without_them_on_board_counts_for_nothing() -> void:
	_goal.bus_moved(_far, [], true)
	_goal.bus_moved(_near, [], true)

	assert_bool(_goal.is_active()).is_true()


func test_leaving_the_bus_before_the_flyby_fails_it_however_they_leave() -> void:
	_goal.bus_moved(_far, [_passenger], true)
	_goal.bus_moved(_far, [], true)
	assert_int(_goal.state).is_equal(Goal.State.FAILED)

	var delivered := FlybyGoal.new(_passenger, _planet)
	delivered.passenger_delivered(_passenger)
	assert_int(delivered.state).is_equal(Goal.State.FAILED)

	var kicked := FlybyGoal.new(_passenger, _planet)
	kicked.passenger_kicked(_passenger)
	assert_int(kicked.state).is_equal(Goal.State.FAILED)
