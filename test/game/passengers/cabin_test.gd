extends GdUnitTestSuite
## Boarding, amenities and getting off, through Cabin's public calls.

var _cabin: Cabin
var _home: Planet
var _away: Planet


func before_test() -> void:
	_cabin = auto_free(Cabin.new())
	add_child(_cabin)
	_home = auto_free(Planet.new())
	_away = auto_free(Planet.new())


func test_boards_until_the_seats_are_full() -> void:
	_cabin.seats = 2
	assert_bool(_cabin.board(_passenger(_away))).is_true()
	assert_bool(_cabin.board(_passenger(_away))).is_true()
	assert_bool(_cabin.board(_passenger(_away))).is_false()
	assert_int(_cabin.get_passengers().size()).is_equal(2)


func test_only_passengers_going_there_get_off_and_pay() -> void:
	var going := _passenger(_away)
	var staying := _passenger(_home)
	_cabin.board(going)
	_cabin.board(staying)
	monitor_signals(_cabin)

	var paid := _cabin.arrive_at(_away)

	assert_int(paid).is_equal(going.get_payout())
	assert_array(_cabin.get_passengers()).contains_exactly([staying])
	await assert_signal(_cabin).is_emitted("delivered", [going, paid])


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
