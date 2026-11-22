extends GdUnitTestSuite
## The frameshift drive's charge, warmth and quick stop, stepped by hand.

const STEP := 0.05
const CHARGE := 3.0
const QUICK := 7.0
const WARM_CHARGE := 0.5

var _drive: FrameshiftDrive


func before_test() -> void:
	_drive = FrameshiftDrive.new(CHARGE, QUICK, WARM_CHARGE)


func test_a_warm_charge_takes_the_part_of_the_warm_charge_time_the_warmth_lacks() -> void:
	# Docked 3.5 s of 7: half warm, so a quarter of a second.
	_drive.begin_stop(true, true)
	_drive.wait(QUICK * 0.5)
	assert_float(_drive.get_time_left()).is_equal_approx(WARM_CHARGE * 0.5, 0.001)
	_drive.held = true
	_drive.start()
	_advance(WARM_CHARGE * 0.5 - STEP)
	assert_bool(_drive.is_charged()).is_false()
	_advance(STEP * 2.0)
	assert_bool(_drive.is_charged()).is_true()
	assert_bool(_drive.is_quick_stop()).is_true()
	# Held the moment the stop's clock starts, it is charged at once.
	_drive.begin_stop(true, true)
	_drive.start()
	assert_bool(_drive.is_charged()).is_true()


func test_without_the_warm_drive_it_is_cold_and_a_charge_takes_the_whole_charge_time() -> void:
	_drive.begin_stop(true, false)
	assert_bool(_drive.is_warm()).is_false()
	_drive.held = true
	_drive.start()
	_advance(CHARGE - STEP)
	assert_bool(_drive.is_charged()).is_false()
	_advance(STEP * 2.0)
	assert_bool(_drive.is_charged()).is_true()


func test_letting_go_of_a_warm_charge_drains_it_fast_and_leaves_it_cold() -> void:
	_drive.begin_stop(true, true)
	_drive.wait(QUICK * 0.9)
	_drive.held = true
	_drive.start()
	_advance(STEP)

	_drive.held = false

	# Nearly full, it drains at four times a cold charge's build: under 0.75 s.
	_advance(0.75)
	assert_bool(_drive.is_drained()).is_true()
	assert_bool(_drive.is_warm()).is_false()
	assert_bool(_drive.is_warm_charge()).is_false()
	# Past the quick stop's time, a new charge is cold and no quick stop.
	_drive.wait(QUICK * 0.1 + STEP)
	_drive.held = true
	_drive.start()
	assert_float(_drive.get_time_left()).is_equal(CHARGE)
	assert_bool(_drive.is_quick_stop()).is_false()


func test_the_quick_stop_runs_out_after_its_time() -> void:
	_drive.begin_stop(true, false)
	assert_bool(_drive.is_quick_stop()).is_true()
	_drive.wait(QUICK - STEP)
	assert_bool(_drive.is_quick_stop()).is_true()
	_drive.wait(STEP * 2.0)
	assert_bool(_drive.is_quick_stop()).is_false()


func test_towed_in_or_ended_early_there_is_no_quick_stop() -> void:
	_drive.begin_stop(false, true)
	assert_bool(_drive.is_warm()).is_false()
	assert_bool(_drive.is_quick_stop()).is_false()

	_drive.begin_stop(true, true)
	_drive.end_stop()

	assert_bool(_drive.is_warm()).is_false()
	assert_bool(_drive.is_quick_stop()).is_false()


func _advance(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		_drive.advance(minf(STEP, left))
		left -= STEP
