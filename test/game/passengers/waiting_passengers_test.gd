extends GdUnitTestSuite
## Who waits where, through WaitingPassengers' public calls.

const BUS_SCENE := preload("res://game/bus/bus.tscn")

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


func test_nobody_new_turns_up_where_the_bus_waits() -> void:
	var bus := BUS_SCENE.instantiate() as FrameshiftBus
	bus.start_planet = _home
	(_home.get_parent() as Node).add_child(bus)
	bus.set_process(false)
	_waiting.bus = bus

	await await_millis(300)

	assert_int(_waiting.count_at(_home)).is_equal(0)
	assert_int(_waiting.count_at(_away)).is_equal(2)


func test_the_game_starts_with_more_waiting_where_the_bus_is() -> void:
	_waiting.starting_at_bus = 2
	_waiting.starting_per_planet = 1

	_waiting.add_starting_passengers(_home)

	assert_int(_waiting.count_at(_home)).is_equal(2)
	assert_int(_waiting.count_at(_away)).is_equal(1)


func test_take_removes_only_that_passenger_from_the_line() -> void:
	_waiting.add(_home)
	_waiting.add(_home)
	var line := _waiting.get_waiting(_home)

	assert_bool(_waiting.take(_home, line[1])).is_true()

	assert_array(_waiting.get_waiting(_home)).contains_exactly([line[0]])
	assert_bool(_waiting.take(_home, line[1])).is_false()
	assert_bool(_waiting.take(_away, line[0])).is_false()


func test_a_passenger_goes_to_another_planet() -> void:
	for i: int in 10:
		var passenger := _waiting.create(_home)
		assert_object(passenger.destination).is_same(_away)
		assert_object(passenger.origin).is_same(_home)


func test_someone_waiting_is_decided_only_when_the_line_is_seen() -> void:
	_waiting.add(_home)
	var later := PassengerType.new()
	_waiting.types = [later]

	assert_int(_waiting.count_at(_home)).is_equal(1)
	var line := _waiting.get_waiting(_home)

	assert_object(line[0].type).is_same(later)
	assert_array(_waiting.get_waiting(_home)).contains_exactly(line)


func test_a_line_holds_at_most_two_going_to_one_planet() -> void:
	var third := _planet()
	_waiting.max_per_planet = 4
	for i: int in 50:
		_waiting.set_planets([_home, _away, third])
		for j: int in 4:
			_waiting.add(_home)
		var going: Dictionary[Planet, int] = {}
		for passenger: Passenger in _waiting.get_waiting(_home):
			going[passenger.destination] = going.get(passenger.destination, 0) + 1
		for planet: Planet in going:
			assert_int(going[planet]).is_less_equal(WaitingPassengers.MAX_SAME_DESTINATION)


func test_destinations_lean_toward_where_those_on_board_are_going() -> void:
	var third := _planet()
	_waiting.set_planets([_home, _away, third])
	var cabin := auto_free(Cabin.new()) as Cabin
	add_child(cabin)
	cabin.board(Passenger.new(PassengerType.new(), _away, 100.0, 40.0))
	_waiting.cabin = cabin
	var going: Dictionary[Planet, int] = {_away: 0, third: 0}

	for i: int in 300:
		going[_waiting.create(_home).destination] += 1

	assert_int(going[_away]).is_greater(going[third] * 3 / 2)
	assert_int(going[third]).is_greater(0)


func test_races_are_dealt_evenly_from_a_bag() -> void:
	var races: Dictionary[Race.Type, int] = {}
	var bag := Race.Type.size() * WaitingPassengers.RACE_BAG_COPIES

	for i: int in bag:
		var race := _waiting.create(_home).race
		races[race] = races.get(race, 0) + 1

	for value: int in Race.Type.values():
		assert_int(races.get(value as Race.Type, 0)).is_equal(WaitingPassengers.RACE_BAG_COPIES)


func test_business_passengers_turn_up_more_often_with_a_better_recent_rating() -> void:
	_waiting.business = PassengerType.new()
	_waiting.ledger = Ledger.new()
	var low := _count_business(300)
	for i: int in Ledger.RECENT_RATINGS:
		_waiting.ledger.rate(Passenger.MAX_STARS)

	var high := _count_business(300)

	assert_int(high).is_greater(low * 3)


func test_a_line_holds_no_more_business_than_its_band_allows_and_room_for_someone_else() -> void:
	_waiting.business = PassengerType.new()
	_waiting.ledger = Ledger.new()
	for i: int in Ledger.RECENT_RATINGS:
		_waiting.ledger.rate(Passenger.MAX_STARS)
	var band := RatingBand.of(Passenger.MAX_STARS)
	for size: int in [2, 3]:
		_waiting.max_per_planet = size
		var limit := mini(RatingBand.BUSINESS_PER_LINE[band], size - 1)
		for i: int in 60:
			_waiting.set_planets([_home, _away])
			for j: int in size:
				_waiting.add(_home)
			var line := _waiting.get_waiting(_home)
			var business := line.filter(
				func(p: Passenger) -> bool: return p.type == _waiting.business
			)
			assert_int(business.size()).is_less_equal(limit)


func test_the_longest_waiting_leaves_once_the_line_is_seen_and_left_alone() -> void:
	_quiet()
	_waiting.add(_home)
	_waiting.add(_home)
	_run(_waiting.leave_seconds * 2.0)
	assert_int(_waiting.count_at(_home)).override_failure_message("left unseen").is_equal(2)
	var line := _waiting.get_waiting(_home)

	_run(_waiting.leave_seconds - 1.0)
	assert_int(_waiting.count_at(_home)).is_equal(2)
	_run(2.0)

	assert_array(_waiting.get_waiting(_home)).contains_exactly([line[1]])
	# The next one's clock starts afresh, from the step after the first left.
	_run(_waiting.leave_seconds - 2.0)
	assert_int(_waiting.count_at(_home)).is_equal(1)


func test_nobody_leaves_where_the_bus_waits() -> void:
	_quiet()
	var bus := BUS_SCENE.instantiate() as FrameshiftBus
	bus.start_planet = _home
	(_home.get_parent() as Node).add_child(bus)
	bus.set_process(false)
	_waiting.bus = bus
	_waiting.add(_home)
	_waiting.get_waiting(_home)

	_run(_waiting.leave_seconds * 2.0)

	assert_int(_waiting.count_at(_home)).is_equal(1)


func _planet() -> Planet:
	var planet := Planet.new()
	(_home.get_parent() as Node).add_child(planet)
	return planet


# Nobody new turns up during the test, and the clocks run only by [method _run].
func _quiet() -> void:
	_waiting.set_process(false)
	_waiting.min_interval = 300.0
	_waiting.max_interval = 300.0
	_waiting.leave_seconds = 10.0
	_waiting.set_planets([_home, _away])


func _run(seconds: float) -> void:
	for i: int in roundi(seconds):
		_waiting._process(1.0)


func _count_business(created: int) -> int:
	var count := 0
	for i: int in created:
		if _waiting.create(_home).type == _waiting.business:
			count += 1
	return count
