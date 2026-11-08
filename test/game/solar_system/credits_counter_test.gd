extends GdUnitTestSuite
## The credits in the resource bar: payments collect in a gain under the total that pops with
## each one, and on commit the total counts up to include them while the gain fades away.

const SCENE := "res://game/solar_system/credits_counter.tscn"


func test_payments_add_up_in_the_gain_and_pop_while_the_total_waits() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as CreditsCounter
	counter.credits = 10
	var total := runner.find_child("TotalLabel") as Label
	var gain := runner.find_child("GainLabel") as Label
	assert_float(gain.modulate.a).is_equal(0.0)

	counter.add(15)
	await runner.simulate_frames(2, 20)
	assert_float(gain.scale.x).is_greater(1.0)
	await runner.simulate_frames(20, 30)
	assert_float(gain.scale.x).is_equal_approx(1.0, 0.01)
	counter.add(12)

	assert_str(gain.text).is_equal("+27")
	assert_float(gain.modulate.a).is_equal(1.0)
	assert_int(counter.credits).is_equal(37)
	await runner.simulate_frames(60, 30)
	assert_str(total.text).is_equal("10")


func test_commit_counts_the_total_up_one_by_one_and_fades_the_gain_upward() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as CreditsCounter
	var total := runner.find_child("TotalLabel") as Label
	var gain := runner.find_child("GainLabel") as Label
	counter.add(20)
	await runner.simulate_frames(10, 30)
	var resting_y := gain.position.y
	var shown: Array[String] = []
	total.draw.connect(func() -> void: shown.append(total.text))

	counter.commit()
	await runner.simulate_frames(4, 30)
	# Still waiting out the delay.
	assert_str(total.text).is_equal("0")
	await runner.simulate_frames(80, 30)

	assert_str(total.text).is_equal("20")
	assert_float(gain.modulate.a).is_equal(0.0)
	assert_float(gain.position.y).is_less(resting_y)
	# It went through the numbers in between, not straight to 20.
	assert_int(shown.size()).is_greater(5)


func test_commit_with_nothing_paid_changes_nothing() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as CreditsCounter
	counter.credits = 5

	counter.commit()
	await runner.simulate_frames(30, 30)

	assert_str((runner.find_child("TotalLabel") as Label).text).is_equal("5")
	assert_float((runner.find_child("GainLabel") as Label).modulate.a).is_equal(0.0)


func test_spending_shows_a_red_loss_and_counts_the_total_down() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as CreditsCounter
	counter.credits = 50
	var total := runner.find_child("TotalLabel") as Label
	var loss := runner.find_child("LossLabel") as Label

	counter.spend(12)

	assert_int(counter.credits).is_equal(38)
	assert_str(loss.text).is_equal("-12")
	assert_float(loss.modulate.a).is_equal(1.0)
	assert_str(total.text).is_equal("50")
	await runner.simulate_frames(60, 30)
	assert_str(total.text).is_equal("38")
	assert_float(loss.modulate.a).is_equal(0.0)


func test_spending_again_while_the_loss_shows_adds_to_it() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as CreditsCounter
	counter.credits = 50
	var total := runner.find_child("TotalLabel") as Label
	var loss := runner.find_child("LossLabel") as Label
	counter.spend(12)
	await runner.simulate_frames(5, 30)

	counter.spend(20)

	assert_str(loss.text).is_equal("-32")
	await runner.simulate_frames(60, 30)
	assert_str(total.text).is_equal("18")
	counter.spend(3)
	assert_str(loss.text).is_equal("-3")


func test_spending_leaves_a_waiting_gain_and_shows_under_it() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as CreditsCounter
	counter.credits = 50
	var total := runner.find_child("TotalLabel") as Label
	var gain := runner.find_child("GainLabel") as Label
	var loss := runner.find_child("LossLabel") as Label
	counter.add(10)

	counter.spend(15)
	await runner.simulate_frames(1)

	assert_int(counter.credits).is_equal(45)
	assert_str(gain.text).is_equal("+10")
	assert_float(loss.position.y).is_greater_equal(gain.size.y - 1.0)
	await runner.simulate_frames(60, 30)
	assert_str(total.text).is_equal("35")
	counter.commit()
	await runner.simulate_frames(80, 30)
	assert_str(total.text).is_equal("45")


func test_spending_during_a_count_up_ends_it_at_the_new_total() -> void:
	var runner := scene_runner(SCENE)
	var counter := runner.scene() as CreditsCounter
	var total := runner.find_child("TotalLabel") as Label
	counter.add(40)
	counter.commit()
	await runner.simulate_frames(15, 30)

	counter.spend(5)
	await runner.simulate_frames(80, 30)

	assert_int(counter.credits).is_equal(35)
	assert_str(total.text).is_equal("35")
