extends GdUnitTestSuite
## When a need next asks: the first wait of someone just on board, and the wait after it
## is served.

const INTERVAL := 20.0


func test_the_first_wait_is_a_random_part_of_an_interval() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var need := _need(0.25)
	var shortest := INF
	var longest := 0.0
	for i: int in 200:
		var wait := _first_wait(Appetite.new([need], 1.0, rng))
		shortest = minf(shortest, wait)
		longest = maxf(longest, wait)
	assert_float(shortest).is_between(INTERVAL * 0.25, INTERVAL * 0.35)
	assert_float(longest).is_between(INTERVAL * 0.9, INTERVAL)


func test_a_first_wait_of_1_is_a_whole_interval() -> void:
	var appetite := Appetite.new([_need(1.0)], 1.0, RandomNumberGenerator.new())
	assert_float(_first_wait(appetite)).is_equal_approx(INTERVAL, 0.001)


func test_a_served_need_waits_a_whole_interval_after_its_activity() -> void:
	var need := _need(0.25)
	var appetite := Appetite.new([need], 1.0, RandomNumberGenerator.new())
	appetite.rest(need, 5.0)
	assert_float(_first_wait(appetite)).is_equal_approx(INTERVAL + 5.0, 0.001)


func test_the_type_s_scale_stretches_every_wait() -> void:
	var appetite := Appetite.new([_need(1.0)], 0.5, RandomNumberGenerator.new())
	assert_float(_first_wait(appetite)).is_equal_approx(INTERVAL * 0.5, 0.001)


# A need that asks exactly every INTERVAL seconds, after a first wait of at least
# [param first_wait] of one.
func _need(first_wait: float) -> Need:
	var need := Need.new()
	need.min_interval = INTERVAL
	need.max_interval = INTERVAL
	need.first_wait = first_wait
	return need


# Seconds until [param appetite]'s need is due, found by running it out.
func _first_wait(appetite: Appetite) -> float:
	var saved := appetite.to_save()
	return float(saved[0])
