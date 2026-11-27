extends GdUnitTestSuite
## An unstable star's swell: it holds at rest until started, then swells out to its widest,
## the hot zone with it, shrinks back and comes again; held, it goes back to rest; a stable
## star never swells. Driven frame by frame with a fixed step.

const STEP := 0.1
const MAX_STEPS := 3000

var _star: StarSystem


func before_test() -> void:
	_star = auto_free(StarSystem.new()) as StarSystem
	_star.zone_radius = 6.6
	_star.hot_zone_radius = 4.8
	_star.swell_zone_radius = 14.9
	_star.swell_hot_zone_radius = 9.0
	add_child(_star)
	_star.set_process(false)


func test_an_unstable_star_holds_at_rest_until_started_then_swells_and_comes_back() -> void:
	assert_bool(_stays_at_rest(_cycle_seconds() * 2.0)).is_true()

	_star.start_swell()
	assert_bool(_step_until(func() -> bool: return _star.get_swell() == 1.0)).is_true()
	assert_float(_star.get_zone_radius()).is_equal_approx(14.9, 0.001)
	assert_float(_star.get_hot_zone_radius()).is_equal_approx(9.0, 0.001)

	assert_bool(_step_until(func() -> bool: return _star.get_swell() == 0.0)).is_true()
	assert_float(_star.get_zone_radius()).is_equal(6.6)
	assert_float(_star.get_hot_zone_radius()).is_equal(4.8)

	assert_bool(_step_until(func() -> bool: return _star.get_swell() > 0.0)).is_true()


func test_held_it_goes_back_to_rest_and_stays() -> void:
	_star.start_swell()
	assert_bool(_step_until(func() -> bool: return _star.get_swell() == 1.0)).is_true()

	_star.hold_swell()
	assert_bool(_stays_at_rest(_cycle_seconds() * 2.0)).is_true()


func test_a_stable_star_never_swells() -> void:
	_star.swell_zone_radius = 0.0
	_star.start_swell()
	assert_bool(_stays_at_rest(_cycle_seconds() * 2.0)).is_true()


func _cycle_seconds() -> float:
	return (
		_star.swell_rest_seconds
		+ _star.swell_grow_seconds
		+ _star.swell_hold_seconds
		+ _star.swell_shrink_seconds
	)


# Steps through [param seconds]. Whether both zones stayed at rest throughout.
func _stays_at_rest(seconds: float) -> bool:
	for i: int in roundi(seconds / STEP):
		_star._process(STEP)
		if _star.get_zone_radius() != 6.6 or _star.get_hot_zone_radius() != 4.8:
			return false
	return true


# Steps until [param done] holds, or gives up after MAX_STEPS. Whether it held.
func _step_until(done: Callable) -> bool:
	for i: int in MAX_STEPS:
		_star._process(STEP)
		if done.call():
			return true
	return false
