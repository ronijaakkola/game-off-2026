extends GdUnitTestSuite
## The temperature's rules: where it rises and falls, overheating, the cooldown and the easy
## way out after it.

const STEP := 0.1

var _temperature: BusTemperature


func before_test() -> void:
	_temperature = auto_free(BusTemperature.new()) as BusTemperature
	add_child(_temperature)


func test_it_starts_at_rest_and_never_falls_below_it() -> void:
	assert_float(_temperature.temperature).is_equal(_temperature.rest_temperature)
	_advance(5.0, 100.0, true)
	assert_float(_temperature.temperature).is_equal(_temperature.rest_temperature)
	_temperature.set_temperature(-40.0)
	assert_float(_temperature.temperature).is_equal(_temperature.rest_temperature)


func test_flying_heats_it_faster_the_nearer_the_star() -> void:
	var t := _temperature
	assert_float(t.get_rise_rate(t.zone_radius)).is_equal(0.0)
	var outer := t.get_rise_rate(t.zone_radius - 0.5)
	var hot := t.get_rise_rate(t.hot_zone_radius - 0.5)
	assert_float(outer).is_greater(0.0)
	assert_float(hot).is_greater(outer)
	assert_float(t.get_rise_rate(t.star_radius)).is_equal(t.surface_rate)


func test_in_the_heat_zone_it_rises_slowly_docked_and_holds_stopped_in_space() -> void:
	var inside := _temperature.zone_radius - 1.0
	_advance(10.0, inside, false, false, true)
	var docked := _temperature.temperature
	assert_float(docked).is_equal_approx(
		_temperature.rest_temperature + _temperature.docked_rate * 10.0, 0.01
	)
	_advance(10.0, inside, false)
	assert_float(_temperature.temperature).is_equal(docked)


func test_outside_the_heat_zone_it_falls_back_to_rest() -> void:
	_temperature.set_temperature(40.0)
	_advance(1.0, _temperature.zone_radius, true)
	assert_float(_temperature.temperature).is_equal_approx(40.0 - _temperature.fall_rate, 0.01)
	_advance(30.0, _temperature.zone_radius, true)
	assert_float(_temperature.temperature).is_equal(_temperature.rest_temperature)


func test_it_overheats_once_and_cools_back_to_rest_over_the_cooldown() -> void:
	var t := _temperature
	var overheats := [0]
	t.overheated.connect(func() -> void: overheats[0] += 1)
	t.set_temperature(t.overheat_temperature + 5.0)
	assert_float(t.temperature).is_equal(t.overheat_temperature)
	assert_bool(t.is_cooling()).is_true()
	# Heating while cooling does nothing.
	t.set_temperature(t.overheat_temperature)
	assert_int(overheats[0]).is_equal(1)
	_advance(t.cooldown_time * 0.5, t.star_radius, true)
	assert_float(t.temperature).is_equal_approx(
		lerpf(t.overheat_temperature, t.rest_temperature, 0.5), 0.5
	)
	_advance(t.cooldown_time * 0.5 + STEP, t.star_radius, true)
	assert_bool(t.is_cooling()).is_false()
	assert_float(t.temperature).is_equal(t.rest_temperature)


func test_while_exempt_it_holds_but_a_cooldown_goes_on() -> void:
	var t := _temperature
	_advance(5.0, t.hot_zone_radius, true, false, false, true)
	assert_float(t.temperature).is_equal(t.rest_temperature)
	t.set_temperature(t.overheat_temperature)
	_advance(t.cooldown_time + STEP, t.hot_zone_radius, true, false, false, true)
	assert_bool(t.is_cooling()).is_false()


func test_after_a_cooldown_heading_out_heats_it_a_little_until_it_leaves_the_zone() -> void:
	var t := _temperature
	var inside := t.hot_zone_radius - 0.5
	t.set_temperature(t.overheat_temperature)
	_advance(t.cooldown_time + STEP, inside, false)
	assert_bool(t.is_escaping()).is_true()
	_advance(1.0, inside, true, true)
	var out := t.temperature - t.rest_temperature
	assert_float(out).is_equal_approx(t.get_rise_rate(inside) * t.escape_share, 0.01)
	# Heading back in heats it as usual.
	var before := t.temperature
	_advance(1.0, inside, true, false)
	assert_float(t.temperature - before).is_equal_approx(t.get_rise_rate(inside), 0.01)
	# Out of the zone, the easy way out is over.
	_advance(STEP, t.zone_radius, true, true)
	assert_bool(t.is_escaping()).is_false()


func _advance(
	seconds: float,
	distance: float,
	flying: bool,
	heading_out := false,
	docked := false,
	exempt := false
) -> void:
	for i: int in roundi(seconds / STEP):
		_temperature.advance(STEP, distance, flying, heading_out, docked, exempt)
