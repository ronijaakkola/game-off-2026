extends GdUnitTestSuite
## How likely a capsule is to hold the castaway, through CapsuleField's public calls.


func test_the_castaway_gets_likelier_with_every_miss_until_certain() -> void:
	var field := auto_free(CapsuleField.new()) as CapsuleField
	field.passenger_chance = 0.1
	field.pity_step = 0.15

	assert_float(field.get_castaway_chance()).is_equal_approx(0.1, 0.001)
	field.castaway_misses = 3
	assert_float(field.get_castaway_chance()).is_equal_approx(0.55, 0.001)
	field.castaway_misses = 6
	assert_float(field.get_castaway_chance()).is_equal(1.0)
	field.castaway_misses = 20
	assert_float(field.get_castaway_chance()).is_equal(1.0)
