class_name RouteStop
extends RefCounted
## One point on the bus's route: a planet, or a fixed point in space.

## The planet to fly to, or null for a point in space.
var planet: Planet
## The point in space, in global coordinates. Unused for a planet.
var point := Vector3.ZERO


static func at_planet(target: Planet) -> RouteStop:
	var stop := RouteStop.new()
	stop.planet = target
	return stop


static func at_point(target: Vector3) -> RouteStop:
	var stop := RouteStop.new()
	stop.point = target
	return stop


## Whether [param stop] is a planet, for filtering a route.
static func is_planet(stop: RouteStop) -> bool:
	return stop.planet != null


## The point [param gap] off [param target]'s surface in [param direction] from its centre,
## on the orbit plane.
static func approach_point(target: Planet, direction: Vector3, gap: float) -> Vector3:
	var center := _flat(target.get_body_global_position())
	return center + direction * (target.get_body_radius() + gap)


static func _flat(at: Vector3) -> Vector3:
	return Vector3(at.x, 0.0, at.z)


## Where the bus heads for this stop coming from [param from], on the orbit plane: the
## planet's side facing [param from], [param gap] off its surface, or the point itself.
func get_target(from: Vector3, gap: float) -> Vector3:
	if not planet:
		return _flat(point)
	var flat := _flat(from - planet.get_body_global_position())
	var direction := flat.normalized() if flat.length_squared() > 1e-6 else Vector3.BACK
	return approach_point(planet, direction, gap)
