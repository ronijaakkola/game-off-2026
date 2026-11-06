extends GdUnitTestSuite
## Passengers in the solar system: one on board at the start, and docking lets off those
## going there and takes on those waiting.

const SCENE := "res://game/solar_system/solar_system.tscn"


func test_starts_with_one_passenger_on_board() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var cabin := runner.find_child("Cabin") as Cabin
	assert_int(cabin.get_passengers().size()).is_equal(1)
	assert_int((runner.find_child("Cards") as Control).get_child_count()).is_equal(1)


func test_docking_at_a_destination_lets_them_off_and_pays() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var cabin := runner.find_child("Cabin") as Cabin
	var bus := runner.find_child("Bus") as FrameshiftBus
	var passenger := cabin.get_passengers()[0]
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	waiting.take(passenger.destination, 99)
	waiting.add(passenger.destination)

	bus.docked.emit(passenger.destination)

	assert_array(cabin.get_passengers()).not_contains([passenger])
	assert_int(cabin.get_passengers().size()).is_equal(1)
	var credits := (runner.find_child("CreditsLabel") as Label).text
	assert_str(credits).is_equal("%d credits" % passenger.get_payout())
