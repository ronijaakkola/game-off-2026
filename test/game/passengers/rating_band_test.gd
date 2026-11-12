extends GdUnitTestSuite
## Which band a recent rating is in.


func test_each_edge_starts_the_next_band_up() -> void:
	assert_int(RatingBand.of(0.0)).is_equal(0)
	for i: int in RatingBand.EDGES.size():
		var edge := RatingBand.EDGES[i]
		assert_int(RatingBand.of(edge - 0.01)).is_equal(i)
		assert_int(RatingBand.of(edge)).is_equal(i + 1)
	assert_int(RatingBand.of(Passenger.MAX_STARS)).is_equal(RatingBand.EDGES.size())
