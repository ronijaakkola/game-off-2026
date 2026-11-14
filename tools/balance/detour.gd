extends RefCounted
## How the scripted player flies round the star. When the straight way to the next planet
## crosses the hot zone, now or as the planet moves, a checkpoint goes beyond the heat
## zone's edge: hugging the hot zone's edge for long overheats in the outer zone. After an
## overheat, the same course again once the cooldown is over, charged at once.

## How far outside the hot zone's edge a leg must pass.
const HOT_ZONE_MARGIN := 0.5
## How far outside the heat zone's edge a checkpoint round it goes.
const HEAT_ZONE_MARGIN := 0.3

var _bus: FrameshiftBus
var _star: Node3D
# The planet the course goes to, and whether an overheat cleared it.
var _heading_to: Planet
var _overheated := false


func _init(bus: FrameshiftBus, star: Node3D) -> void:
	_bus = bus
	_star = star
	bus.temperature.overheated.connect(func() -> void: _overheated = true)


## Sets a course to [param planet], round the hot zone when the straight leg crosses it.
func plot(planet: Planet) -> void:
	_heading_to = planet
	_bus.plot_course(RouteStop.at_planet(planet))
	steer()


## Every frame away from a planet: a course again after an overheat, and a checkpoint when
## the leg to the planet ahead has come to cross the hot zone.
func steer() -> void:
	if _overheated and not _bus.temperature.is_cooling():
		_overheated = false
		plot(_heading_to)
		_bus.frameshift_held = true
		return
	var stops := _bus.get_route_stops()
	if stops.size() != 1 or not stops[0].planet or _bus.is_towing():
		return
	var star := _star.global_position
	var to := stops[0].get_target(_bus.global_position, _bus.dock_gap)
	var temperature := _bus.temperature
	var clear := temperature.hot_zone_radius + HOT_ZONE_MARGIN
	var out := temperature.zone_radius + HEAT_ZONE_MARGIN
	var from := RouteStop.flat(_bus.global_position - star)
	var via: Variant = around(from, RouteStop.flat(to - star), clear, out)
	if via != null:
		_bus.plot_course(RouteStop.at_point(star + (via as Vector3)), true)


## The checkpoint that keeps a leg from [param from] to [param to] at least [param clear]
## from the star, both relative to the star on the orbit plane, or null when the straight
## leg already does. It goes at least [param out] from the star, beyond where the leg comes
## nearest it, and further until neither leg crosses.
static func around(from: Vector3, to: Vector3, clear: float, out: float) -> Variant:
	if not _crosses(from, to, clear):
		return null
	var nearest := Geometry3D.get_closest_point_to_segment(Vector3.ZERO, from, to)
	var side := nearest.normalized()
	if nearest.length() < 0.01:
		side = (to - from).cross(Vector3.UP).normalized()
	var radius := maxf(out, clear)
	while (
		radius < clear * 4.0
		and (_crosses(from, side * radius, clear) or _crosses(side * radius, to, clear))
	):
		radius += 0.25
	return side * radius


# Whether the leg from a to b passes within clear of the star between its ends. A leg
# nearest the star at an end only heads in or out, as from an overheat or into Ember.
static func _crosses(a: Vector3, b: Vector3, clear: float) -> bool:
	var nearest := Geometry3D.get_closest_point_to_segment(Vector3.ZERO, a, b)
	return (
		nearest.length() < clear
		and not nearest.is_equal_approx(a)
		and not nearest.is_equal_approx(b)
	)
