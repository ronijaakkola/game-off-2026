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
