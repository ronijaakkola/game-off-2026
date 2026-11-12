extends GdUnitTestSuite
## The ledger: the player's credits, research points by race and the ratings passengers
## gave, each change signalled for the resource bar to show.


func test_earning_and_spending_change_the_credits_and_say_by_how_much() -> void:
	var ledger := Ledger.new()
	var changes: Array[int] = []
	ledger.credits_earned.connect(func(amount: int) -> void: changes.append(amount))
	ledger.credits_spent.connect(func(amount: int) -> void: changes.append(-amount))

	ledger.earn(15)
	ledger.spend(20)

	assert_int(ledger.credits).is_equal(-5)
	assert_array(changes).is_equal([15, -20])


func test_research_points_add_up_by_race() -> void:
	var ledger := Ledger.new()

	ledger.earn_research(Race.Type.BLUE)
	ledger.earn_research(Race.Type.BLUE, 2)
	ledger.earn_research(Race.Type.GREEN)

	assert_int(ledger.get_research(Race.Type.BLUE)).is_equal(3)
	assert_int(ledger.get_research(Race.Type.ORANGE)).is_equal(0)
	assert_int(ledger.get_research(Race.Type.GREEN)).is_equal(1)


func test_the_average_rating_is_the_mean_with_out_of_range_ratings_at_the_nearest_end() -> void:
	var ledger := Ledger.new()
	assert_float(ledger.get_average_rating()).is_equal(0.0)

	ledger.rate(9.0)
	ledger.rate(-3.0)
	ledger.rate(4.0)

	assert_int(ledger.get_rating_count()).is_equal(3)
	assert_float(ledger.get_average_rating()).is_equal_approx(3.0, 0.001)


func test_the_recent_rating_is_the_mean_of_only_the_last_ratings() -> void:
	var ledger := Ledger.new()
	assert_float(ledger.get_recent_rating()).is_equal(0.0)
	for i: int in Ledger.RECENT_RATINGS:
		ledger.rate(1.0)
	for i: int in Ledger.RECENT_RATINGS:
		ledger.rate(5.0)

	assert_float(ledger.get_recent_rating()).is_equal_approx(5.0, 0.001)
	assert_float(ledger.get_average_rating()).is_equal_approx(3.0, 0.001)
