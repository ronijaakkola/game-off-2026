extends GdUnitTestSuite
## The goals the tracker follows, told what happens in a real Cabin and Ledger: deliveries
## count toward a milestone, a quest completes on its passenger's delivery and fails on
## their kick, and a standing rating goal follows the ledger.

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


func _passenger() -> Passenger:
	return Passenger.new(PassengerType.new(), _away, 100.0, 40.0)


func _board(passenger: Passenger) -> Passenger:
	_cabin.board(passenger)
	return passenger


# Boards [param passenger], stops at their destination and waits until they are off.
func _deliver(passenger: Passenger) -> void:
	_board(passenger)
	_cabin.stop_at(_away)
	await await_signal_on(_cabin, "stop_finished", [], 3000)
