extends GdUnitTestSuite
## Boarding, picking up, amenities and getting off, through Cabin's public calls.

var _cabin: Cabin
var _home: Planet
var _away: Planet


func before_test() -> void:
	_cabin = auto_free(Cabin.new())
	add_child(_cabin)
	_home = auto_free(Planet.new())
	_away = auto_free(Planet.new())
	# In the tree, so a WaitingPassengers can measure the distance between them.
	add_child(_home)
	add_child(_away)


func test_boards_until_the_seats_are_full() -> void:
	_cabin.seats = 2
	assert_bool(_cabin.board(_passenger(_away))).is_true()
	assert_bool(_cabin.board(_passenger(_away))).is_true()
	assert_bool(_cabin.board(_passenger(_away))).is_false()
	assert_int(_cabin.get_passengers().size()).is_equal(2)


func test_the_ride_starts_when_the_bus_leaves() -> void:
	var passenger := _passenger(_away)
	_cabin.board(passenger)
	passenger.tick(10.0, true)
	assert_float(passenger.happiness).is_equal(Passenger.BASE_HAPPINESS)

	_cabin.docked = false
	passenger.tick(10.0, false)

	assert_float(passenger.happiness).is_greater(Passenger.BASE_HAPPINESS)


func test_boarding_on_the_frame_the_bus_arrives_still_holds_happiness() -> void:
	# On the frame the bus docks, docked is still false from before it moved.
	_cabin.docked = false
	var passenger := _passenger(_away)
	_cabin.board(passenger)
	passenger.tick(0.1, false)
	_cabin.docked = true
	passenger.tick(10.0, true)

	assert_float(passenger.happiness).is_equal(Passenger.BASE_HAPPINESS)


func test_happiness_holds_while_the_bus_parks() -> void:
	var passenger := _passenger(_away)
	_cabin.board(passenger)
	_cabin.docked = false
	_cabin.parking = true
	_cabin._process(10.0)

	assert_float(passenger.happiness).is_equal(Passenger.BASE_HAPPINESS)


func test_a_kick_scares_everyone_left_on_board() -> void:
	var kicked := _passenger(_away)
	var staying := _passenger(_away)
	_cabin.board(kicked)
	_cabin.board(staying)

	assert_bool(_cabin.kick(kicked)).is_true()

	assert_float(staying.happiness).is_equal(Passenger.BASE_HAPPINESS + Cabin.KICK_SHOCK)
	assert_float(kicked.happiness).is_equal(Passenger.BASE_HAPPINESS)


func test_comfort_follows_the_bus_s_traits() -> void:
	var stats := BusStats.new()
	_cabin.follow(stats)
	assert_float(_cabin.comfort.bonus).is_equal(0.0)
	assert_bool(_cabin.comfort.can_sleep()).is_false()

	stats.get_traits().add(BusTraits.Type.GAMEPADS)
	stats.get_traits().add(BusTraits.Type.PILLOWS)

	assert_float(_cabin.comfort.bonus).is_equal(Comfort.GAMEPADS_BONUS)
	assert_float(_cabin.comfort.sleep_max).is_equal(Comfort.PILLOW_NAP_MAX)

	stats.get_traits().add(BusTraits.Type.SLEEPING_PODS)

	assert_float(_cabin.comfort.sleep_max).is_equal(Comfort.POD_SLEEP_MAX)
	assert_float(_cabin.comfort.sleep_clock).is_equal(Comfort.POD_CLOCK)


func test_only_passengers_going_there_get_off_and_pay() -> void:
	var going := _passenger(_away)
	var staying := _passenger(_home)
	_cabin.board(going)
	_cabin.board(staying)
	var payout := going.get_payout()
	monitor_signals(_cabin)

	_cabin.stop_at(_away)

	assert_array(_cabin.get_passengers()).contains_exactly([staying])
	await assert_signal(_cabin).is_emitted("delivered", [going, payout])


func test_everyone_going_there_is_announced_before_the_first_gets_off() -> void:
	var first := _passenger(_away)
	var staying := _passenger(_home)
	var second := _passenger(_away)
	for passenger: Passenger in [first, staying, second]:
		_cabin.board(passenger)
	var events: Array[String] = []
	_cabin.getting_off.connect(
		func(p: Passenger) -> void: events.append("leaving %d" % [first, second].find(p))
	)
	_cabin.delivered.connect(
		func(p: Passenger, _paid: int) -> void: events.append("off %d" % [first, second].find(p))
	)

	_cabin.stop_at(_away)

	assert_array(events).contains_exactly(["leaving 0", "leaving 1", "off 0"])


func test_a_stop_lets_off_then_boards_those_picked_up_one_at_a_time() -> void:
	_cabin.step_seconds = 0.2
	_cabin.seats = 3
	_cabin.board(_passenger(_away))
	_cabin.board(_passenger(_away))
	_cabin.board(_passenger(_home))
	var events: Array[String] = []
	_cabin.delivered.connect(func(_p: Passenger, _paid: int) -> void: events.append("off"))
	_cabin.boarded.connect(func(_p: Passenger) -> void: events.append("on"))
	_cabin.unloaded.connect(func() -> void: events.append("unloaded"))

	_cabin.stop_at(_away)
	# Picked up while the others are still getting off, so they get on after them.
	assert_bool(_cabin.pick_up(_passenger(_home))).is_true()

	# The first gets off at once, the rest one step apart.
	assert_array(events).contains_exactly(["off"])
	assert_bool(_cabin.is_stopping()).is_true()
	await await_millis(300)
	assert_array(events).contains_exactly(["off", "off"])
	await assert_signal(_cabin).wait_until(2000).is_emitted("stop_finished")
	assert_array(events).contains_exactly(["off", "off", "unloaded", "on"])
	assert_int(_cabin.get_passengers().size()).is_equal(2)
	assert_bool(_cabin.is_stopping()).is_false()


func test_a_stop_with_nobody_getting_off_or_on_is_over_at_once() -> void:
	_cabin.board(_passenger(_home))
	var finished := [false]
	_cabin.stop_finished.connect(func() -> void: finished[0] = true)

	_cabin.stop_at(_away)

	assert_bool(finished[0]).is_true()
	assert_bool(_cabin.is_stopping()).is_false()


func test_picks_up_only_while_a_seat_is_free_for_them() -> void:
	_cabin.seats = 2
	_cabin.board(_passenger(_away))
	var picked := _passenger(_away)

	assert_bool(_cabin.pick_up(picked)).is_true()
	# The last seat is theirs while they get on.
	assert_int(_cabin.get_free_seats()).is_equal(0)
	assert_bool(_cabin.pick_up(_passenger(_away))).is_false()
	assert_array(_cabin.get_passengers()).contains([picked])


func test_the_seats_follow_the_bus_stat_and_cutting_them_leaves_riders_on_board() -> void:
	_cabin.seats = 2
	var stats := BusStats.new()

	_cabin.follow(stats)
	assert_float(stats.get_stat(BusStats.Type.SEATS).base).is_equal(2.0)

	stats.add_modifier(_seat_change(1.0))
	assert_int(_cabin.seats).is_equal(3)
	for i: int in 3:
		assert_bool(_cabin.board(_passenger(_away))).is_true()

	stats.add_modifier(_seat_change(-2.0))
	assert_int(_cabin.seats).is_equal(1)
	assert_int(_cabin.get_passengers().size()).is_equal(3)
	assert_int(_cabin.get_free_seats()).is_equal(0)
	assert_bool(_cabin.board(_passenger(_away))).is_false()


func test_someone_picked_up_still_gets_on_after_their_seat_is_cut() -> void:
	_cabin.step_seconds = 0.1
	_cabin.seats = 2
	var stats := BusStats.new()
	_cabin.follow(stats)
	_cabin.board(_passenger(_away))
	_cabin.board(_passenger(_home))
	# The first gets off at once, which frees a seat to pick someone up into.
	_cabin.stop_at(_away)
	var picked := _passenger(_home)
	assert_bool(_cabin.pick_up(picked)).is_true()

	stats.add_modifier(_seat_change(-1.0))

	await assert_signal(_cabin).wait_until(2000).is_emitted("stop_finished")
	assert_array(_cabin.get_passengers()).contains([picked])


func test_an_amenity_serves_its_need_as_soon_as_it_is_asked_for() -> void:
	var dispenser := Amenity.new()
	dispenser.need = &"snack"
	dispenser.line = "Getting a snack from the dispenser"
	_cabin.amenities = [dispenser]
	var passenger := _passenger(_away, 0.5)
	_cabin.board(passenger)

	await await_millis(800)

	assert_object(passenger.request).is_null()
	assert_str(passenger.activity).is_equal(dispenser.line)


# A passenger to [param to] whose one need, a snack, asks after [param need_after] seconds.
func _passenger(to: Planet, need_after := 1000.0) -> Passenger:
	var snack := Need.new()
	snack.id = &"snack"
	snack.min_interval = need_after
	snack.max_interval = need_after
	var kind := PassengerType.new()
	kind.needs = [snack]
	return Passenger.new(kind, to, 100.0, 40.0)


func _seat_change(amount: float) -> StatModifier:
	return StatModifier.new(BusStats.Type.SEATS, StatModifier.Kind.FLAT, amount)
