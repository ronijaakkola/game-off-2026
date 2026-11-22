extends RefCounted
## How the scripted player flies round the star of the system the bus works in. When the
## straight way to the next planet crosses the hot zone, now or as the planet moves, a
## waypoint goes beyond the heat zone's edge: hugging the hot zone's edge for long
## overheats in the outer zone. After an overheat, the same course again once the cooldown
## is over, charged at once. Where an asteroid field lies across the way, the course
## threads the gap that makes it shortest, where the gap will be by the time the bus gets
## there.

## How far outside the hot zone's edge a leg must pass.
const HOT_ZONE_MARGIN := 0.5
## How far outside the heat zone's edge a waypoint round it goes.
const HEAT_ZONE_MARGIN := 0.3
## How far past the band's edges the waypoints either end of a gap go.
const GAP_MARGIN := 0.8
## Seconds the bus takes to get going, on top of flying, when guessing where a gap will be.
const GAP_LEAD := 1.5
## How far apart the points tested along a leg for rocks are.
const ROCK_STEP := 0.25

var _bus: FrameshiftBus
var _star_map: StarMap
# The planet the course goes to, and whether it overheated since the course was set.
var _heading_to: Planet
var _overheated := false


func _init(bus: FrameshiftBus, star_map: StarMap) -> void:
	_bus = bus
	_star_map = star_map
	bus.temperature.overheated.connect(func() -> void: _overheated = true)


## Sets a course to [param planet], round the hot zone when the straight leg crosses it.
## In flight, as for a quest, the bus turns there at once.
func plot(planet: Planet) -> void:
	_heading_to = planet
	_bus.plot_course(RouteStop.at_planet(planet))
	_through_gap(planet)
	steer()


## Every frame away from a planet: a course again after an overheat, and a waypoint when
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
	var star := (_star_map.get_current().get_node(^"Star") as Node3D).global_position
	var to := stops[0].get_target(_bus.global_position, _bus.dock_gap)
	var temperature := _bus.temperature
	var clear := temperature.hot_zone_radius + HOT_ZONE_MARGIN
	var out := temperature.zone_radius + HEAT_ZONE_MARGIN
	var from := RouteStop.flat(_bus.global_position - star)
	var via: Variant = around(from, RouteStop.flat(to - star), clear, out)
	if via != null:
		# Round the other side when that meets the planet sooner, rather than chasing it
		# round the star.
		var moving := RouteStop.flat(stops[0].planet.get_body_velocity())
		var other: Variant = around(from, RouteStop.flat(to - star), clear, out, -(via as Vector3))
		if _way_round(from, other, to - star, moving) < _way_round(from, via, to - star, moving):
			via = other
		# Adding a stop puts it on the end, so the waypoint goes first and the planet after.
		_bus.plot_course(RouteStop.at_point(star + (via as Vector3)))
		_bus.plot_course(stops[0], true)


## The waypoint that keeps a leg from [param from] to [param to] at least [param clear]
## from the star, both relative to the star on the orbit plane, or null when the straight
## leg already does. It goes at least [param out] from the star, beyond where the leg comes
## nearest it, and further until neither leg crosses. [param towards] picks the side of the
## star it goes round instead.
static func around(
	from: Vector3, to: Vector3, clear: float, out: float, towards := Vector3.ZERO
) -> Variant:
	if not _crosses(from, to, clear):
		return null
	var nearest := Geometry3D.get_closest_point_to_segment(Vector3.ZERO, from, to)
	var side := nearest.normalized()
	if nearest.length() < 0.01:
		side = (to - from).cross(Vector3.UP).normalized()
	if towards != Vector3.ZERO:
		side = towards.normalized()
	var radius := maxf(out, clear)
	while (
		radius < clear * 4.0
		and (_crosses(from, side * radius, clear) or _crosses(side * radius, to, clear))
	):
		radius += 0.25
	return side * radius


# How far the bus flies from [param from] by [param via] to a planet now at [param to],
# moving at [param moving], where it will be by then.
func _way_round(from: Vector3, via: Variant, to: Vector3, moving: Vector3) -> float:
	if via == null:
		return INF
	var point := via as Vector3
	var seconds := (from.distance_to(point) + point.distance_to(to)) / _bus.max_speed
	return from.distance_to(point) + point.distance_to(to + moving * seconds)


# Whether the leg from a to b passes within clear of the star between its ends. A leg
# nearest the star at an end only heads in or out, as from an overheat or into Ember.
static func _crosses(a: Vector3, b: Vector3, clear: float) -> bool:
	var nearest := Geometry3D.get_closest_point_to_segment(Vector3.ZERO, a, b)
	return (
		nearest.length() < clear
		and not nearest.is_equal_approx(a)
		and not nearest.is_equal_approx(b)
	)


# With an asteroid field between the bus and [param planet], waypoints either end of the
# gap that makes the way shortest, with neither leg to and from it among the rocks. None
# when no gap does.
func _through_gap(planet: Planet) -> void:
	var fields := _star_map.get_current().find_children("*", "AsteroidField", true, false)
	if fields.is_empty() or _bus.get_route_stops().size() != 1:
		return
	var field := fields[0] as AsteroidField
	var from := _bus.global_position
	var to := planet.get_body_global_position()
	if not _hits_rocks(field, from, to):
		return
	var best := INF
	var way: Array[Vector3] = []
	for i: int in field.belt.gap_angles.size():
		var ends := _gap_ends(field, i, from)
		if _hits_rocks(field, from, ends[0]) or _hits_rocks(field, ends[1], to):
			continue
		# Round the star to the gap, or from it, where the straight leg would cross it.
		var points: Array[Vector3] = [from]
		points.append_array(_round_star(from, ends[0]))
		points.append_array(ends)
		points.append_array(_round_star(ends[1], to))
		points.append(to)
		var length := 0.0
		for j: int in points.size() - 1:
			length += points[j].distance_to(points[j + 1])
		if length < best:
			best = length
			way = points.slice(1, -1)
	if way.is_empty():
		return
	var stop := _bus.get_route_stops()[0]
	_bus.plot_course(RouteStop.at_point(way[0]))
	for point: Vector3 in way.slice(1):
		_bus.plot_course(RouteStop.at_point(point), true)
	_bus.plot_course(stop, true)


# The waypoint round the star between [param a] and [param b], or none when the straight
# leg already keeps clear of the hot zone.
func _round_star(a: Vector3, b: Vector3) -> Array[Vector3]:
	var star := (_star_map.get_current().get_node(^"Star") as Node3D).global_position
	var temperature := _bus.temperature
	var clear := temperature.hot_zone_radius + HOT_ZONE_MARGIN
	var out := temperature.zone_radius + HEAT_ZONE_MARGIN
	var via: Variant = around(RouteStop.flat(a - star), RouteStop.flat(b - star), clear, out)
	if via == null:
		return []
	return [star + (via as Vector3)]


# The points just outside the band either end of the gap at [param index], where the gap
# will be once the bus gets there from [param from]: the near end first.
func _gap_ends(field: AsteroidField, index: int, from: Vector3) -> Array[Vector3]:
	var belt := field.belt
	var centre := field.global_position
	var outside := RouteStop.flat(from - centre).length() > belt.outer_radius
	var radii := [belt.outer_radius + GAP_MARGIN, belt.inner_radius - GAP_MARGIN]
	if not outside:
		radii.reverse()
	var turn := TAU / field.orbit_period if field.orbit_period != 0.0 else 0.0
	var ends: Array[Vector3] = []
	var direction := field.global_basis * AsteroidBelt.get_gap_direction(belt.gap_angles[index])
	direction = RouteStop.flat(direction).normalized()
	for radius: float in radii:
		var point := centre + direction * radius
		# Twice, since where the gap will be moves how far it is.
		for i: int in 2:
			var seconds := from.distance_to(point) / _bus.max_speed + GAP_LEAD
			point = centre + direction.rotated(Vector3.UP, turn * seconds) * radius
		ends.append(point)
	return ends


# Whether the straight leg from [param a] to [param b] passes among the field's rocks.
static func _hits_rocks(field: AsteroidField, a: Vector3, b: Vector3) -> bool:
	var steps := maxi(ceili(a.distance_to(b) / ROCK_STEP), 1)
	for i: int in steps + 1:
		var at := field.to_local(a.lerp(b, float(i) / steps))
		if field.belt.is_in_band(at, -field.clearance) and not field.belt.is_in_gap(at):
			return true
	return false
