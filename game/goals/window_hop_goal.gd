class_name WindowHopGoal
extends HopGoal
## A quest: bring the bus to a halt near [member planet], a moon, while its hop window is
## open, with [member passenger] on board, so they can hop out there. The window is open
## while the moon is inside its star's hot zone, which it swings into once each turn round
## its own planet. It is done when the bus holds still in space within [member radius] of
## the moon's centre, or is at the moon, parking, docked or charging, while the window is
## open; a halt outside the window does nothing, and the next window comes round. It fails
## as a hop does.

## How far from the moon's centre the bus may come to rest, in units: at the moon's closest
## the zone's outer rim is on the hot zone's edge.
const WINDOW_RADIUS := 1.8

## The moon they want to hop out near.
var planet: Planet
# What the player was last shown, so a change is told once: whether the window was open,
# and the whole seconds to go.
var _shown_open := false
var _shown_seconds := -1


func _init(who: Passenger, near: Planet) -> void:
	super(who, Vector3.ZERO)
	planet = near
	radius = WINDOW_RADIUS


func get_text() -> String:
	return "Bring bus to halt near %s when it is hot enough" % planet.display_name


func get_spot() -> Vector3:
	return planet.get_body_global_position()


func is_open() -> bool:
	return RouteStop.flat(get_spot() - _get_star()).length() <= _get_reach()


func get_window_text() -> String:
	var time := Vip.format_time(get_window_seconds())
	return ("Hot enough for %s" if is_open() else "Hot enough in %s") % time


## Seconds until the window closes, while it is open, or opens: as long as it takes with
## the bus in flight, and twice that with it stopped, as the orbits slow then.
func get_window_seconds() -> float:
	var orbits := planet.get_parent() as Planet
	if not orbits or planet.orbit_period == 0.0 or orbits.orbit_period == 0.0:
		return 0.0
	# How fast the moon gains on the line from its planet to the star, in radians a second.
	var rate := TAU / planet.orbit_period - TAU / orbits.orbit_period
	if rate <= 0.0:
		return 0.0
	var half := get_window_half_angle()
	var center := orbits.get_body_global_position()
	var angle := wrapf(_get_angle(get_spot() - center) - _get_angle(_get_star() - center), -PI, PI)
	var left := half - angle if is_open() else wrapf(-half - angle, 0.0, TAU)
	return maxf(left, 0.0) / rate


## Half the angle of the moon's orbit that lies inside the hot zone, in radians, to either
## side of the line from its planet to the star. 0 for a moon that never comes inside.
func get_window_half_angle() -> float:
	var orbits := planet.get_parent() as Planet
	if not orbits:
		return 0.0
	var center := orbits.get_body_global_position()
	var far := RouteStop.flat(_get_star() - center).length()
	var near := RouteStop.flat(get_spot() - center).length()
	if far <= 0.0 or near <= 0.0:
		return 0.0
	var reach := _get_reach()
	return acos(clampf((far * far + near * near - reach * reach) / (2.0 * far * near), -1.0, 1.0))


func _on_bus_moved(position: Vector3, on_board: Array[Passenger], in_flight: bool) -> void:
	super(position, on_board, in_flight)
	var open := is_open()
	var seconds := ceili(get_window_seconds())
	if is_active() and (open != _shown_open or seconds != _shown_seconds):
		_shown_open = open
		_shown_seconds = seconds
		changed.emit()


func _on_bus_stopped_at(at: Planet, on_board: Array[Passenger]) -> void:
	if at == planet and passenger in on_board and is_open():
		_complete()


func _get_star() -> Vector3:
	return planet.star_system.global_position


func _get_reach() -> float:
	return planet.star_system.get_hot_zone_radius()


# The angle of [param offset] on the orbit plane, counter-clockwise seen from above, as
# the planets go.
static func _get_angle(offset: Vector3) -> float:
	return atan2(-offset.z, offset.x)
