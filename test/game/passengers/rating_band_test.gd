extends GdUnitTestSuite
## Which band a recent rating is in, and what the player reads about it.


func test_each_edge_starts_the_next_band_up() -> void:
	assert_int(RatingBand.of(0.0)).is_equal(0)
	for i: int in RatingBand.EDGES.size():
		var edge := RatingBand.EDGES[i]
		assert_int(RatingBand.of(edge - 0.01)).is_equal(i)
		assert_int(RatingBand.of(edge)).is_equal(i + 1)
	assert_int(RatingBand.of(Passenger.MAX_STARS)).is_equal(RatingBand.EDGES.size())


func test_every_band_but_the_top_says_where_the_next_one_starts() -> void:
	for i: int in RatingBand.EDGES.size():
		var below := RatingBand.EDGES[i] - 0.01
		assert_str(RatingBand.describe(below)).contains(RatingBand.NEXT_BRINGS)
	assert_str(RatingBand.describe(Passenger.MAX_STARS)).not_contains(RatingBand.NEXT_BRINGS)
