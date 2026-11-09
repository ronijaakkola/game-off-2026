extends GdUnitTestSuite
## A tow ship coming for a bus that ran dry, wired as the solar system wires it, and stepped
## alongside the bus with a fixed delta.

const BUS := "res://game/bus/bus.tscn"
const TOW_SHIP := "res://game/bus/tow_ship.tscn"
const STEP := 0.05
# Long enough for any tow in these tests.
const MAX_STEPS := 3000

var _space: Node3D
var _bus: FrameshiftBus
var _home: Planet
var _reduce_motion: bool


func before_test() -> void:
	_reduce_motion = Settings.reduce_motion
	Settings.reduce_motion = true
	_space = auto_free(Node3D.new()) as Node3D
	add_child(_space)
	_home = _planet(Vector3.ZERO)
	_bus = (load(BUS) as PackedScene).instantiate() as FrameshiftBus
	_bus.start_planet = _home
	_space.add_child(_bus)
	_bus.set_process(false)


func after_test() -> void:
	Settings.reduce_motion = _reduce_motion


func test_the_ship_tows_a_bus_that_ran_dry_far_out_to_the_planet() -> void:
	var target := _planet(Vector3(4.0, 0.0, -3.0))
	_run_dry_on_the_way_to(Vector3(14.0, 0.0, 10.0), 8.0)
	await _assert_tows_to(target)


func test_the_ship_tows_a_bus_that_ran_dry_beside_the_planet_without_entering_it() -> void:
	var target := _planet(Vector3(10.0, 0.0, 0.0))
	# Dry about two units short of the planet's surface.
	_run_dry_on_the_way_to(Vector3(10.0, 0.0, 2.0), 6.5)
	await _assert_tows_to(target)


# Flies toward [param at] and runs dry after [param distance] or so.
func _run_dry_on_the_way_to(at: Vector3, distance: float) -> void:
	var tank := _bus.get_fuel_tank()
	tank.fuel = distance * tank.burn_per_unit
	_bus.plot_course(RouteStop.at_point(at))
	for i: int in MAX_STEPS:
		_bus._process(STEP)
		if tank.is_empty():
			break
	assert_bool(tank.is_empty()).is_true()


func _assert_tows_to(target: Planet) -> void:
	var ship := (load(TOW_SHIP) as PackedScene).instantiate() as TowShip
	_space.add_child(ship)
	ship.set_process(false)
	ship.hitched.connect(_bus.tow_to.bind(target))
	monitor_signals(_bus)
	ship.come_for(_bus, target)
	var closest := INF
	var hitched := false
	var docked := false
	for i: int in MAX_STEPS:
		_bus._process(STEP)
		ship._process(STEP)
		var center := target.get_body_global_position()
		closest = minf(closest, (ship.global_position - center).length())
		hitched = hitched or ship.phase == TowShip.Phase.TOWING
		docked = docked or _bus.state == FrameshiftBus.State.DOCKED
		if ship.is_queued_for_deletion():
			break
	assert_bool(hitched).is_true()
	assert_bool(docked).is_true()
	assert_object(_bus.get_docked_planet()).is_same(target)
	assert_float(_bus.get_fuel_tank().fuel).is_equal(_bus.get_fuel_tank().capacity)
	assert_float(closest).is_greater(target.get_body_radius())
	assert_bool(ship.is_queued_for_deletion()).is_true()
	await assert_signal(_bus).is_emitted("towed", [target])


func _planet(at: Vector3) -> Planet:
	var planet := Planet.new()
	planet.orbit_radius = 0.0
	planet.orbit_period = 0.0
	planet.show_orbit = false
	planet.position = at
	_space.add_child(planet)
	return planet
