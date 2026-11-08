extends GdUnitTestSuite
## The bus's route rules, driven frame by frame with a fixed step on still planets, so
## each test is quick and doesn't depend on the machine's speed.

const BUS := "res://game/bus/bus.tscn"
const STEP := 0.05
# Long enough for any trip in these tests.
const MAX_STEPS := 2000

var _bus: FrameshiftBus
var _home: Planet
var _near: Planet
var _far: Planet
var _reduce_motion: bool


func before_test() -> void:
	_reduce_motion = Settings.reduce_motion
	Settings.reduce_motion = true
	var space := auto_free(Node3D.new()) as Node3D
	add_child(space)
	_home = _planet(space, Vector3(0.0, 0.0, 0.0))
	_near = _planet(space, Vector3(6.0, 0.0, 0.0))
	_far = _planet(space, Vector3(6.0, 0.0, 6.0))
	_bus = (load(BUS) as PackedScene).instantiate() as FrameshiftBus
	_bus.start_planet = _home
	space.add_child(_bus)
	# The test steps the bus itself.
	_bus.set_process(false)


func after_test() -> void:
	# Assigning re-saves the developer's own settings file with their value.
	Settings.reduce_motion = _reduce_motion


func test_a_course_from_a_planet_charges_then_flies_and_docks_at_the_moving_planet() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(_bus.charge_time - 0.5)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.CHARGING)
	assert_object(_bus.get_docked_planet()).is_same(_home)
	_step_for(1.0)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.FLYING)
	assert_object(_bus.get_docked_planet()).is_null()
	# The planet moves after the bus each frame, as it does in the game.
	var docked := false
	for i: int in MAX_STEPS:
		_bus._process(STEP)
		_near.position += Vector3(0.0, 0.0, 0.45) * STEP
		if _bus.state == FrameshiftBus.State.DOCKED:
			docked = true
			break
	assert_bool(docked).is_true()
	assert_object(_bus.get_docked_planet()).is_same(_near)
	assert_array(_bus.get_route_planets()).is_empty()


func test_the_bus_pulls_out_and_turns_toward_its_next_stop_while_charging() -> void:
	var parked := _bus.global_position.distance_to(_home.global_position)
	var behind := _planet(_home.get_parent() as Node3D, Vector3(-6.0, 0.0, 0.0))
	_bus.plot_course(RouteStop.at_planet(behind))
	_step_for(_bus.charge_time - 0.5)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.CHARGING)
	var to_stop := (behind.global_position - _bus.global_position) * Vector3(1.0, 0.0, 1.0)
	var forward := (_bus.global_basis.z * Vector3(1.0, 0.0, 1.0)).normalized()
	assert_float(forward.dot(to_stop.normalized())).is_greater(0.99)
	var out := _bus.global_position.distance_to(_home.global_position) - parked
	assert_float(out).is_equal_approx(_bus.charge_gap - _bus.dock_gap, 0.02)


func test_the_thrusters_light_up_while_charging_burn_in_flight_and_go_dark_docked() -> void:
	var model := _bus.get_node(^"%Model") as BusModel
	var glow := model.find_child("ThrusterGlow", true, false) as MeshInstance3D
	var glow_material := glow.material_override as StandardMaterial3D
	assert_float(model.thrust).is_equal(0.0)
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(_bus.charge_time * 0.5)
	assert_float(model.thrust).is_between(0.2, 0.8)
	assert_bool(_step_until(FrameshiftBus.State.FLYING)).is_true()
	_step_for(0.5)
	assert_float(model.thrust).is_equal(1.0)
	assert_that(glow_material.albedo_color).is_equal(model.thruster_color)
	assert_float(glow.scale.z).is_equal(1.0)
	assert_bool(_step_until_docked()).is_true()
	_step_for(1.0)
	assert_float(model.thrust).is_equal(0.0)
	assert_that(glow_material.albedo_color).is_equal(model.thruster_off_color)
	assert_float(glow.scale.z).is_less(0.2)


func test_a_flight_leaves_a_trail_that_fades_after_it_arrives() -> void:
	var trail := _bus.get_node(^"%ThrusterTrail") as ThrusterTrail
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(_bus.charge_time - 0.5)
	assert_bool(trail.is_empty()).is_true()
	assert_bool(_step_until(FrameshiftBus.State.FLYING)).is_true()
	_step_for(1.0)
	assert_bool(trail.is_empty()).is_false()
	assert_bool(_step_until(FrameshiftBus.State.PARKING)).is_true()
	_step_for(trail.lifetime * 0.5)
	assert_bool(trail.is_empty()).is_false()
	_step_for(trail.lifetime)
	assert_bool(trail.is_empty()).is_true()


func test_each_planet_on_the_route_docks_and_charges_again() -> void:
	var docked_at: Array[Planet] = []
	_bus.docked.connect(func(planet: Planet) -> void: docked_at.append(planet))
	_bus.plot_course(RouteStop.at_planet(_near))
	_bus.plot_course(RouteStop.at_planet(_far), true)
	assert_array(_bus.get_route_planets()).contains_exactly([_near, _far])
	_step_for(_bus.charge_time + STEP)
	assert_bool(_step_until(FrameshiftBus.State.CHARGING)).is_true()
	assert_object(_bus.get_docked_planet()).is_same(_near)
	assert_array(_bus.get_route_planets()).contains_exactly([_far])
	assert_bool(_step_until_docked()).is_true()
	assert_object(_bus.get_docked_planet()).is_same(_far)
	assert_array(docked_at).contains_exactly([_near, _far])


func test_boarding_holds_a_charge_from_starting_and_a_charge_under_way() -> void:
	_bus.boarding = true
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(_bus.charge_time + 1.0)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.DOCKED)
	assert_array(_bus.get_route_planets()).contains_exactly([_near])

	_bus.boarding = false

	assert_int(_bus.state).is_equal(FrameshiftBus.State.CHARGING)
	_step_for(_bus.charge_time - 0.5)
	var progress := _bus.get_charge_progress()
	_bus.boarding = true
	_step_for(_bus.charge_time)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.CHARGING)
	assert_float(_bus.get_charge_progress()).is_equal_approx(progress, 0.001)
	_bus.boarding = false
	_step_for(1.0)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.FLYING)


func test_boarding_set_on_docking_holds_the_charge_to_the_next_stop() -> void:
	_bus.docked.connect(func(_planet: Planet) -> void: _bus.boarding = true)
	_bus.plot_course(RouteStop.at_planet(_near))
	_bus.plot_course(RouteStop.at_planet(_far), true)
	assert_bool(_step_until_docked()).is_true()
	assert_object(_bus.get_docked_planet()).is_same(_near)
	_step_for(_bus.charge_time + 1.0)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.DOCKED)

	_bus.boarding = false

	assert_int(_bus.state).is_equal(FrameshiftBus.State.CHARGING)


func test_removing_a_stop_in_the_middle_keeps_the_rest_in_order() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	var checkpoint := RouteStop.at_point(Vector3(3.0, 0.0, 3.0))
	_bus.plot_course(checkpoint, true)
	_bus.remove_stop(checkpoint)
	assert_array(_bus.get_route_stops()).has_size(1)
	assert_object(_bus.get_last_stop().planet).is_same(_near)


func test_a_point_in_space_becomes_the_one_checkpoint_before_the_first_planet() -> void:
	var first := RouteStop.at_point(Vector3(3.0, 0.0, 3.0))
	var second := RouteStop.at_point(Vector3(4.0, 0.0, 3.0))
	_bus.plot_course(RouteStop.at_planet(_near))
	_bus.plot_course(RouteStop.at_planet(_far), true)
	_bus.plot_course(first, true)
	assert_object(_bus.get_route_stops()[0]).is_same(first)
	_bus.plot_course(second, true)
	var stops := _bus.get_route_stops()
	assert_array(stops).has_size(3)
	assert_object(stops[0]).is_same(second)
	assert_array(_bus.get_route_planets()).contains_exactly([_near, _far])


func test_a_checkpoint_is_flown_through_before_docking() -> void:
	var checkpoint := Vector3(-3.0, 0.0, -3.0)
	_bus.plot_course(RouteStop.at_planet(_near))
	_bus.plot_course(RouteStop.at_point(checkpoint), true)
	var closest := INF
	for i: int in MAX_STEPS:
		_bus._process(STEP)
		closest = minf(closest, _bus.global_position.distance_to(checkpoint))
		if _bus.state == FrameshiftBus.State.DOCKED and _bus.get_docked_planet() == _near:
			break
	assert_object(_bus.get_docked_planet()).is_same(_near)
	assert_float(closest).is_less(_bus.waypoint_radius + 0.05)


func test_removing_a_planet_takes_its_checkpoint_along() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	_bus.plot_course(RouteStop.at_point(Vector3(3.0, 0.0, 3.0)), true)
	_bus.plot_course(RouteStop.at_planet(_far), true)
	_bus.remove_stop(_bus.get_last_stop())
	# The checkpoint before Near isn't Far's, so it stays.
	assert_array(_bus.get_route_stops()).has_size(2)
	assert_array(_bus.get_route_planets()).contains_exactly([_near])
	assert_int(_bus.state).is_equal(FrameshiftBus.State.CHARGING)
	# Near takes its checkpoint along, and with no stop left the charge stops.
	_bus.remove_stop(_bus.get_last_stop())
	assert_object(_bus.get_last_stop()).is_null()
	assert_int(_bus.state).is_equal(FrameshiftBus.State.DOCKED)


func test_a_point_in_space_with_no_planet_ahead_replaces_the_one_there() -> void:
	var point := Vector3(-4.0, 0.0, 3.0)
	_bus.plot_course(RouteStop.at_point(Vector3(-2.0, 0.0, 4.0)))
	_bus.plot_course(RouteStop.at_point(point), true)
	assert_array(_bus.get_route_stops()).has_size(1)
	_step_for(_bus.charge_time + STEP)
	assert_bool(_step_until(FrameshiftBus.State.HOLDING)).is_true()
	assert_vector(_bus.global_position).is_equal_approx(point, Vector3.ONE * 0.1)


func test_a_course_from_space_leaves_without_charging() -> void:
	_bus.plot_course(RouteStop.at_point(Vector3(-3.0, 0.0, 0.0)))
	_step_for(_bus.charge_time + STEP)
	assert_bool(_step_until(FrameshiftBus.State.HOLDING)).is_true()
	_bus.plot_course(RouteStop.at_planet(_near))
	assert_int(_bus.state).is_equal(FrameshiftBus.State.FLYING)


func test_cancel_while_charging_stays_docked() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(1.0)
	_bus.cancel_course()
	_step_for(_bus.charge_time)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.DOCKED)
	assert_object(_bus.get_docked_planet()).is_same(_home)


func test_a_course_to_the_docked_planet_cancels() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	_bus.plot_course(RouteStop.at_planet(_home))
	assert_int(_bus.state).is_equal(FrameshiftBus.State.DOCKED)
	assert_array(_bus.get_route_planets()).is_empty()


func test_the_time_estimate_matches_a_trip_to_a_still_planet() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	var estimate := _bus.estimate_time_to_next_planet()
	var took := 0.0
	for i: int in MAX_STEPS:
		_bus._process(STEP)
		took += STEP
		if _bus.state == FrameshiftBus.State.DOCKED:
			break
	assert_object(_bus.get_docked_planet()).is_same(_near)
	assert_float(estimate).is_between(took * 0.9, took * 1.1)


func test_the_next_planet_skips_points_in_space() -> void:
	_bus.plot_course(RouteStop.at_point(Vector3(3.0, 0.0, 3.0)))
	assert_object(_bus.get_next_planet()).is_null()
	assert_float(_bus.estimate_time_to_next_planet()).is_equal(-1.0)
	_bus.plot_course(RouteStop.at_planet(_far))
	_bus.plot_course(RouteStop.at_point(Vector3(3.0, 0.0, 3.0)), true)
	assert_object(_bus.get_route_stops()[0].planet).is_null()
	assert_object(_bus.get_next_planet()).is_same(_far)
	assert_float(_bus.estimate_time_to_next_planet()).is_greater(_bus.charge_time)


func test_a_planet_replaces_a_point_in_space_with_no_planet_ahead() -> void:
	_bus.plot_course(RouteStop.at_point(Vector3(3.0, 0.0, 3.0)))
	_bus.plot_course(RouteStop.at_planet(_far), true)
	assert_array(_bus.get_route_stops()).has_size(1)
	assert_object(_bus.get_last_stop().planet).is_same(_far)
	# With a planet on the route, the point before it stays as its checkpoint.
	_bus.plot_course(RouteStop.at_point(Vector3(3.0, 0.0, 3.0)), true)
	_bus.plot_course(RouteStop.at_planet(_near), true)
	assert_array(_bus.get_route_stops()).has_size(3)
	assert_array(_bus.get_route_planets()).contains_exactly([_far, _near])


func test_docking_brakes_then_parks_with_the_door_toward_the_planet_then_docks() -> void:
	var docked_at: Array[Planet] = []
	_bus.docked.connect(func(planet: Planet) -> void: docked_at.append(planet))
	assert_float(_door_facing(_home)).is_greater(0.99)
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(_bus.charge_time + 1.0)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.FLYING)
	assert_bool(_bus.is_docking()).is_false()
	var docking_seen := false
	for i: int in MAX_STEPS:
		_bus._process(STEP)
		if _bus.state == FrameshiftBus.State.PARKING:
			break
		docking_seen = docking_seen or _bus.is_docking()
	assert_bool(docking_seen).is_true()
	# Arrives still a little way out, nose first, then glides the rest, slowing, and swings
	# side-on. It hasn't docked yet.
	var dock_point := _bus._dock_point()
	assert_float(_bus.global_position.distance_to(dock_point)).is_greater(0.3)
	assert_float(_door_facing(_near)).is_less(0.5)
	assert_object(_bus.get_next_planet()).is_same(_near)
	var first_step := _moved_in(STEP)
	_step_for(1.0)
	assert_float(_moved_in(STEP)).is_less(first_step * 0.5)
	assert_array(docked_at).is_empty()
	assert_bool(_step_until_docked()).is_true()
	assert_array(docked_at).contains_exactly([_near])
	assert_bool(_bus.is_docking()).is_false()
	assert_float(_bus.global_position.distance_to(dock_point)).is_less(0.05)
	assert_float(_door_facing(_near)).is_greater(0.99)


func test_cancel_while_flying_is_stopping_until_it_holds_in_space() -> void:
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(_bus.charge_time + 2.0)
	assert_bool(_bus.is_stopping()).is_false()
	_bus.cancel_course()
	assert_bool(_bus.is_stopping()).is_true()
	assert_bool(_step_until(FrameshiftBus.State.HOLDING)).is_true()
	assert_bool(_bus.is_stopping()).is_false()
	assert_object(_bus.get_docked_planet()).is_null()


func test_on_board_speeding_up_pushes_back_a_turn_pushes_out_and_braking_forward() -> void:
	# The bus leaves Home toward +X, then turns left, toward -Z, for Side.
	var side := _planet(_home.get_parent() as Node3D, Vector3(5.0, 0.0, -6.0))
	_bus.plot_course(RouteStop.at_planet(side))
	_bus.plot_course(RouteStop.at_point(Vector3(4.0, 0.0, 0.0)), true)
	_step_for(_bus.charge_time)
	assert_vector(_bus.get_felt_acceleration()).is_equal(Vector2.ZERO)
	var least := Vector2.ZERO
	var most := Vector2.ZERO
	for i: int in MAX_STEPS:
		_bus._process(STEP)
		least = least.min(_bus.get_felt_acceleration())
		most = most.max(_bus.get_felt_acceleration())
		if _bus.state == FrameshiftBus.State.DOCKED:
			break
	assert_object(_bus.get_docked_planet()).is_same(side)
	assert_float(least.y).is_less(-1.0)
	assert_float(most.x).is_greater(0.5)
	# Braking at its rate, then the glide easing off, capped.
	assert_float(most.y).is_between(_bus.acceleration, FrameshiftBus.FELT_MAX)
	_step_for(2.0)
	assert_vector(_bus.get_felt_acceleration()).is_equal_approx(Vector2.ZERO, Vector2.ONE * 0.01)


func test_flying_burns_fuel_by_distance_and_charging_and_parking_burn_none() -> void:
	var tank := _bus.get_fuel_tank()
	_bus.plot_course(RouteStop.at_planet(_near))
	var flown := 0.0
	for i: int in MAX_STEPS:
		var before := _bus.global_position
		_bus._process(STEP)
		if _bus.state == FrameshiftBus.State.FLYING:
			flown += before.distance_to(_bus.global_position)
		if _bus.state == FrameshiftBus.State.DOCKED:
			break
	assert_object(_bus.get_docked_planet()).is_same(_near)
	assert_float(flown).is_greater(4.0)
	assert_float(tank.fuel).is_equal_approx(tank.capacity - flown * tank.burn_per_unit, 0.01)


func test_running_dry_in_flight_stops_the_bus_and_asks_for_a_tow() -> void:
	var tank := _bus.get_fuel_tank()
	# Enough for 2 units of the trip, which is longer.
	tank.fuel = 2.0 * tank.burn_per_unit
	monitor_signals(_bus)
	_bus.plot_course(RouteStop.at_planet(_far))
	assert_bool(_step_until(FrameshiftBus.State.HOLDING)).is_true()
	await assert_signal(_bus).is_emitted("ran_out_of_fuel")
	assert_bool(tank.is_empty()).is_true()
	assert_array(_bus.get_route_stops()).is_empty()
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(1.0)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.HOLDING)


func test_a_tow_takes_no_course_changes_and_docks_with_a_full_tank() -> void:
	var tank := _bus.get_fuel_tank()
	tank.fuel = 2.0 * tank.burn_per_unit
	_bus.plot_course(RouteStop.at_planet(_far))
	assert_bool(_step_until(FrameshiftBus.State.HOLDING)).is_true()
	monitor_signals(_bus)
	_bus.tow_to(_near)
	_bus.plot_course(RouteStop.at_planet(_far))
	_bus.cancel_course()
	assert_array(_bus.get_route_planets()).contains_exactly([_near])
	assert_bool(_step_until_docked()).is_true()
	assert_object(_bus.get_docked_planet()).is_same(_near)
	assert_float(tank.fuel).is_equal(tank.capacity)
	assert_bool(_bus.is_towing()).is_false()
	await assert_signal(_bus).is_emitted("towed", [_near])


func test_emptying_the_tank_at_a_planet_stops_a_charge_and_calls_no_tow() -> void:
	monitor_signals(_bus)
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(1.0)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.CHARGING)
	_bus.get_fuel_tank().drain()
	assert_int(_bus.state).is_equal(FrameshiftBus.State.DOCKED)
	assert_array(_bus.get_route_stops()).is_empty()
	# No course until it refuels.
	_bus.plot_course(RouteStop.at_planet(_near))
	_step_for(1.0)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.DOCKED)
	await assert_signal(_bus).wait_until(50).is_not_emitted("ran_out_of_fuel")


func test_a_tow_catches_a_planet_that_orbits_faster_than_the_tow_speed() -> void:
	_bus.plot_course(RouteStop.at_point(Vector3(0.0, 0.0, 4.0)))
	assert_bool(_step_until(FrameshiftBus.State.HOLDING)).is_true()
	# Just ahead of the bus and moving away from it (-z at its start angle), faster than the
	# tow speed, so the tow chases it from behind.
	var orbiting := Planet.new()
	orbiting.orbit_radius = 5.0
	orbiting.orbit_period = TAU * orbiting.orbit_radius / (_bus.tow_speed * 1.5)
	orbiting.show_orbit = false
	orbiting.position = Vector3(-5.0, 0.0, 2.0)
	_home.get_parent().add_child(orbiting)
	orbiting.set_process(false)
	_bus.tow_to(orbiting)
	var docked := false
	for i: int in MAX_STEPS * 2:
		_bus._process(STEP)
		orbiting._process(STEP)
		if _bus.state == FrameshiftBus.State.DOCKED:
			docked = true
			break
	assert_bool(docked).is_true()
	assert_object(_bus.get_docked_planet()).is_same(orbiting)
	assert_bool(_bus.is_towing()).is_false()


func test_a_top_speed_modifier_makes_the_bus_cruise_faster() -> void:
	var boost := StatModifier.new(BusStats.Type.MAX_SPEED, StatModifier.Kind.PERCENT, 100.0)
	_bus.get_stats().add_modifier(boost)
	_bus.plot_course(RouteStop.at_point(Vector3(-40.0, 0.0, 0.0)))
	assert_bool(_step_until(FrameshiftBus.State.FLYING)).is_true()
	# Long enough to reach top speed from a standstill.
	_step_for(3.0)
	var before := _bus.global_position
	_step_for(1.0)
	var flown := before.distance_to(_bus.global_position)
	assert_float(flown).is_equal_approx(_bus.max_speed * 2.0, 0.02)


func test_a_fuel_capacity_modifier_resizes_the_tank() -> void:
	var tank := _bus.get_fuel_tank()
	var bigger := StatModifier.new(BusStats.Type.FUEL_CAPACITY, StatModifier.Kind.PERCENT, 50.0)
	_bus.get_stats().add_modifier(bigger)
	assert_float(tank.capacity).is_equal_approx(150.0, 0.0001)


# A planet that stays where it is put.


func _planet(parent: Node3D, at: Vector3) -> Planet:
	var planet := Planet.new()
	planet.orbit_radius = 0.0
	planet.orbit_period = 0.0
	planet.show_orbit = false
	planet.position = at
	parent.add_child(planet)
	return planet


# How squarely the door on the bus's left faces the planet: 1 when it faces it head on.
func _door_facing(planet: Planet) -> float:
	var to_planet := (planet.global_position - _bus.global_position) * Vector3(1.0, 0.0, 1.0)
	return (-_bus.global_basis.x).dot(to_planet.normalized())


# How far the bus moves in one step of [param seconds].
func _moved_in(seconds: float) -> float:
	var before := _bus.global_position
	_bus._process(seconds)
	return _bus.global_position.distance_to(before)


func _step_for(seconds: float) -> void:
	for i: int in roundi(seconds / STEP):
		_bus._process(STEP)


func _step_until(state: FrameshiftBus.State) -> bool:
	for i: int in MAX_STEPS:
		_bus._process(STEP)
		if _bus.state == state:
			return true
	return false


func _step_until_docked() -> bool:
	return _step_until(FrameshiftBus.State.DOCKED)
