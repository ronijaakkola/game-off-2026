class_name DockGlide
extends RefCounted
## Where a docked bus sits beside its planet, and how it glides there and keeps up with it:
## the planet, the side of it the bus is on, and where the bus is from the planet's centre.
## That offset is kept rather than measured each frame: a planet that moves after the bus
## in a frame would otherwise drag the bus behind it, and it would never park. Everything
## is on the orbit plane.

## The planet the bus is docked at, or null.
var planet: Planet
## From the planet's centre toward the bus.
var direction := Vector3.BACK
## How fast the bus glides toward its dock point, measured from the planet.
var velocity := Vector3.ZERO

var _offset := Vector3.ZERO


## Docks at [param at] on the side [param side] points to, from the planet's centre, with
## the bus at [param from].
func dock(at: Planet, side: Vector3, from: Vector3) -> void:
	planet = at
	var flat := RouteStop.flat(side)
	direction = flat.normalized() if flat.length_squared() > 1e-6 else Vector3.BACK
	_offset = RouteStop.flat(from - at.get_body_global_position())


## The heading that puts the bus's left side, where its door is, toward the planet.
func get_heading() -> float:
	return atan2(-direction.z, direction.x)


## Where the bus docks, [param gap] off the planet's surface.
func get_point(gap: float) -> Vector3:
	return RouteStop.approach_point(planet, direction, gap)


## Glides [param delta] seconds toward the point [param gap] off the surface, measured from
## the planet, and returns where the bus is now.
func follow(delta: float, gap: float) -> Vector3:
	var center := RouteStop.flat(planet.get_body_global_position())
	var weight := 1.0 - exp(-FrameshiftBus.DOCK_SMOOTHING * delta)
	var glided := _offset.lerp(get_point(gap) - center, weight)
	velocity = (glided - _offset) / delta if delta > 0.0 else Vector3.ZERO
	_offset = glided
	return center + glided


## Whether a bus heading [param heading] has parked at the point [param gap] off: there,
## and side-on.
func is_parked(gap: float, heading: float) -> bool:
	var center := RouteStop.flat(planet.get_body_global_position())
	var off := (get_point(gap) - center - _offset).length()
	var turned := absf(angle_difference(heading, get_heading()))
	return off < FrameshiftBus.PARK_DISTANCE and turned < FrameshiftBus.PARK_ANGLE


## Seconds the glide takes from [param distance] out to parked.
static func park_seconds(distance: float) -> float:
	var park := FrameshiftBus.PARK_DISTANCE
	return log(maxf(distance, park) / park) / FrameshiftBus.DOCK_SMOOTHING
