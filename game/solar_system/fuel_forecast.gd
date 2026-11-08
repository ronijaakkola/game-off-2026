class_name FuelForecast
extends Control
## Over the route's last stop, how much of the tank the course burns ("-18% fuel"), while
## the bus has the fuel forecast trait. It counts the straight legs from the bus through
## each stop as everything is now, so with planets moving it is an estimate. It turns red
## when the course burns more fuel than the bus has left. It hides with no course, and
## while the bus is towed, since a tow burns none. It places itself after the camera has
## moved each frame.

## The off-white lilac of the planets' names.
const COLOR := Color(0.93, 0.92, 1.0, 0.95)
## The red of low fuel in the bus status.
const SHORT_COLOR := Color(0.95, 0.3, 0.4, 1.0)
## Pixels between the top of the stop on screen and the forecast's lower edge.
const GAP_PIXELS := 4.0
## The process priority Phantom Camera's host sets on itself to move the camera.
const CAMERA_HOST_PRIORITY := 300

## The bus whose course it forecasts.
@export var bus: FrameshiftBus
## The camera the stop is seen through.
@export var camera: Camera3D


## The fuel [param from_bus] burns flying its course from where it is now: the straight
## legs to each stop, short of each planet by where the bus starts to park, which burns
## none. 0 with no course.
static func estimate(from_bus: FrameshiftBus) -> float:
	var at := from_bus.global_position
	var distance := 0.0
	for stop: RouteStop in from_bus.get_route_stops():
		var to := stop.get_target(at, from_bus.dock_gap)
		var leg := Vector2(to.x - at.x, to.z - at.z).length()
		if stop.planet:
			leg = maxf(leg - FrameshiftBus.DOCK_DISTANCE, 0.0)
		distance += leg
		at = to
	return distance * from_bus.get_fuel_tank().burn_per_unit


func _ready() -> void:
	process_priority = CAMERA_HOST_PRIORITY + 1


func _process(_delta: float) -> void:
	var stop := bus.get_last_stop() if bus else null
	var shown := (
		stop != null
		and camera != null
		and not bus.is_towing()
		and bus.get_stats().get_traits().has(BusTraits.Type.FUEL_FORECAST)
	)
	var top := _top_of(stop) if shown else Vector3.ZERO
	shown = shown and not camera.is_position_behind(top)
	(%Label as Control).visible = shown
	if shown:
		_show(estimate(bus), camera.unproject_position(top))


# The top of [param stop] as the camera sees it: a planet's upper edge, or the tip of a
# point's diamond.
func _top_of(stop: RouteStop) -> Vector3:
	if stop.planet:
		var center := stop.planet.get_body_global_position()
		return center + camera.global_basis.y * stop.planet.get_body_radius()
	return stop.point + camera.global_basis.y * bus.get_marker_size()


func _show(cost: float, top: Vector2) -> void:
	var tank := bus.get_fuel_tank()
	var label := %Label as Label
	var percent := roundi(cost / tank.capacity * 100.0) if tank.capacity > 0.0 else 0
	var text := "-%d%% fuel" % percent
	if label.text != text:
		label.text = text
		label.reset_size()
	var short := cost > tank.fuel
	label.add_theme_color_override(&"font_color", SHORT_COLOR if short else COLOR)
	label.position = top - Vector2(label.size.x * 0.5, label.size.y + GAP_PIXELS)
