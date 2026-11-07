extends GdUnitTestSuite
## The ride's rules: patience, mood, pay and needs, through Passenger's public calls.

const TRIP := 100.0
const FARE := 50.0

var _planet: Planet


func before_test() -> void:
	_planet = auto_free(Planet.new())


func test_mood_follows_patience_left() -> void:
	assert_int(Passenger.mood_for(1.0)).is_equal(Passenger.Mood.HAPPY)
	assert_int(Passenger.mood_for(0.6)).is_equal(Passenger.Mood.HAPPY)
	assert_int(Passenger.mood_for(0.59)).is_equal(Passenger.Mood.OKAY)
	assert_int(Passenger.mood_for(0.3)).is_equal(Passenger.Mood.OKAY)
	assert_int(Passenger.mood_for(0.29)).is_equal(Passenger.Mood.ANNOYED)
	assert_int(Passenger.mood_for(0.01)).is_equal(Passenger.Mood.ANNOYED)
	assert_int(Passenger.mood_for(0.0)).is_equal(Passenger.Mood.FURIOUS)


func test_patience_starts_at_the_trip_time_with_the_type_s_slack() -> void:
	var kind := _type()
	kind.patience_slack = 1.5
	var passenger := Passenger.new(kind, _planet, TRIP, FARE)
	assert_float(passenger.patience).is_equal(150.0)


func test_patience_holds_until_they_depart() -> void:
	var snack := _need(1.0)
	var passenger := Passenger.new(_type([snack]), _planet, TRIP, FARE)
	passenger.tick(30.0, true)
	passenger.tick(30.0, false)
	assert_object(passenger.request).is_same(snack)
	assert_float(passenger.patience).is_equal(passenger.patience_max)


func test_patience_runs_down_at_half_speed_while_docked() -> void:
	var flying := Passenger.new(_type(), _planet, TRIP, FARE)
	var docked := Passenger.new(_type(), _planet, TRIP, FARE)
	flying.depart()
	docked.depart()
	flying.tick(10.0, false)
	docked.tick(10.0, true)
	assert_float(flying.patience_max - flying.patience).is_equal_approx(10.0, 0.001)
	assert_float(docked.patience_max - docked.patience).is_equal_approx(5.0, 0.001)


func test_pay_follows_mood_at_the_end() -> void:
	var kind := _type()
	kind.fare_multiplier = 2.0
	var passenger := Passenger.new(kind, _planet, TRIP, FARE)
	assert_int(passenger.get_payout()).is_equal(120)
	passenger.patience = passenger.patience_max * 0.4
	assert_int(passenger.get_payout()).is_equal(100)
	passenger.patience = passenger.patience_max * 0.1
	assert_int(passenger.get_payout()).is_equal(50)
	passenger.patience = 0.0
	assert_int(passenger.get_payout()).is_equal(0)


func test_finds_their_seat_then_idles_on_one_of_the_type_s_lines() -> void:
	var kind := _type()
	kind.idle_lines = ["Sleeping...", "Counting stars"]
	var passenger := Passenger.new(kind, _planet, TRIP, FARE)
	assert_str(passenger.activity).is_equal(Passenger.BOARDING_LINE)
	passenger.tick(Passenger.BOARDING_SECONDS + 0.1, true)
	assert_array(kind.idle_lines).contains([passenger.activity])


func test_asks_for_a_need_when_its_timer_runs_out() -> void:
	var snack := _need(10.0)
	var passenger := Passenger.new(_type([snack]), _planet, TRIP, FARE)
	passenger.tick(9.0, false)
	assert_object(passenger.request).is_null()
	passenger.tick(2.0, false)
	assert_object(passenger.request).is_same(snack)
	assert_str(passenger.activity).is_equal(snack.request_line)


func test_an_open_request_drains_patience_faster() -> void:
	var snack := _need(1.0)
	snack.unmet_drain = 3.0
	var passenger := Passenger.new(_type([snack]), _planet, TRIP, FARE)
	passenger.depart()
	passenger.tick(1.0, false)
	var before := passenger.patience
	passenger.tick(10.0, false)
	assert_float(before - passenger.patience).is_equal_approx(30.0, 0.001)


func test_serving_closes_the_request_and_shows_the_served_line() -> void:
	var snack := _need(1.0)
	var passenger := Passenger.new(_type([snack]), _planet, TRIP, FARE)
	passenger.tick(1.0, false)
	passenger.serve()
	assert_object(passenger.request).is_null()
	assert_str(passenger.activity).is_equal(snack.served_line)
	# The served activity lasts its time, then they idle and the need waits its interval.
	passenger.tick(snack.served_seconds + 0.1, false)
	assert_str(passenger.activity).is_not_equal(snack.served_line)
	assert_object(passenger.request).is_null()


func test_an_amenity_serves_with_its_own_line() -> void:
	var snack := _need(1.0)
	var passenger := Passenger.new(_type([snack]), _planet, TRIP, FARE)
	passenger.tick(1.0, false)
	var dispenser := Amenity.new()
	dispenser.need = snack.id
	dispenser.line = "Getting a snack from the dispenser"
	passenger.serve_with(dispenser)
	assert_object(passenger.request).is_null()
	assert_str(passenger.activity).is_equal(dispenser.line)


func test_the_same_seed_gives_the_same_look() -> void:
	var looks: Array[AlienLook] = []
	for i: int in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		looks.append(Passenger.new(_type(), _planet, TRIP, FARE, rng).look)
	assert_object(looks[0].head).is_same(looks[1].head)
	assert_object(looks[0].eye_style).is_same(looks[1].eye_style)
	assert_that(looks[0].skin_color).is_equal(looks[1].skin_color)


func _type(needs: Array[Need] = []) -> PassengerType:
	var kind := PassengerType.new()
	kind.needs = needs
	return kind


# A need that asks exactly every [param interval] seconds.
func _need(interval: float) -> Need:
	var need := Need.new()
	need.id = &"snack"
	need.request_line = "Hungry"
	need.served_line = "Munching"
	need.min_interval = interval
	need.max_interval = interval
	return need
