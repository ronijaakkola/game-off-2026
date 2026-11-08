extends GdUnitTestSuite
## The average rating beside the credits: a dash until the first rating, then the mean of
## every rating to one decimal, popping with each new one.

const SCENE := "res://game/solar_system/rating_counter.tscn"


func test_shows_a_dash_before_anyone_rates() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as RatingCounter
	assert_str((runner.find_child("AverageLabel") as Label).text).is_equal(RatingCounter.NO_RATING)
	assert_int(counter.get_count()).is_equal(0)
	assert_float(counter.get_average()).is_equal(0.0)


func test_shows_the_mean_of_every_rating_to_one_decimal() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as RatingCounter
	var label := runner.find_child("AverageLabel") as Label

	counter.add(5.0)
	counter.add(4.0)
	counter.add(0.0)

	assert_int(counter.get_count()).is_equal(3)
	assert_float(counter.get_average()).is_equal_approx(3.0, 0.001)
	assert_str(label.text).is_equal("3.0")
	counter.add(5.0)
	counter.add(5.0)
	assert_str(label.text).is_equal("3.8")


func test_a_rating_out_of_range_counts_as_the_nearest_end() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as RatingCounter

	counter.add(9.0)
	counter.add(-3.0)

	assert_float(counter.get_average()).is_equal_approx(2.5, 0.001)


func test_each_rating_pops_the_number() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as RatingCounter
	var label := runner.find_child("AverageLabel") as Label

	counter.add(5.0)
	await runner.simulate_frames(2, 20)
	assert_float(label.scale.x).is_greater(1.0)
	await runner.simulate_frames(20, 30)
	assert_float(label.scale.x).is_equal_approx(1.0, 0.01)
