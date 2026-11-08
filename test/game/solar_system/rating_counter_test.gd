extends GdUnitTestSuite
## The average rating beside the credits: a dash until the first rating, then the mean of
## every rating to one decimal. Like the credits, ratings collect in a gain under it that
## shows how far the average moved, and on commit the average moves while the gain fades.

const SCENE := "res://game/solar_system/rating_counter.tscn"


func test_shows_a_dash_until_the_first_rating_is_committed() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as RatingCounter
	var label := runner.find_child("AverageLabel") as Label
	var gain := runner.find_child("GainLabel") as Label
	assert_str(label.text).is_equal(RatingCounter.NO_RATING)

	counter.add(4.0)
	# Nothing to move from yet, so no gain.
	assert_float(gain.modulate.a).is_equal(0.0)
	assert_str(label.text).is_equal(RatingCounter.NO_RATING)
	counter.commit()
	await runner.simulate_frames(30, 30)

	assert_str(label.text).is_equal("4.0")
	assert_int(counter.get_count()).is_equal(1)


func test_ratings_show_the_change_in_the_gain_while_the_average_waits() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as RatingCounter
	var label := runner.find_child("AverageLabel") as Label
	var gain := runner.find_child("GainLabel") as Label
	counter.add(5.0)
	counter.add(5.0)
	counter.commit()
	await runner.simulate_frames(30, 30)

	counter.add(2.0)
	await runner.simulate_frames(2, 20)
	assert_float(gain.scale.x).is_greater(1.0)

	assert_str(gain.text).is_equal("-1.0")
	assert_that(gain.get_theme_color(&"font_color")).is_equal(RatingCounter.DOWN_COLOR)
	assert_float(gain.modulate.a).is_equal(1.0)
	assert_float(counter.get_average()).is_equal_approx(4.0, 0.001)
	assert_str(label.text).is_equal("5.0")


func test_commit_moves_the_average_and_fades_the_gain_upward() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as RatingCounter
	var label := runner.find_child("AverageLabel") as Label
	var gain := runner.find_child("GainLabel") as Label
	counter.add(0.0)
	counter.commit()
	await runner.simulate_frames(30, 30)
	counter.add(5.0)
	assert_str(gain.text).is_equal("+2.5")
	assert_that(gain.get_theme_color(&"font_color")).is_equal(RatingCounter.UP_COLOR)
	await runner.simulate_frames(10, 30)
	var resting_y := gain.position.y

	counter.commit()
	await runner.simulate_frames(4, 30)
	# Still waiting out the delay.
	assert_str(label.text).is_equal("0.0")
	await runner.simulate_frames(60, 30)

	assert_str(label.text).is_equal("2.5")
	assert_float(gain.modulate.a).is_equal(0.0)
	assert_float(gain.position.y).is_less(resting_y)


func test_gain_text_rounds_to_a_tenth_with_its_sign() -> void:
	assert_str(RatingCounter.gain_text(0.26)).is_equal("+0.3")
	assert_str(RatingCounter.gain_text(-0.04)).is_equal("±0.0")
	assert_str(RatingCounter.gain_text(-1.5)).is_equal("-1.5")
	assert_that(RatingCounter.gain_color(0.01)).is_equal(RatingCounter.SAME_COLOR)


func test_a_rating_out_of_range_counts_as_the_nearest_end() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as RatingCounter

	counter.add(9.0)
	counter.add(-3.0)

	assert_float(counter.get_average()).is_equal_approx(2.5, 0.001)
