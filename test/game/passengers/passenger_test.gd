extends GdUnitTestSuite
## The ride's rules: happiness, timing, shocks, mood, pay and needs, through Passenger's
## public calls.

const TRIP := 100.0
const FARE := 50.0
# Where a passenger starts the ride on a bare bus.
const START := Passenger.BASE_HAPPINESS + Passenger.ON_TIME_BONUS

var _planet: Planet


func before_test() -> void:
	_planet = auto_free(Planet.new())


func test_mood_follows_happiness() -> void:
	assert_int(Passenger.mood_for(100.0)).is_equal(Passenger.Mood.HAPPY)
	assert_int(Passenger.mood_for(70.0)).is_equal(Passenger.Mood.HAPPY)
	assert_int(Passenger.mood_for(69.9)).is_equal(Passenger.Mood.OKAY)
	assert_int(Passenger.mood_for(50.0)).is_equal(Passenger.Mood.OKAY)
	assert_int(Passenger.mood_for(49.9)).is_equal(Passenger.Mood.ANNOYED)
	assert_int(Passenger.mood_for(25.0)).is_equal(Passenger.Mood.ANNOYED)
	assert_int(Passenger.mood_for(24.9)).is_equal(Passenger.Mood.FURIOUS)
	assert_int(Passenger.mood_for(0.0)).is_equal(Passenger.Mood.FURIOUS)


func test_they_wait_at_the_base_and_expect_the_trip_with_the_type_s_slack() -> void:
	var kind := _type()
	kind.slack = 1.5
	var passenger := Passenger.new(kind, _planet, TRIP, FARE)
	assert_float(passenger.happiness).is_equal(Passenger.BASE_HAPPINESS)
	assert_float(passenger.expected_seconds).is_equal(150.0)


func test_happiness_holds_until_they_depart() -> void:
	var snack := _need(1.0)
	var passenger := Passenger.new(_type([snack]), _planet, TRIP, FARE)
	passenger.tick(30.0, false)
	assert_object(passenger.request).is_same(snack)
	assert_float(passenger.happiness).is_equal(Passenger.BASE_HAPPINESS)


func test_they_start_the_ride_at_the_target_and_an_on_time_ride_keeps_them_there() -> void:
	var passenger := _departed()
	assert_float(passenger.happiness).is_equal(START)
	passenger.tick(TRIP, false)
	assert_float(passenger.happiness).is_equal(START)

	var comfort := Comfort.new()
	comfort.bonus = 20.0
	var comfortable := Passenger.new(_type(), _planet, TRIP, FARE)
	comfortable.depart(comfort)
	assert_float(comfortable.happiness).is_equal(START + 20.0)


func test_settling_does_nothing_after_a_shock_or_once_the_bus_has_left() -> void:
	var scared := Passenger.new(_type(), _planet, TRIP, FARE)
	scared.settle()
	scared.shock(-25.0)
	scared.depart()
	assert_float(scared.happiness).is_equal(START - 25.0)

	var riding := _departed()
	riding.happiness = 40.0
	riding.settle()
	assert_float(riding.happiness).is_equal(40.0)


func test_an_open_request_sends_them_toward_0_at_the_falling_rate() -> void:
	var snack := _need(1.0)
	var passenger := Passenger.new(_type([snack]), _planet, TRIP, FARE)
	passenger.depart()
	passenger.tick(1.0, false)
	assert_object(passenger.request).is_same(snack)
	var before := passenger.happiness
	passenger.tick(4.0, false)
	assert_float(before - passenger.happiness).is_equal_approx(4.0 * Passenger.FALL_RATE, 0.001)
	assert_float(passenger.get_target()).is_equal(0.0)


func test_timing_falls_to_0_at_the_expected_time_and_on_to_worn_out() -> void:
	var passenger := _departed()
	assert_float(passenger.get_timing()).is_equal(Passenger.ON_TIME_BONUS)
	passenger.tick(TRIP, false)
	assert_float(passenger.get_timing()).is_equal(Passenger.ON_TIME_BONUS)
	passenger.tick(passenger.expected_seconds - TRIP, false)
	assert_float(passenger.get_timing()).is_equal_approx(0.0, 0.001)
	passenger.tick(TRIP * 0.5, false)
	assert_float(passenger.get_timing()).is_equal_approx(Passenger.WORN_OUT * 0.5, 0.001)
	passenger.tick(TRIP, false)
	assert_float(passenger.get_timing()).is_equal(Passenger.WORN_OUT)


func test_given_enough_time_anyone_reaches_0_however_comfortable() -> void:
	var comfort := Comfort.new()
	comfort.bonus = Passenger.MAX_HAPPINESS
	var passenger := _departed()
	for i: int in 400:
		passenger.tick(1.0, false, false, comfort)
	assert_float(passenger.happiness).is_equal(0.0)


func test_while_docked_the_clock_runs_and_happiness_falls_slowly() -> void:
	var flying := _departed()
	var docked := _departed()
	flying.tick(TRIP + 20.0, false)
	docked.tick(TRIP + 20.0, true)
	assert_float(docked.get_timing()).is_equal(Passenger.ON_TIME_BONUS)
	assert_float(flying.get_timing()).is_less(Passenger.ON_TIME_BONUS)

	var cheerful := _departed()
	cheerful.happiness = Passenger.MAX_HAPPINESS
	cheerful.tick(10.0, true)
	assert_float(Passenger.MAX_HAPPINESS - cheerful.happiness).is_equal_approx(
		10.0 * Passenger.FALL_RATE * Passenger.DOCKED_RATE, 0.001
	)


func test_no_request_opens_at_a_stop_and_their_needs_run_slowly_there() -> void:
	var snack := _need(5.0)
	var passenger := Passenger.new(_type([snack]), _planet, TRIP, FARE)
	passenger.depart()
	passenger.tick(30.0, true)
	assert_object(passenger.request).is_null()
	# Parking counts in full toward the need, but opens no request.
	passenger.tick(0.5, false, true)
	assert_object(passenger.request).is_null()
	# 30 s docked counted 3 s toward the 5 s, and parking 0.5 s.
	passenger.tick(1.0, false)
	assert_object(passenger.request).is_null()
	passenger.tick(1.0, false)
	assert_object(passenger.request).is_same(snack)


func test_an_open_request_goes_on_hold_at_a_stop_and_returns_when_the_bus_leaves() -> void:
	var snack := _need(1.0)
	var passenger := Passenger.new(_type([snack]), _planet, TRIP, FARE)
	passenger.depart()
	passenger.tick(1.5, false)
	assert_object(passenger.request).is_same(snack)

	passenger.tick(0.1, true)
	assert_object(passenger.request).is_null()
	assert_str(passenger.activity).is_not_equal(snack.request_line)
	assert_float(passenger.get_target()).is_greater(0.0)

	passenger.tick(0.1, false)
	assert_object(passenger.request).is_same(snack)
	assert_str(passenger.activity).is_equal(snack.request_line)


func test_arriving_with_a_long_unserved_request_disappoints_them() -> void:
	var snack := _need(1.0)
	var ignored := Passenger.new(_type([snack]), _planet, TRIP, FARE)
	ignored.depart()
	ignored.tick(1.0, false)
	ignored.tick(Passenger.REQUEST_GRACE, false)
	ignored.tick(0.1, false, true)
	var before := ignored.happiness
	ignored.arrive()
	assert_float(ignored.happiness).is_equal(before + Passenger.UNSERVED_SHOCK)


func test_a_request_asked_just_before_arriving_is_forgiven() -> void:
	var snack := _need(1.0)
	var late := Passenger.new(_type([snack]), _planet, TRIP, FARE)
	late.depart()
	late.tick(1.0, false)
	late.tick(Passenger.REQUEST_GRACE * 0.5, false)
	# Parking counts for nothing.
	late.tick(Passenger.REQUEST_GRACE, false, true)
	var before := late.happiness
	late.arrive()
	assert_float(late.happiness).is_equal(before)


func test_a_happy_passenger_grants_leeway_up_to_a_limit() -> void:
	var comfort := Comfort.new()
	comfort.bonus = 30.0
	var happy := _departed()
	happy.happiness = Passenger.LEEWAY_HAPPINESS
	happy.tick(10.0, false, false, comfort)
	assert_float(happy.leeway).is_equal_approx(10.0 * Passenger.LEEWAY_RATE, 0.001)
	for i: int in 300:
		happy.tick(1.0, false, false, comfort)
	assert_float(happy.leeway).is_equal_approx(TRIP * Passenger.LEEWAY_MAX, 0.001)

	var content := _departed()
	content.tick(TRIP, false)
	assert_float(content.leeway).is_equal(0.0)


func test_comfort_raises_the_target() -> void:
	var comfort := Comfort.new()
	comfort.bonus = 20.0
	var passenger := _departed()
	assert_float(passenger.get_target(comfort)).is_equal(
		Passenger.BASE_HAPPINESS + 20.0 + Passenger.ON_TIME_BONUS
	)


func test_a_shock_changes_happiness_at_once_and_it_climbs_back_slowly() -> void:
	var passenger := _departed()
	passenger.shock(-25.0)
	assert_float(passenger.happiness).is_equal(START - 25.0)
	passenger.tick(10.0, false)
	assert_float(passenger.happiness).is_equal_approx(
		START - 25.0 + 10.0 * Passenger.CLIMB_RATE, 0.001
	)
	passenger.shock(-1000.0)
	assert_float(passenger.happiness).is_equal(0.0)


func test_pay_follows_mood_at_the_end() -> void:
	var kind := _type()
	kind.fare_multiplier = 2.0
	var passenger := Passenger.new(kind, _planet, TRIP, FARE)
	passenger.happiness = 80.0
	assert_int(passenger.get_payout()).is_equal(120)
	passenger.happiness = 60.0
	assert_int(passenger.get_payout()).is_equal(100)
	passenger.happiness = 30.0
	assert_int(passenger.get_payout()).is_equal(50)
	passenger.happiness = 10.0
	assert_int(passenger.get_payout()).is_equal(0)


func test_rating_is_happiness_in_fifths_to_the_nearest_star() -> void:
	var passenger := Passenger.new(_type(), _planet, TRIP, FARE)
	assert_float(passenger.get_rating()).is_equal(3.0)
	passenger.happiness = Passenger.BASE_HAPPINESS + Passenger.ON_TIME_BONUS
	assert_float(passenger.get_rating()).is_equal(4.0)
	passenger.happiness = 100.0
	assert_float(passenger.get_rating()).is_equal(5.0)
	passenger.happiness = 29.0
	assert_float(passenger.get_rating()).is_equal(1.0)
	passenger.happiness = 0.0
	assert_float(passenger.get_rating()).is_equal(0.0)


func test_finds_their_seat_then_idles_on_one_of_the_type_s_lines() -> void:
	var kind := _type()
	kind.idle_lines = ["Reading", "Counting stars"]
	var passenger := Passenger.new(kind, _planet, TRIP, FARE)
	assert_str(passenger.activity).is_equal(Passenger.BOARDING_LINE)
	passenger.tick(Passenger.BOARDING_SECONDS + 0.1, true)
	assert_array(kind.idle_lines).contains([passenger.activity])
	assert_bool(passenger.asleep).is_false()


func test_nobody_sleeps_on_a_bus_with_nowhere_to_sleep() -> void:
	var kind := _type()
	kind.idle_lines = []
	kind.sleep_lines = ["Sleeping..."]
	var passenger := Passenger.new(kind, _planet, TRIP, FARE)
	passenger.tick(Passenger.BOARDING_SECONDS + 0.1, false)
	assert_bool(passenger.asleep).is_false()
	assert_str(passenger.activity).is_empty()


func test_a_sleep_runs_its_length_while_their_needs_wait() -> void:
	var snack := _need(Passenger.BOARDING_SECONDS + 1.0)
	var kind := _type([snack])
	kind.idle_lines = []
	kind.sleep_lines = ["Sleeping..."]
	var passenger := Passenger.new(kind, _planet, TRIP, FARE)
	var comfort := _sleepy(10.0)
	passenger.tick(Passenger.BOARDING_SECONDS + 0.1, false, false, comfort)
	assert_str(passenger.activity).is_equal("Sleeping...")
	assert_bool(passenger.asleep).is_true()
	passenger.tick(9.0, false, false, comfort)
	assert_bool(passenger.asleep).is_true()
	assert_object(passenger.request).is_null()
	# Woken on a bare bus, so they don't drop straight back off.
	passenger.tick(1.5, false)
	assert_bool(passenger.asleep).is_false()
	passenger.tick(1.0, false)
	assert_object(passenger.request).is_same(snack)


func test_their_clock_runs_as_slow_as_the_comfort_says_while_asleep() -> void:
	var kind := _type()
	kind.idle_lines = []
	kind.sleep_lines = ["Sleeping..."]
	var passenger := Passenger.new(kind, _planet, TRIP, FARE)
	passenger.depart()
	var comfort := _sleepy(1000.0)
	comfort.sleep_clock = 0.25
	passenger.tick(Passenger.BOARDING_SECONDS, false, false, comfort)
	passenger.tick(0.1, false, false, comfort)
	passenger.tick(TRIP * 2.0, false, false, comfort)
	assert_bool(passenger.asleep).is_true()
	assert_float(passenger.get_timing()).is_equal(Passenger.ON_TIME_BONUS)


func test_a_show_slows_their_clock_until_a_request_stops_it() -> void:
	var snack := _need(Passenger.BOARDING_SECONDS + 5.0)
	var kind := _type([snack])
	kind.idle_lines = []
	kind.watch_lines = ["Watching a show"]
	var passenger := Passenger.new(kind, _planet, TRIP, FARE)
	passenger.depart()
	var comfort := Comfort.new()
	comfort.watch_min = 1000.0
	comfort.watch_max = 1000.0
	comfort.watch_clock = 0.25
	passenger.tick(Passenger.BOARDING_SECONDS + 0.1, false, false, comfort)
	assert_bool(passenger.watching).is_true()
	assert_int(passenger.action).is_equal(Need.Action.WATCH)
	# Four seconds on a quarter-speed clock: still the direct trip time.
	passenger.tick(4.0, false, false, comfort)
	assert_bool(passenger.watching).is_true()
	passenger.tick(1.0, false, false, comfort)
	assert_object(passenger.request).is_same(snack)
	assert_bool(passenger.watching).is_false()
	assert_int(passenger.action).is_equal(Need.Action.NONE)


func test_feeding_fills_the_request_and_holds_happiness_while_it_does() -> void:
	var snack := _need(1.0)
	snack.food = true
	snack.served_seconds = 4.0
	var passenger := Passenger.new(_type([snack]), _planet, TRIP, FARE)
	passenger.depart()
	passenger.tick(1.0, false)
	assert_object(passenger.request).is_same(snack)
	var before := passenger.happiness
	passenger.feed(0.5)
	passenger.tick(1.0, false)
	assert_float(passenger.happiness).is_equal(before)
	assert_float(passenger.serving).is_equal(0.5)
	# Bigger portions make the snack last longer.
	passenger.feed(0.5, 2.0)
	assert_object(passenger.request).is_null()
	passenger.tick(7.9, false)
	assert_str(passenger.activity).is_equal(snack.served_line)
	passenger.tick(0.2, false)
	assert_str(passenger.activity).is_not_equal(snack.served_line)


func test_a_shock_wakes_a_sleeper_and_waking_costs_more() -> void:
	var kind := _type()
	kind.idle_lines = ["Reading"]
	kind.sleep_lines = []
	var passenger := Passenger.new(kind, _planet, TRIP, FARE)
	passenger.asleep = true
	passenger.shock(-25.0)
	assert_bool(passenger.asleep).is_false()
	assert_float(passenger.happiness).is_equal(
		Passenger.BASE_HAPPINESS - 25.0 + Passenger.WAKE_SHOCK
	)


func test_asks_for_a_need_when_its_timer_runs_out() -> void:
	var snack := _need(10.0)
	var passenger := Passenger.new(_type([snack]), _planet, TRIP, FARE)
	passenger.tick(9.0, false)
	assert_object(passenger.request).is_null()
	passenger.tick(2.0, false)
	assert_object(passenger.request).is_same(snack)
	assert_str(passenger.activity).is_equal(snack.request_line)


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


func test_the_same_seed_gives_the_same_look() -> void:
	var looks: Array[AlienLook] = []
	for i: int in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		looks.append(Passenger.new(_type(), _planet, TRIP, FARE, rng).look)
	assert_object(looks[0].head).is_same(looks[1].head)
	assert_object(looks[0].eye_style).is_same(looks[1].eye_style)
	assert_that(looks[0].skin_color).is_equal(looks[1].skin_color)


func test_a_passenger_has_one_of_their_race_s_heads_in_its_colour() -> void:
	for i: int in 30:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var passenger := Passenger.new(_type(), _planet, TRIP, FARE, rng)
		assert_array(AlienLook.HEADS[passenger.race]).contains([passenger.look.head])
		assert_that(passenger.look.skin_color).is_equal(Race.SKIN_COLORS[passenger.race])


func test_the_trend_is_where_happiness_gets_to_in_the_next_seconds() -> void:
	var climbing := _departed()
	climbing.shock(-20.0)
	climbing.tick(0.01, false)
	assert_float(climbing.trend).is_greater(0.0)
	_expect_trend_comes_true(climbing)

	var snack := _need(1.0)
	var asking := Passenger.new(_type([snack]), _planet, TRIP, FARE)
	asking.depart()
	asking.tick(1.0, false)
	asking.tick(0.01, false)
	assert_object(asking.request).is_same(snack)
	assert_float(asking.trend).is_less(0.0)
	_expect_trend_comes_true(asking)


func test_the_trend_is_0_while_happiness_holds() -> void:
	var waiting := Passenger.new(_type(), _planet, TRIP, FARE)
	waiting.tick(1.0, false)
	assert_float(waiting.trend).override_failure_message("before departing").is_equal(0.0)

	var parked := _departed()
	parked.tick(1.0, false, true)
	assert_float(parked.trend).override_failure_message("while parked").is_equal(0.0)

	var settled := _departed()
	settled.tick(60.0, false)
	settled.tick(1.0, false)
	assert_float(settled.trend).override_failure_message("at the target").is_equal(0.0)


# A passenger whose bus has left, so their ride runs.
func _departed() -> Passenger:
	var passenger := Passenger.new(_type(), _planet, TRIP, FARE)
	passenger.depart()
	return passenger


# A bus where every sleep lasts exactly [param seconds].
func _sleepy(seconds: float) -> Comfort:
	var comfort := Comfort.new()
	comfort.sleep_min = seconds
	comfort.sleep_max = seconds
	return comfort


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


# Runs [constant Passenger.TREND_SECONDS] of the ride and checks [param passenger]'s
# happiness moved by the trend they had at the start.
func _expect_trend_comes_true(passenger: Passenger) -> void:
	var start := passenger.happiness
	var trend := passenger.trend
	for i: int in roundi(Passenger.TREND_SECONDS * 10.0):
		passenger.tick(0.1, false)
	assert_float(passenger.happiness - start).is_equal_approx(trend, 0.1)
