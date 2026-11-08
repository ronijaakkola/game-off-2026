extends GdUnitTestSuite
## A stat's value from its base and modifiers: the base plus every flat modifier, times one
## plus every percent added together.


func test_with_no_modifiers_the_value_is_the_base() -> void:
	assert_float(Stat.new(8.0).get_value()).is_equal(8.0)


func test_flat_modifiers_add_to_the_base() -> void:
	var stat := Stat.new(8.0)
	stat.add_modifier(_flat(5.0))
	stat.add_modifier(_flat(-2.0))
	assert_float(stat.get_value()).is_equal_approx(11.0, 0.0001)


func test_percents_add_together_instead_of_compounding() -> void:
	var stat := Stat.new(8.0)
	stat.add_modifier(_percent(10.0))
	stat.add_modifier(_percent(20.0))
	assert_float(stat.get_value()).is_equal_approx(8.0 * 1.3, 0.0001)


func test_flat_modifiers_apply_before_percents() -> void:
	var stat := Stat.new(8.0)
	stat.add_modifier(_percent(10.0))
	stat.add_modifier(_flat(5.0))
	stat.add_modifier(_percent(20.0))
	assert_float(stat.get_value()).is_equal_approx((8.0 + 5.0) * 1.3, 0.0001)


func test_removing_a_modifier_takes_it_back_out() -> void:
	var stat := Stat.new(8.0)
	var boost := _percent(50.0)
	stat.add_modifier(_flat(2.0))
	stat.add_modifier(boost)
	stat.remove_modifier(boost)
	assert_float(stat.get_value()).is_equal_approx(10.0, 0.0001)


func test_a_new_base_keeps_the_modifiers() -> void:
	var stat := Stat.new(8.0)
	stat.add_modifier(_flat(2.0))
	stat.add_modifier(_percent(50.0))
	stat.base = 4.0
	assert_float(stat.get_value()).is_equal_approx(9.0, 0.0001)


func test_the_value_never_goes_below_zero() -> void:
	var stat := Stat.new(3.0)
	stat.add_modifier(_percent(-150.0))
	assert_float(stat.get_value()).is_equal(0.0)


func test_changed_is_emitted_when_the_value_changes() -> void:
	var stat := Stat.new(8.0)
	monitor_signals(stat, false)
	stat.add_modifier(_flat(1.0))
	await assert_signal(stat).is_emitted("changed")


func _flat(amount: float) -> StatModifier:
	return StatModifier.new(BusStats.Type.MAX_SPEED, StatModifier.Kind.FLAT, amount)


func _percent(amount: float) -> StatModifier:
	return StatModifier.new(BusStats.Type.MAX_SPEED, StatModifier.Kind.PERCENT, amount)
