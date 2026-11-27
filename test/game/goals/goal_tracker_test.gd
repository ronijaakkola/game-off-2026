extends GdUnitTestSuite
## The goals the tracker follows, told what happens in a real Cabin and Ledger: deliveries
## count toward a milestone, a quest completes on its passenger's delivery and fails on
## their kick, a standing rating goal follows the ledger, an on-time milestone skips the
## late, and an earning goal counts credits that come in, whatever is spent.

var _tracker: GoalTracker
var _cabin: Cabin
var _ledger: Ledger
var _away: Planet


func before_test() -> void:
	_cabin = auto_free(Cabin.new())
	add_child(_cabin)
	_away = auto_free(Planet.new())
	add_child(_away)
	_ledger = Ledger.new()
	_tracker = auto_free(GoalTracker.new())
	_tracker.cabin = _cabin
	_tracker.ledger = _ledger
	add_child(_tracker)


func test_a_milestone_counts_deliveries_from_when_it_is_added_but_not_kicks() -> void:
	await _deliver(_passenger())
	var goal := DeliveryCountGoal.new(2)
	_tracker.add(goal)
	monitor_signals(_tracker)

	_cabin.kick(_board(_passenger()))
	await _deliver(_passenger())

	assert_float(goal.get_progress()).is_equal(0.5)
	assert_bool(goal.is_met()).is_false()

	await _deliver(_passenger())

	assert_bool(goal.is_met()).is_true()
	await assert_signal(_tracker).is_emitted("goal_completed", [goal])
	# Done stays done.
	await _deliver(_passenger())
	assert_bool(goal.is_met()).is_true()
	assert_float(goal.get_progress()).is_equal(1.0)


func test_a_milestone_of_one_type_counts_only_those_passengers() -> void:
	var business := PassengerType.new()
	var goal := DeliveryCountGoal.new(2, business)
	_tracker.add(goal)

	await _deliver(_passenger())
	await _deliver(_passenger(business))

	assert_float(goal.get_progress()).is_equal(0.5)
	assert_bool(goal.is_met()).is_false()

	await _deliver(_passenger(business))

	assert_bool(goal.is_met()).is_true()


func test_a_quest_completes_when_its_passenger_is_delivered() -> void:
	var passenger := _passenger()
	var goal := PassengerDeliveryGoal.new(passenger)
	_tracker.add(goal)

	await _deliver(_passenger())
	assert_bool(goal.is_active()).is_true()
	await _deliver(passenger)

	assert_int(goal.state).is_equal(Goal.State.COMPLETED)


func test_a_quest_fails_when_its_passenger_is_kicked_and_stays_failed() -> void:
	var passenger := _board(_passenger())
	var goal := PassengerDeliveryGoal.new(passenger)
	_tracker.add(goal)
	monitor_signals(_tracker)

	_cabin.kick(passenger)

	assert_int(goal.state).is_equal(Goal.State.FAILED)
	await assert_signal(_tracker).is_emitted("goal_failed", [goal])
	# Taking in no more facts, a later delivery doesn't complete it.
	goal.passenger_delivered(passenger)
	assert_int(goal.state).is_equal(Goal.State.FAILED)


func test_a_rating_goal_starts_from_the_ledger_and_follows_it() -> void:
	_ledger.rate(5.0)
	_ledger.rate(5.0)
	var goal := RatingGoal.new(4.0, 3)
	_tracker.add(goal)

	# Above the target, but too few rides yet.
	assert_bool(goal.is_met()).is_false()
	_ledger.rate(5.0)
	assert_bool(goal.is_met()).is_true()
	_ledger.rate(0.0)
	_ledger.rate(0.0)
	assert_bool(goal.is_met()).is_false()


func test_a_rating_goal_forgets_rides_older_than_the_recent_ones() -> void:
	var goal := RatingGoal.new(4.0)
	_tracker.add(goal)
	for i: int in 10:
		_ledger.rate(1.0)
	assert_bool(goal.is_met()).is_false()

	for i: int in 10:
		_ledger.rate(5.0)
	assert_bool(goal.is_met()).is_true()


func test_all_are_met_only_while_each_milestone_is_done_and_each_standing_goal_holds() -> void:
	assert_bool(_tracker.are_all_met()).override_failure_message("met with no goals").is_false()
	var deliveries := DeliveryCountGoal.new(1)
	var rating := RatingGoal.new(3.0)
	_tracker.add(deliveries)
	_tracker.add(rating)

	_ledger.rate(5.0)
	assert_bool(_tracker.are_all_met()).is_false()
	await _deliver(_passenger())
	assert_bool(_tracker.are_all_met()).is_true()
	_ledger.rate(0.0)
	_ledger.rate(0.0)
	assert_bool(_tracker.are_all_met()).is_false()


func test_a_removed_goal_takes_in_nothing_more() -> void:
	var goal := DeliveryCountGoal.new(1)
	_tracker.add(goal)
	_tracker.remove(goal)

	await _deliver(_passenger())

	assert_bool(goal.is_met()).is_false()
	assert_array(_tracker.get_goals()).is_empty()


func test_frozen_goals_stay_as_they_stand() -> void:
	var deliveries := DeliveryCountGoal.new(2)
	var rating := RatingGoal.new(4.0)
	_tracker.add(deliveries)
	_tracker.add(rating)
	_ledger.rate(5.0)
	await _deliver(_passenger())
	await _deliver(_passenger())
	assert_bool(_tracker.are_all_met()).is_true()

	_tracker.frozen = true
	_ledger.rate(0.0)
	_ledger.rate(0.0)
	await _deliver(_passenger())

	assert_bool(_tracker.are_all_met()).override_failure_message("a frozen goal moved").is_true()
	assert_float(rating.get_progress()).is_equal(1.0)


func test_an_on_time_milestone_skips_passengers_who_were_late() -> void:
	var goal := DeliveryCountGoal.new(1, Vip.TYPE, true)
	_tracker.add(goal)
	var late := _passenger(Vip.TYPE)
	late.ride.clock = late.ride.get_seconds_left() + 1.0

	await _deliver(late)

	assert_bool(goal.is_met()).is_false()
	assert_str(goal.get_text()).is_equal("Deliver 1 VIP passengers on time")

	await _deliver(_passenger(Vip.TYPE))

	assert_bool(goal.is_met()).is_true()


func test_an_earning_goal_counts_credits_earned_and_ignores_spending() -> void:
	var goal := EarnCreditsGoal.new(1000)
	_tracker.add(goal)

	_ledger.earn(600)
	_ledger.spend(500)

	assert_int(goal.earned).is_equal(600)
	assert_bool(goal.is_met()).is_false()

	_ledger.earn(400)

	assert_bool(goal.is_met()).is_true()


func test_an_earning_goal_comes_back_from_a_save() -> void:
	var goal := EarnCreditsGoal.new(1000)
	goal.earned = 250
	var back := EarnCreditsGoal.new(1000)

	back.load_save(goal.to_save())

	assert_int(back.earned).is_equal(250)


func _passenger(type: PassengerType = PassengerType.new()) -> Passenger:
	return Passenger.new(type, _away, 100.0, 40.0)


func _board(passenger: Passenger) -> Passenger:
	_cabin.board(passenger)
	return passenger


# Boards [param passenger], stops at their destination and waits until they are off.
func _deliver(passenger: Passenger) -> void:
	_board(passenger)
	_cabin.stop_at(_away)
	await await_signal_on(_cabin, "stop_finished", [], 3000)
