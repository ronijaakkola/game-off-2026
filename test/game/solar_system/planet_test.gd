extends GdUnitTestSuite
## A planet's body velocity, which a tow uses to keep up with it. Stepped by hand with a
## fixed delta, and checked against how far the body really moves in a step.

const STEP := 0.01


func test_body_velocity_matches_how_the_body_moves_moon_included() -> void:
	var space := auto_free(Node3D.new()) as Node3D
	add_child(space)
	var planet := _planet(space, 6.0, 20.0, 30.0)
	planet.position = Vector3(1.0, 0.0, -2.0)
	var moon := _planet(planet, 1.5, 4.0, 90.0)
	for i: int in 50:
		_step(planet, moon)
		for body: Planet in [planet, moon]:
			var before := body.get_body_global_position()
			var velocity := body.get_body_velocity()
			_step(planet, moon)
			var moved := (body.get_body_global_position() - before) / STEP
			assert_vector(velocity).is_equal_approx(moved, Vector3.ONE * 0.05)
	assert_float(moon.get_body_velocity().length()).is_greater(0.0)


func _planet(parent: Node3D, orbit: float, period: float, angle: float) -> Planet:
	var planet := Planet.new()
	planet.orbit_radius = orbit
	planet.orbit_period = period
	planet.start_angle = angle
	planet.show_orbit = false
	parent.add_child(planet)
	planet.set_process(false)
	return planet


# The planet before its moon, so the moon reads where its centre is this step.
func _step(planet: Planet, moon: Planet) -> void:
	planet._process(STEP)
	moon._process(STEP)
