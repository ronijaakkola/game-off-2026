extends GdUnitTestSuite
## A hop quest, told where the bus is: it completes when the bus comes to rest at the hop
## location with the passenger on board, and fails when they leave the bus first.

const SPOT := Vector3(10.0, 0.0, -4.0)

var _passenger: Passenger
var _goal: HopGoal
var _inside: Vector3
var _outside: Vector3


func before_test() -> void:
	_passenger = Passenger.new(PassengerType.new(), null, 100.0, 0.0)
	_goal = HopGoal.new(_passenger, SPOT)
	_inside = SPOT + Vector3.RIGHT * _goal.radius * 0.5
	_outside = SPOT + Vector3.RIGHT * _goal.radius * 2.0


func test_coming_to_rest_at_the_hop_location_with_them_on_board_completes_it() -> void:
	_goal.bus_moved(_inside, [_passenger], true)
	_goal.bus_held(_inside, [_passenger])

	assert_int(_goal.state).is_equal(Goal.State.COMPLETED)


func test_flying_through_the_hop_location_is_no_stop() -> void:
	_goal.bus_moved(_outside, [_passenger], true)
	_goal.bus_moved(_inside, [_passenger], true)
	_goal.bus_moved(_outside, [_passenger], true)

	assert_bool(_goal.is_active()).is_true()


func test_coming_to_rest_outside_the_hop_location_counts_for_nothing() -> void:
	_goal.bus_held(_outside, [_passenger])

	assert_bool(_goal.is_active()).is_true()


func test_coming_to_rest_there_without_them_on_board_counts_for_nothing() -> void:
	_goal.bus_held(_inside, [])

	assert_bool(_goal.is_active()).is_true()


func test_leaving_the_bus_first_fails_it_however_they_leave() -> void:
	_goal.bus_moved(_outside, [_passenger], true)
	_goal.bus_moved(_outside, [], true)
	assert_int(_goal.state).is_equal(Goal.State.FAILED)

	var kicked := HopGoal.new(_passenger, SPOT)
	kicked.passenger_kicked(_passenger)
	assert_int(kicked.state).is_equal(Goal.State.FAILED)
