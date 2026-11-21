extends GdUnitTestSuite
## How a ride stands, through RideProgress's public calls.


func test_a_saved_ride_comes_back_where_it_stood() -> void:
	var ride := RideProgress.new(100.0, 150.0, 2)
	ride.run(40.0, 0.0)
	ride.leeway = 3.0
	ride.stops = 1
	var loaded := RideProgress.new(100.0, 100.0, 2)
	loaded.load_save(ride.to_save())
	assert_float(loaded.expected_seconds).is_equal(150.0)
	assert_float(loaded.clock).is_equal(40.0)
	assert_float(loaded.leeway).is_equal(3.0)
	assert_int(loaded.stops).is_equal(1)
