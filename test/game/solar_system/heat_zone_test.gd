extends GdUnitTestSuite
## The heat zone keeping the bus out of the star: a bus sent straight at it brakes to a stop
## short of its surface and overheats there, its route cleared and no new course taken until
## it has cooled down. Driven frame by frame with a fixed step.

const BUS := "res://game/bus/bus.tscn"
const HEAT_SHADER := "res://game/solar_system/heat_zone.gdshader"
const STEP := 0.05
const MAX_STEPS := 4000

var _bus: FrameshiftBus
var _zone: HeatZone
var _star: Node3D
var _far: Planet
var _reduce_motion: bool


func before_test() -> void:
	_reduce_motion = Settings.reduce_motion
	Settings.reduce_motion = true
	var space := auto_free(Node3D.new()) as Node3D
	add_child(space)
	_star = Node3D.new()
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
	_zone.star = _star
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
	assert_array(_bus.get_route_planets()).is_empty()
	# While it cools down, no course can be set.
	_bus.plot_course(RouteStop.at_planet(_far))
	assert_array(_bus.get_route_planets()).is_empty()
	# It coasts to a stop, still clear of the star.
	for i: int in roundi(temperature.cooldown_time / STEP) + 1:
		_step()
		nearest = minf(nearest, _distance())
	assert_float(nearest).is_greater(temperature.star_radius + FrameshiftBus.RADIUS)
	assert_bool(temperature.is_cooling()).is_false()
	_bus.plot_course(RouteStop.at_planet(_far))
	assert_array(_bus.get_route_planets()).is_not_empty()


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
