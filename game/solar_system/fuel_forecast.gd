class_name FuelForecast
extends Control
## Over the route's last stop, how much of the tank the course burns ("-18% fuel"), while
## the bus has the fuel forecast trait, and over the middle of each leg, when the course has
## more than one, what that leg burns ("-9%"). It counts the straight legs from the bus through
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
## Pixels between a leg on screen and its cost beside it.
const LEG_GAP_PIXELS := 2.0
## The leg costs' font size; the total's is set in the scene.
const LEG_FONT_SIZE := 11
## The process priority Phantom Camera's host sets on itself to move the camera.
const CAMERA_HOST_PRIORITY := 300

## The bus whose course it forecasts.
@export var bus: FrameshiftBus
## The camera the stop is seen through.
@export var camera: Camera3D

# The legs' costs, made as the course first needs them.
var _legs: Array[Label] = []


## The fuel [param from_bus] burns flying its course from where it is now: the straight
## legs to each stop, short of each planet by where the bus starts to park, which burns
## none. 0 with no course.
static func estimate(from_bus: FrameshiftBus) -> float:
	var total := 0.0
	for cost: float in leg_costs(from_bus):
		total += cost
	return total


## The fuel each leg of [param from_bus]'s course burns, in order, as [method estimate]
## counts it.
static func leg_costs(from_bus: FrameshiftBus) -> PackedFloat32Array:
	var points := _leg_ends(from_bus)
	var stops := from_bus.get_route_stops()
	var costs := PackedFloat32Array()
	for i: int in stops.size():
		var leg := Vector2(points[i + 1].x - points[i].x, points[i + 1].z - points[i].z).length()
		if stops[i].planet:
			leg = maxf(leg - FrameshiftBus.DOCK_DISTANCE, 0.0)
		costs.append(leg * from_bus.get_fuel_tank().burn_per_unit)
	return costs


# Where each leg of [param from_bus]'s course starts and ends: the bus, then each stop.
static func _leg_ends(from_bus: FrameshiftBus) -> PackedVector3Array:
	var points := PackedVector3Array([from_bus.global_position])
	for stop: RouteStop in from_bus.get_route_stops():
		points.append(stop.get_target(points[-1], from_bus.dock_gap))
	return points


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
	_show_legs(leg_costs(bus) if shown else PackedFloat32Array())


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


# Each leg's cost over its middle, while the course has more than one leg.
func _show_legs(costs: PackedFloat32Array) -> void:
	if costs.size() < 2:
		costs.clear()
	while _legs.size() < costs.size():
		var total := %Label as Label
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override(&"font_size", LEG_FONT_SIZE)
		label.add_theme_color_override(&"font_color", COLOR)
		label.add_theme_color_override(
			&"font_outline_color", total.get_theme_color(&"font_outline_color")
		)
		label.add_theme_constant_override(
			&"outline_size", total.get_theme_constant(&"outline_size")
		)
		add_child(label)
		_legs.append(label)
	var points := _leg_ends(bus) if not costs.is_empty() else PackedVector3Array()
	var capacity := bus.get_fuel_tank().capacity if bus else 0.0
	for i: int in _legs.size():
		var label := _legs[i]
		var middle := (points[i] + points[i + 1]) * 0.5 if i < costs.size() else Vector3.ZERO
		label.visible = i < costs.size() and not camera.is_position_behind(middle)
		if not label.visible:
			continue
		var percent := roundi(costs[i] / capacity * 100.0) if capacity > 0.0 else 0
		var text := "-%d%%" % percent
		if label.text != text:
			label.text = text
			label.reset_size()
		# Beside the leg, on its upper side, so the line doesn't cross the text.
		var along := camera.unproject_position(points[i + 1]) - camera.unproject_position(points[i])
		var side := Vector2(along.y, -along.x).normalized()
		if side.y > 0.0:
			side = -side
		var reach := absf(side.x) * label.size.x * 0.5 + absf(side.y) * label.size.y * 0.5
		var at := camera.unproject_position(middle) + side * (reach + LEG_GAP_PIXELS)
		label.position = at - label.size * 0.5
