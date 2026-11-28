extends GdUnitTestSuite
## The heat zone keeping the bus out of the star: a bus sent straight at it brakes to a stop
## short of its surface and overheats there, its route kept. The route waits there for a
## charge until it has cooled. A swelling star's heat reaches a bus docked past its resting
## zone only while swollen, and one parked there through a swell overheats. Driven frame by
## frame with a fixed step.

const BUS := "res://game/bus/bus.tscn"
const HEAT_SHADER := "res://game/solar_system/heat_zone.gdshader"
const STEP := 0.05
const MAX_STEPS := 4000

var _bus: FrameshiftBus
var _zone: HeatZone
var _star: StarSystem
var _far: Planet
var _reduce_motion: bool


func before_test() -> void:
	_reduce_motion = Settings.reduce_motion
	Settings.reduce_motion = true
	var space := auto_free(Node3D.new()) as Node3D
	add_child(space)
	_star = StarSystem.new()
	space.add_child(_star)
	var home := _planet(space, Vector3(12.0, 0.0, 0.0))
	# Beyond the star, so the straight way there runs through it.
	_far = _planet(space, Vector3(-12.0, 0.0, 0.0))
	_bus = (load(BUS) as PackedScene).instantiate() as FrameshiftBus
	_bus.start_planet = home
	space.add_child(_bus)
	_bus.set_process(false)
	_bus.frameshift_held = true
	var disc := MeshInstance3D.new()
	var material := ShaderMaterial.new()
	material.shader = load(HEAT_SHADER) as Shader
	disc.material_override = material
	_star.add_child(disc)
	var map_zoom := MapZoom.new()
	space.add_child(map_zoom)
	_zone = HeatZone.new()
	_zone.bus = _bus
	var star_map := StarMap.new()
	star_map.world = space
	space.add_child(star_map)
	_zone.star_map = star_map
	_zone.map_zoom = map_zoom
	_zone.zone = disc
	space.add_child(_zone)
	_zone.set_process(false)


func after_test() -> void:
	Settings.reduce_motion = _reduce_motion


func test_a_bus_sent_through_the_star_stops_short_of_it_and_overheats() -> void:
	var temperature := _bus.temperature
	_bus.plot_course(RouteStop.at_planet(_far))
	var nearest := INF
	var overheated := false
	for i: int in MAX_STEPS:
		_step()
		nearest = minf(nearest, _distance())
		if temperature.is_cooling():
			overheated = true
			break
	assert_bool(overheated).is_true()
	assert_float(nearest).is_greater(temperature.star_radius + FrameshiftBus.RADIUS)
	# The route stays, but the bus coasts to a stop and the drive doesn't charge, though
	# the key is held.
	assert_array(_bus.get_route_planets()).contains_exactly([_far])
	_bus.frameshift_held = true
	for i: int in roundi(temperature.cooldown_time / STEP) - 2:
		_step()
		nearest = minf(nearest, _distance())
		assert_int(_bus.state).is_not_equal(FrameshiftBus.State.CHARGING)
	assert_int(_bus.state).is_equal(FrameshiftBus.State.HOLDING)
	assert_float(nearest).is_greater(temperature.star_radius + FrameshiftBus.RADIUS)
	# Cooled down, it charges for the course.
	for i: int in 4:
		_step()
	assert_bool(temperature.is_cooling()).is_false()
	assert_int(_bus.state).is_equal(FrameshiftBus.State.CHARGING)


func test_overheated_against_the_star_a_course_that_clears_it_gets_out() -> void:
	var temperature := _bus.temperature
	var overheats := [0]
	temperature.overheated.connect(func() -> void: overheats[0] += 1)
	_bus.plot_course(RouteStop.at_planet(_far))
	for i: int in MAX_STEPS:
		_step()
		if temperature.is_cooling():
			break
	assert_int(overheats[0]).is_equal(1)
	# A planet off to the side, its way heading 85° from straight at the star: a little
	# toward it at first, but clear of it.
	var toward := (_star.global_position - _bus.global_position).normalized()
	var aside := toward.rotated(Vector3.UP, deg_to_rad(85.0))
	var side := _planet(_far.get_parent() as Node3D, _bus.global_position + aside * 12.0)
	_bus.plot_course(RouteStop.at_planet(side))
	_bus.frameshift_held = true
	var docked := false
	for i: int in MAX_STEPS:
		_step()
		if _bus.state == FrameshiftBus.State.DOCKED:
			docked = true
			break
	assert_bool(docked).is_true()
	assert_int(overheats[0]).is_equal(1)


func test_overheated_on_the_way_in_beside_the_star_the_same_course_gets_out() -> void:
	var temperature := _bus.temperature
	var overheats := [0]
	temperature.overheated.connect(func() -> void: overheats[0] += 1)
	# The straight way there passes about 3.3 from the star's centre, deep in the hot zone.
	var beside := _planet(_far.get_parent() as Node3D, Vector3(-12.0, 0.0, 6.9))
	_bus.plot_course(RouteStop.at_planet(beside))
	for i: int in MAX_STEPS:
		_step()
		if _distance() < 5.0:
			break
	# Warm from earlier, it overheats on the way in.
	temperature.set_temperature(temperature.overheat_temperature)
	for i: int in MAX_STEPS:
		_step()
		if _bus.state == FrameshiftBus.State.HOLDING:
			break
	# Stopped short of its nearest point, it still heads toward the star, its route kept.
	var forward := _bus.global_basis.z
	assert_float(forward.dot(_star.global_position - _bus.global_position)).is_greater(0.0)
	assert_array(_bus.get_route_planets()).contains_exactly([beside])
	# Holding the key once it has cooled takes it on along the same route.
	_bus.frameshift_held = true
	var nearest := INF
	var docked := false
	for i: int in MAX_STEPS:
		_step()
		nearest = minf(nearest, _distance())
		if _bus.state == FrameshiftBus.State.DOCKED:
			docked = true
			break
	assert_bool(docked).is_true()
	assert_int(overheats[0]).is_equal(1)
	assert_float(nearest).is_greater(temperature.star_radius + FrameshiftBus.RADIUS)


func test_a_swollen_star_heats_a_bus_docked_past_its_resting_zone() -> void:
	var temperature := _bus.temperature
	_star.swell_zone_radius = 14.9
	var at_rest := temperature.temperature
	for i: int in roundi(60.0 / STEP):
		_step_swelling()
	assert_float(temperature.temperature).is_equal(at_rest)

	_star.start_swell()
	for i: int in MAX_STEPS:
		_step_swelling()
		if _star.get_swell() == 1.0:
			break
	assert_int(_bus.state).is_equal(FrameshiftBus.State.DOCKED)
	assert_float(temperature.temperature).is_greater(at_rest)


func test_a_bus_parked_through_a_swell_overheats() -> void:
	var temperature := _bus.temperature
	_star.swell_zone_radius = 16.0
	_star.swell_standing_heating = 4.0
	var overheats := [0]
	temperature.overheated.connect(func() -> void: overheats[0] += 1)
	_star.start_swell()
	var swelled := false
	for i: int in MAX_STEPS:
		_step_swelling()
		swelled = swelled or _star.get_swell() == 1.0
		if swelled and _star.get_swell() == 0.0:
			break
	assert_bool(swelled).is_true()
	assert_int(_bus.state).is_equal(FrameshiftBus.State.DOCKED)
	assert_int(overheats[0]).is_greater(0)


func _step_swelling() -> void:
	_star._process(STEP)
	_step()


# The bus runs first each frame, as it does in the game, so it flies by last frame's cap.
func _step() -> void:
	_bus._process(STEP)
	_zone._process(STEP)


func _distance() -> float:
	var offset := _bus.global_position - _star.global_position
	offset.y = 0.0
	return offset.length()


func _planet(parent: Node3D, at: Vector3) -> Planet:
	var planet := Planet.new()
	planet.orbit_radius = 0.0
	planet.orbit_period = 0.0
	planet.show_orbit = false
	planet.position = at
	parent.add_child(planet)
	return planet


# The smoke drifted on the shader's TIME, which keeps counting while the game is paused, so
# it went on churning under the pause menu.
func test_the_smoke_holds_still_while_the_game_is_paused() -> void:
	var material := _zone.zone.material_override as ShaderMaterial
	_zone.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var drifted := material.get_shader_parameter(&"smoke_time") as float
	assert_float(drifted).is_greater(0.0)

	get_tree().paused = true
	for i: int in 5:
		await get_tree().process_frame
	get_tree().paused = false

	assert_float(material.get_shader_parameter(&"smoke_time") as float).is_equal(drifted)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(material.get_shader_parameter(&"smoke_time") as float).is_greater(drifted)
