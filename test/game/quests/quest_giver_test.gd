extends GdUnitTestSuite
## Quests in the solar system: what ends one as the bus docks, what that costs the
## passenger who asked, and that one under way comes back from a save.

const SCENE := "res://game/solar_system/solar_system.tscn"


func test_docking_at_their_destination_first_fails_an_errand_before_they_rate() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var giver := runner.find_child("QuestGiver") as QuestGiver
	var passenger := await _board_someone(runner)
	var quest := _errand(passenger, _other_planet(runner, passenger, bus))
	giver.take_on(quest)
	var before := passenger.happiness

	bus.docked.emit(passenger.destination)

	assert_int(quest.goal.state).is_equal(Goal.State.FAILED)
	assert_float(passenger.happiness).is_equal_approx(before + QuestGiver.FAIL_SHOCK, 0.01)


func test_docking_at_the_errand_completes_it_and_they_ride_on_with_no_stop_counted() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var cabin := runner.find_child("Cabin") as Cabin
	var bus := runner.find_child("Bus") as FrameshiftBus
	var giver := runner.find_child("QuestGiver") as QuestGiver
	var passenger := await _board_someone(runner)
	passenger.depart()
	var quest := _errand(passenger, _other_planet(runner, passenger, bus))
	giver.take_on(quest)
	var ledger := (runner.scene() as SolarSystem).get_ledger()
	var credits := ledger.credits

	bus.docked.emit(quest.planet)

	assert_int(quest.goal.state).is_equal(Goal.State.COMPLETED)
	assert_array(cabin.get_passengers()).contains([passenger])
	assert_int(passenger.ride.stops).is_equal(0)
	assert_int(ledger.credits).is_equal(credits + ErrandQuest.REWARD_CREDITS[0])


func test_a_fly_past_and_an_errand_come_back_from_a_save() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var passenger := await _board_someone(runner)
	var planet := _other_planet(runner, passenger, bus)
	var by_name: Dictionary[String, Planet] = {String(planet.name): planet}
	var flyby := FlybyQuest.new()
	flyby.passenger = passenger
	flyby.planet = planet
	flyby.accept()
	var quests: Array[Quest] = [flyby, _errand(passenger, planet)]
	for quest: Quest in quests:
		var saved := quest.to_save()
		var back: Quest = ErrandQuest.new()
		if saved["kind"] == FlybyQuest.KIND:
			back = FlybyQuest.new()

		assert_bool(back.restore(saved, passenger, by_name)).is_true()

		assert_object(back.get_planet()).is_same(planet)
		assert_str(back.goal.get_text()).is_equal(quest.goal.get_text())
		assert_int(back.reward_credits).is_equal(quest.reward_credits)


# Someone waiting where the bus is docked, on board, with nobody calling meanwhile.
func _board_someone(runner: GdUnitSceneRunner) -> Passenger:
	var cabin := runner.find_child("Cabin") as Cabin
	var bus := runner.find_child("Bus") as FrameshiftBus
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	(runner.find_child("QuestGiver") as QuestGiver).enabled = false
	var passenger := waiting.create(bus.get_docked_planet())
	cabin.board(passenger)
	await runner.simulate_frames(2)
	return passenger


# An errand quest [param who] asked for at [param planet], accepted.
func _errand(who: Passenger, planet: Planet) -> ErrandQuest:
	var quest := ErrandQuest.new()
	quest.passenger = who
	quest.planet = planet
	quest.reward_credits = ErrandQuest.REWARD_CREDITS[0]
	quest.reward_research = ErrandQuest.REWARD_RESEARCH[0]
	quest.accept()
	return quest


# A planet that isn't where [param who] is going or where [param bus] is docked.
func _other_planet(runner: GdUnitSceneRunner, who: Passenger, bus: FrameshiftBus) -> Planet:
	for planet_name: String in ["Frost", "Giant", "Terra"]:
		var planet := runner.find_child(planet_name) as Planet
		if planet != who.destination and planet != bus.get_docked_planet():
			return planet
	return null
