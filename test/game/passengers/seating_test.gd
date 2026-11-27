extends GdUnitTestSuite
## Seats in the solar system: a VIP takes two, and picking one up on a bus with too few
## free kicks passengers off to make room, one at a time, with no shock to the rest.

const SCENE := "res://game/solar_system/solar_system.tscn"


func test_a_vip_takes_two_seats() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var cabin := runner.find_child("Cabin") as Cabin
	var vip := _vip(runner)

	cabin.board(vip)

	assert_int(cabin.get_free_seats()).is_equal(cabin.seats - 2)


func test_a_vip_on_a_full_bus_kicks_two_one_after_the_other_and_nobody_else_is_shocked() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var cabin := _fill(runner, 0)
	var kicked: Array[Passenger] = []
	cabin.kicked.connect(func(passenger: Passenger) -> void: kicked.append(passenger))
	var vip := _vip(runner)

	assert_bool(Seating.fits(vip, cabin)).is_false()
	assert_bool(Seating.can_pick_up(cabin, vip)).is_true()
	Seating.pick_up(cabin, vip)

	assert_int(kicked.size()).override_failure_message("the first goes at once").is_equal(1)
	var stayed := cabin.get_passengers().filter(func(p: Passenger) -> bool: return p not in kicked)
	var before := stayed.map(func(p: Passenger) -> float: return p.happiness)
	await runner.simulate_frames(30, 50)
	assert_int(kicked.size()).is_equal(2)
	await runner.simulate_frames(30, 50)
	assert_bool(vip in cabin.get_passengers()).is_true()
	assert_int(Seating.count(cabin.get_passengers())).is_equal(cabin.seats)
	for i: int in stayed.size():
		var stayer := stayed[i] as Passenger
		if stayer not in kicked:
			assert_float(stayer.happiness).is_greater_equal(float(before[i]) - 1.0)


func test_a_vip_with_one_seat_free_kicks_one() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var cabin := _fill(runner, 1)
	var kicked: Array[Passenger] = []
	cabin.kicked.connect(func(passenger: Passenger) -> void: kicked.append(passenger))
	var vip := _vip(runner)

	Seating.pick_up(cabin, vip)
	await runner.simulate_frames(40, 50)

	assert_int(kicked.size()).is_equal(1)
	assert_bool(vip in cabin.get_passengers()).is_true()


func test_anyone_else_on_a_full_bus_cannot_be_picked_up() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(2)
	var cabin := _fill(runner, 0)
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	var bus := runner.find_child("Bus") as FrameshiftBus

	var someone := waiting.create(bus.get_docked_planet())

	assert_bool(Seating.can_pick_up(cabin, someone)).is_false()


# The cabin, its seats taken by ordinary passengers until [param free] are left, with nobody
# calling meanwhile.
func _fill(runner: GdUnitSceneRunner, free: int) -> Cabin:
	var cabin := runner.find_child("Cabin") as Cabin
	var bus := runner.find_child("Bus") as FrameshiftBus
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	(runner.find_child("QuestGiver") as QuestGiver).enabled = false
	while cabin.get_free_seats() > free:
		cabin.board(waiting.create(bus.get_docked_planet()))
	return cabin


func _vip(runner: GdUnitSceneRunner) -> Passenger:
	var bus := runner.find_child("Bus") as FrameshiftBus
	var waiting := runner.find_child("WaitingPassengers") as WaitingPassengers
	var vip := waiting.create(bus.get_docked_planet())
	vip.type = Vip.TYPE
	return vip
