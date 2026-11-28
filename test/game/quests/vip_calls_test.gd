extends GdUnitTestSuite
## VIPs in the solar system: a passenger's quest and a VIP's tour run side by side and both
## come back from a save, and VIPs unlock from a save with enough deliveries.

const SCENE := "res://game/solar_system/solar_system.tscn"


func test_a_quest_and_a_tour_run_side_by_side_and_both_come_back_from_a_save() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var bus := runner.find_child("Bus") as FrameshiftBus
	var cabin := runner.find_child("Cabin") as Cabin
	var giver := runner.find_child("QuestGiver") as QuestGiver
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	giver.enabled = false
	var commuter := waiting.create(bus.get_docked_planet())
	cabin.board(commuter)
	var vip := waiting.create(bus.get_docked_planet())
	vip.type = Vip.TYPE
	vip.tour = Tour.new([vip.destination])
	cabin.board(vip)
	await runner.simulate_frames(2)
	var errand_at := _other_planet(runner, [commuter.destination, vip.destination], bus)
	var tour := VipTourQuest.new()
	tour.passenger = vip
	tour.accept()
	(tour.goal as VipTourGoal).boarded = true
	giver.take_on(tour)
	var errand := _errand(commuter, errand_at)
	giver.take_on(errand)

	assert_object(giver.get_quest()).is_same(errand)
	assert_object(giver.get_tour()).is_same(tour)
	assert_bool(giver.can_rescue()).override_failure_message("a quest is under way").is_false()

	bus.docked.emit(errand_at)

	assert_int(errand.goal.state).is_equal(Goal.State.COMPLETED)
	assert_object(giver.get_quest()).is_null()
	assert_object(giver.get_tour()).override_failure_message("the tour ended too").is_same(tour)

	giver.take_on(_errand(commuter, errand_at))
	var saved := giver.to_save(cabin.get_passengers())
	var by_name: Dictionary[String, Planet] = {String(errand_at.name): errand_at}
	giver.load_save(saved, cabin.get_passengers(), by_name)

	assert_int(saved.size()).is_equal(2)
	assert_object(giver.get_quest()).is_instanceof(ErrandQuest)
	assert_object(giver.get_tour()).is_not_same(tour)
	assert_object(giver.get_tour().passenger).is_same(vip)


func test_vips_unlock_from_a_save_once_enough_were_delivered() -> void:
	var vips := auto_free(VipCalls.new()) as VipCalls
	var ledger := Ledger.new()
	for i: int in 10:
		ledger.rate(4.0)
	vips.start([], ledger, null, VipCalls.LEVEL)
	var heard: Array[bool] = []
	vips.unlocked.connect(func() -> void: heard.append(true))

	vips.load_save({"delivered": VipCalls.FIRST_DELIVERIES - 1})

	assert_bool(vips.is_unlocked()).is_false()

	vips.load_save({"delivered": VipCalls.FIRST_DELIVERIES})

	assert_bool(vips.is_unlocked()).is_true()
	assert_int(heard.size()).is_equal(1)


func test_vips_never_unlock_outside_their_star_system() -> void:
	var vips := auto_free(VipCalls.new()) as VipCalls
	var ledger := Ledger.new()
	for i: int in 10:
		ledger.rate(4.0)
	vips.start([], ledger, null, VipCalls.LEVEL - 1)

	vips.load_save({"delivered": VipCalls.FIRST_DELIVERIES})

	assert_bool(vips.is_unlocked()).is_false()


func _errand(who: Passenger, at: Planet) -> ErrandQuest:
	var quest := ErrandQuest.new()
	quest.passenger = who
	quest.planet = at
	quest.accept()
	return quest


func _other_planet(
	runner: GdUnitSceneRunner, not_these: Array[Planet], bus: FrameshiftBus
) -> Planet:
	for planet_name: String in ["Frost", "Giant", "Terra", "Moon"]:
		var planet := runner.find_child(planet_name) as Planet
		if planet and planet not in not_these and planet != bus.get_docked_planet():
			return planet
	return null
