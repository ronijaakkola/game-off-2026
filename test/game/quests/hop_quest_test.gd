extends GdUnitTestSuite
## The castaway's hop quest: where the hop location goes, and what asking it makes of the
## passenger, who goes nowhere from then on: fully happy, shocked by nothing, asking for
## nothing, and kept by a save.

const BUS := preload("res://game/bus/bus.tscn")
const OUTER := 17.5

var _system: StarSystem
var _planets: Array[Planet] = []


func before_test() -> void:
	_system = auto_free(StarSystem.new())
	_planets = []
	for radius: float in [5.0, OUTER, 9.0]:
		var planet := Planet.new()
		planet.orbit_radius = radius
		planet.orbit_period = 0.0
		_system.add_child(planet)
		planet.set_process(false)
		_planets.append(planet)
	add_child(_system)
	_system.global_position = Vector3(30.0, 0.0, -10.0)


func test_the_hop_location_is_across_the_star_just_inside_the_outermost_orbit() -> void:
	var star := _system.global_position
	var found := star + Vector3(-6.0, 0.0, 8.0)

	var spot := HopQuest.find_spot(_system, found)

	var from_star := spot - star
	assert_float(from_star.length()).is_equal_approx(OUTER - HopQuest.INSET, 0.01)
	# Straight through the star from where they were found.
	assert_float(from_star.normalized().dot((star - found).normalized())).is_equal_approx(
		1.0, 0.001
	)


func test_asking_makes_them_a_passenger_going_nowhere_who_pays_only_the_reward() -> void:
	var passenger := _ask()

	assert_object(passenger.destination).is_null()
	assert_float(passenger.fare).is_equal(0.0)
	assert_int(passenger.get_payout()).is_equal(0)


func test_someone_going_nowhere_is_as_happy_as_can_be_and_nothing_shocks_them() -> void:
	var passenger := _ask()
	passenger.settle()
	passenger.depart()
	assert_float(passenger.happiness).is_equal(Passenger.MAX_HAPPINESS)

	passenger.shock(-25.0)
	for planet: Planet in _planets + _planets:
		passenger.pass_stop(planet)
	passenger.tick(600.0, false)

	assert_float(passenger.happiness).is_equal(Passenger.MAX_HAPPINESS)
	assert_float(passenger.frustration).is_equal(0.0)


func test_someone_going_nowhere_asks_for_nothing() -> void:
	var passenger := _ask()
	passenger.depart()

	for i: int in 200:
		passenger.tick(1.0, false)
		assert_object(passenger.request).is_null()


func test_someone_going_nowhere_comes_back_from_a_save() -> void:
	var passenger := _ask()
	var types: Dictionary[String, PassengerType] = {passenger.type.resource_path: passenger.type}

	var back := Passenger.from_save(passenger.to_save(), types, {})

	assert_object(back).is_not_null()
	assert_object(back.destination).is_null()
	assert_float(back.get_target()).is_equal(Passenger.MAX_HAPPINESS)


# A passenger bound for a planet, after a hop quest was planned for them.
func _ask() -> Passenger:
	var kind := PassengerType.new()
	var snack := Need.new()
	snack.min_interval = 10.0
	snack.max_interval = 10.0
	kind.needs = [snack]
	var passenger := Passenger.new(kind, _planets[0], 100.0, 50.0)
	var bus := auto_free(BUS.instantiate()) as FrameshiftBus
	add_child(bus)
	var rng := RandomNumberGenerator.new()
	assert_bool(HopQuest.new().plan(passenger, bus, _planets, null, rng)).is_true()
	return passenger
