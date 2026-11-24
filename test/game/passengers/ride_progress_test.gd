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


func test_a_passenger_s_save_keeps_their_ride() -> void:
	var kind := PassengerType.new()
	var planet := auto_free(Planet.new()) as Planet
	planet.name = &"Frost"
	var passenger := Passenger.new(kind, planet, 100.0, 50.0)
	passenger.depart()
	passenger.tick(6.0, false)
	passenger.pass_stop(auto_free(Planet.new()) as Planet)
	var types: Dictionary[String, PassengerType] = {kind.resource_path: kind}
	var planets: Dictionary[String, Planet] = {"Frost": planet}
	var loaded := Passenger.from_save(passenger.to_save(), types, planets)
	assert_float(loaded.ride.clock).is_equal(6.0)
	assert_int(loaded.ride.stops).is_equal(1)
