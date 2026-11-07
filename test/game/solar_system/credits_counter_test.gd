extends GdUnitTestSuite
## The credits in the top right: a payment counts the total up and shows what was paid
## under it, which fades away.

const SCENE := "res://game/solar_system/credits_counter.tscn"


func test_a_payment_counts_up_and_shows_the_gain_then_fades() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as CreditsCounter
	counter.credits = 10
	var total := runner.find_child("TotalLabel") as Label
	var gain := runner.find_child("GainLabel") as Label
	assert_str(total.text).is_equal("10 credits")
	assert_float(gain.modulate.a).is_equal(0.0)

	counter.add(15)

	assert_int(counter.credits).is_equal(25)
	await runner.simulate_frames(20, 30)
	assert_str(total.text).is_equal("25 credits")
	assert_str(gain.text).is_equal("+15")
	assert_float(gain.modulate.a).is_equal(1.0)
	await runner.simulate_frames(40, 50)
	assert_float(gain.modulate.a).is_equal(0.0)


func test_payments_close_together_add_up_in_one_gain() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as CreditsCounter

	counter.add(15)
	await runner.simulate_frames(10, 30)
	counter.add(12)
	await runner.simulate_frames(20, 30)

	assert_str((runner.find_child("GainLabel") as Label).text).is_equal("+27")
	assert_str((runner.find_child("TotalLabel") as Label).text).is_equal("27 credits")
