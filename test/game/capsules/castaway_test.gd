extends GdUnitTestSuite
## The castaway's portrait shows the space of the star system they are bound for.

const COMMUTER := preload("res://game/passengers/types/commuter.tres")


func test_the_space_behind_the_castaway_is_their_destination_system_s_fog() -> void:
	var system: StarSystem = auto_free(StarSystem.new())
	system.fog_color = Color.RED
	var planet := Planet.new()
	var moon := Planet.new()
	planet.add_child(moon)
	system.add_child(planet)
	add_child(system)
	var passenger := Passenger.new(COMMUTER, moon, 60.0, 40.0)
	Castaway.dress(passenger, false)

	assert_that(Castaway.get_space_color(passenger)).is_equal(Color.RED)


func test_the_space_is_the_castaway_s_own_outside_a_star_system() -> void:
	var planet: Planet = auto_free(Planet.new())
	var passenger := Passenger.new(COMMUTER, planet, 60.0, 40.0)

	assert_that(Castaway.get_space_color(passenger)).is_equal(Castaway.SPACE)
