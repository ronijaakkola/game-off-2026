extends GdUnitTestSuite
## Quests in the solar system: what ends one as the bus docks, what that costs the
## passenger who asked, and that one of any kind under way comes back from a save.

const SCENE := "res://game/solar_system/solar_system.tscn"
const VIP_TOUR := preload("res://game/quests/vip_tour_quest.gd")


func test_docking_at_their_destination_first_fails_an_errand_before_they_rate() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var giver := runner.find_child("QuestGiver") as QuestGiver
	var passenger := await _board_someone(runner)
	var quest := _errand(passenger, _other_planet(runner, passenger, bus))
	giver.take_on(quest)
	# Arriving pays out their timing as well, so the shock is what's left after it.
	var before := passenger.happiness + passenger.ride.get_timing()

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
	var happiness := passenger.happiness
	var target := passenger.get_target()

	bus.docked.emit(quest.planet)

	assert_int(quest.goal.state).is_equal(Goal.State.COMPLETED)
	assert_array(cabin.get_passengers()).contains([passenger])
	assert_int(passenger.ride.stops).is_equal(0)
	# Only that stop is free: coming back there counts as any other stop.
	passenger.pass_stop(quest.planet)
	assert_int(passenger.ride.stops).is_equal(1)
	assert_int(ledger.credits).is_equal(credits + ErrandQuest.REWARD_CREDITS[0])
	# A done quest lifts them at once, and what they can reach for the rest of the ride.
	assert_float(passenger.happiness).is_equal_approx(happiness + giver.done_happiness, 0.01)
	assert_float(passenger.get_target()).is_equal_approx(target + giver.done_happiness, 0.01)


func test_docking_where_an_express_quest_sent_them_completes_it_before_they_rate() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var giver := runner.find_child("QuestGiver") as QuestGiver
	var passenger := await _board_someone(runner)
	passenger.depart()
	var quest := ExpressQuest.new()
	quest.passenger = passenger
	quest.planet = _other_planet(runner, passenger, bus)
	quest.trip_seconds = passenger.ride.trip_seconds
	quest.accept()
	giver.take_on(quest)
	var before := passenger.happiness + passenger.ride.get_timing()

	bus.docked.emit(quest.planet)

	assert_int(quest.goal.state).is_equal(Goal.State.COMPLETED)
	assert_float(passenger.happiness).is_equal_approx(before + giver.done_happiness, 0.01)


func test_every_kind_of_quest_under_way_comes_back_from_a_save() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var cabin := runner.find_child("Cabin") as Cabin
	var giver := runner.find_child("QuestGiver") as QuestGiver
	var passenger := await _board_someone(runner)
	var planet := _other_planet(runner, passenger, bus)
	var by_name: Dictionary[String, Planet] = {String(planet.name): planet}
	var on_board := cabin.get_passengers()
	# A tour last: it stays under way in a slot of its own, beside the others.
	var kinds := QuestKinds.ALL.filter(func(kind: GDScript) -> bool: return kind != VIP_TOUR)
	kinds.append(VIP_TOUR)
	for script: GDScript in kinds:
		var quest := script.new() as Quest
		quest.passenger = passenger
		if quest is FlybyQuest:
			(quest as FlybyQuest).planet = planet
		elif quest is ErrandQuest:
			(quest as ErrandQuest).planet = planet
		elif quest is ExpressQuest:
			(quest as ExpressQuest).planet = planet
		passenger.tour = Tour.new([passenger.destination]) if quest is VipTourQuest else null
		quest.reward_credits = 100
		quest.accept()
		if quest is VipTourQuest:
			# A save keeps a tour only once they are on board.
			(quest.goal as VipTourGoal).boarded = true
		giver.take_on(quest)
		var saved := giver.to_save(on_board)
		cabin.fondness.forget(passenger)

		giver.load_save(saved, on_board, by_name)

		var back := giver.get_tour() if quest is VipTourQuest else giver.get_quest()
		assert_object(back).is_not_same(quest)
		assert_object(back.get_script()).is_same(script)
		assert_object(back.get_planet()).is_same(quest.get_planet())
		assert_str(back.goal.get_text()).is_equal(quest.goal.get_text())
		assert_int(back.reward_credits).is_equal(100)
		var rocks := cabin.fondness.has(passenger, Fondness.Kind.ROCKS)
		assert_bool(rocks).is_equal(quest is RockRideQuest)
		var heat := cabin.fondness.has(passenger, Fondness.Kind.HEAT)
		assert_bool(heat).is_equal(quest is SaunaQuest)


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
