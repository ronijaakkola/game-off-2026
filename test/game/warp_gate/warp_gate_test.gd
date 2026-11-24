extends GdUnitTestSuite
## Where a warp gate floats: beside its planet, on the side away from the planet's star,
## wherever its star system sits on the map.


func test_a_gate_floats_beside_its_planet_away_from_a_star_off_the_origin() -> void:
	var system := auto_free(StarSystem.new()) as StarSystem
	system.position = Vector3(30.0, 0.0, -12.0)
	add_child(system)
	var planet := Planet.new()
	planet.orbit_radius = 6.0
	planet.start_angle = 90.0
	planet.show_orbit = false
	system.add_child(planet)
	var gate := WarpGate.new()
	gate.planet = planet
	system.add_child(gate)
	await await_idle_frame()
	await await_idle_frame()
	var star := system.global_position
	var body := planet.get_body_global_position()
	var away := Vector3(body.x - star.x, 0.0, body.z - star.z).normalized()
	assert_vector(gate.global_position).is_equal_approx(
		body + away * WarpGate.DISTANCE, Vector3.ONE * 0.001
	)
