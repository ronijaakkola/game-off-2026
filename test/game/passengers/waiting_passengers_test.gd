extends GdUnitTestSuite
## Who waits where, through WaitingPassengers' public calls.

var _waiting: WaitingPassengers
var _home: Planet
var _away: Planet


func before_test() -> void:
	var space := auto_free(Node3D.new()) as Node3D
	add_child(space)
	_home = Planet.new()
	_away = Planet.new()
	space.add_child(_home)
	space.add_child(_away)
	_waiting = auto_free(WaitingPassengers.new())
	_waiting.types = [PassengerType.new()]
	_waiting.min_interval = 0.02
	_waiting.max_interval = 0.02
	_waiting.max_per_planet = 2
	add_child(_waiting)
	_waiting.set_planets([_home, _away])


func test_passengers_turn_up_over_time_up_to_the_limit() -> void:
	assert_int(_waiting.count_at(_home)).is_equal(0)
	await await_millis(300)
	assert_int(_waiting.count_at(_home)).is_equal(2)


func test_take_hands_over_at_most_the_count_asked_for() -> void:
	_waiting.add(_home)
	_waiting.add(_home)
	var taken := _waiting.take(_home, 1)
	assert_int(taken.size()).is_equal(1)
	assert_int(_waiting.count_at(_home)).is_equal(1)
	assert_int(_waiting.take(_home, 4).size()).is_equal(1)
	assert_int(_waiting.count_at(_home)).is_equal(0)


func test_a_passenger_goes_to_another_planet() -> void:
	for i: int in 10:
		var passenger := _waiting.create(_home)
		assert_object(passenger.destination).is_same(_away)
		assert_object(passenger.origin).is_same(_home)
