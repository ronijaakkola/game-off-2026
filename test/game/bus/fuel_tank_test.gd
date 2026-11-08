extends GdUnitTestSuite
## The fuel tank's capacity following a stat as upgrades change it.


func test_the_capacity_follows_its_stat_and_a_smaller_tank_spills_what_no_longer_fits() -> void:
	var tank := auto_free(FuelTank.new()) as FuelTank
	add_child(tank)
	var stat := Stat.new()

	tank.follow(stat)
	assert_float(stat.base).is_equal(100.0)

	stat.add_modifier(_percent(50.0))
	assert_float(tank.capacity).is_equal_approx(150.0, 0.0001)
	# The new room starts empty.
	assert_float(tank.fuel).is_equal(100.0)

	stat.add_modifier(_percent(-100.0))
	assert_float(tank.capacity).is_equal_approx(50.0, 0.0001)
	assert_float(tank.fuel).is_equal_approx(50.0, 0.0001)


func _percent(amount: float) -> StatModifier:
	return StatModifier.new(BusStats.Type.FUEL_CAPACITY, StatModifier.Kind.PERCENT, amount)
