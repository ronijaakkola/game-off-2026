extends GdUnitTestSuite
## A hop near a moon: its window is open only while the moon is inside the star's hot zone,
## and it completes when the bus is at rest in the zone, or at the moon, while it is open.

const HOT := 6.6
const MOON_PERIOD := 50.0
const PLANET_PERIOD := 120.0

var _system: StarSystem
var _cinder: Planet
var _janus: Planet
var _passenger: Passenger
var _goal: WindowHopGoal


func before_test() -> void:
	_system = auto_free(StarSystem.new())
	_system.hot_zone_radius = HOT
	_cinder = Planet.new()
	_cinder.orbit_radius = 8.8
	_cinder.orbit_period = PLANET_PERIOD
	_janus = Planet.new()
	_janus.orbit_radius = 4.0
	_janus.orbit_period = MOON_PERIOD
	_cinder.add_child(_janus)
	_system.add_child(_cinder)
	add_child(_system)
	_cinder.set_process(false)
	_janus.set_process(false)
	_passenger = Passenger.new(PassengerType.new(), null, 100.0, 0.0)
	_goal = WindowHopGoal.new(_passenger, _janus)


func test_the_window_is_open_only_while_the_moon_is_in_the_hot_zone() -> void:
	_turn_moon(0.5)
	assert_bool(_goal.is_open()).is_true()

	_turn_moon(0.0)
	assert_bool(_goal.is_open()).is_false()


func test_the_window_opens_and_closes_when_it_says_it_will() -> void:
	_turn_moon(0.0)
	var opens := _goal.get_window_seconds()
	_advance(opens - 0.5)
	assert_bool(_goal.is_open()).is_false()
	_advance(1.0)
	assert_bool(_goal.is_open()).is_true()

	var closes := _goal.get_window_seconds()
	_advance(closes - 0.5)
	assert_bool(_goal.is_open()).is_true()
	_advance(1.0)
	assert_bool(_goal.is_open()).is_false()
	# A quarter of the moon's turn against its planet.
	assert_float(closes).is_between(18.0, 24.0)


func test_the_time_to_the_window_is_longer_while_the_orbits_run_slow() -> void:
	_turn_moon(0.0)
	var in_flight := _goal.get_window_seconds()

	_janus.orbit_speed = 0.5

	assert_float(_goal.get_window_seconds()).is_equal_approx(in_flight * 2.0, 0.01)


func test_coming_to_rest_in_the_zone_counts_only_while_the_window_is_open() -> void:
	_turn_moon(0.0)
	_goal.bus_held(_goal.get_spot() + Vector3.RIGHT, [_passenger])
	assert_bool(_goal.is_active()).is_true()

	_turn_moon(0.5)
	_goal.bus_held(_goal.get_spot() + Vector3.RIGHT * _goal.radius * 2.0, [_passenger])
	assert_bool(_goal.is_active()).is_true()
	_goal.bus_held(_goal.get_spot() + Vector3.RIGHT, [_passenger])
	assert_int(_goal.state).is_equal(Goal.State.COMPLETED)


func test_parking_at_the_moon_while_the_window_is_open_completes_it() -> void:
	_turn_moon(0.5)
	_goal.bus_stopped_at(_cinder, [_passenger])
	assert_bool(_goal.is_active()).is_true()

	_goal.bus_stopped_at(_janus, [_passenger])

	assert_int(_goal.state).is_equal(Goal.State.COMPLETED)


func test_parking_at_the_moon_outside_the_window_counts_for_nothing() -> void:
	_turn_moon(0.0)

	_goal.bus_stopped_at(_janus, [_passenger])

	assert_bool(_goal.is_active()).is_true()


# Puts the moon [param turns] of a turn round its planet from the side away from the star.
func _turn_moon(turns: float) -> void:
	_cinder.orbit_time = 0.0
	_janus.orbit_time = turns * MOON_PERIOD
	_place()


func _advance(seconds: float) -> void:
	_cinder.orbit_time += seconds
	_janus.orbit_time += seconds
	_place()


func _place() -> void:
	_cinder._process(0.0)
	_janus._process(0.0)
