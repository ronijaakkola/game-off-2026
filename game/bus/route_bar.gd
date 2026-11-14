class_name RouteBar
extends PanelContainer
## The upper of the bus's two bars on the bottom edge of the screen. A header says what the
## bus is doing; with a route it adds, at its right, the time the whole route takes and,
## with the fuel forecast trait, the fuel the whole route burns, red when that is more than
## the tank holds now. Under the header, the route as a line to scale ([RouteStrip]): from
## where the bus set off or waits, through each planet ahead, to a point in space where the
## route ends at one. A point in space on the way to a planet isn't drawn. A planet ahead,
## or the point the route ends at, offers an X that takes it off the route
## ([method FrameshiftBus.remove_stop]), except during a tow.
## With no route to draw it is one row, with an icon before the text, and it opens to two
## when a route is set: its height eases out to the new one while the line fades in, and
## back. Under Reduce motion the height changes at once and only the fade is left.
## The text morphs into new text as a passenger's activity does ([MorphLabel]); the time
## and fuel just tick. Docked at the end of a route it reads "Route complete" for
## [constant COMPLETE_SECONDS]. It reads [member bus] every frame.

const COMPLETE_SECONDS := 4.0
## Seconds it takes to open to two rows, and to close back to one, easing out.
const OPEN_SECONDS := 0.3
const CLOSE_SECONDS := 0.2
## Pixels the line takes under the header when open, with the room around it.
const LINE_ROOM := 22.0
## Pixels the icon before the text takes with its gap, in one row.
const ICON_ROOM := 20.0
## The room above and under the header, so one row is 28 px and two are 50.
const PADDING := 5.0
const TEXT_COLOR := Color(0.957, 0.945, 1.0, 1.0)
const DIM_COLOR := Color(0.957, 0.945, 1.0, 0.651)
const DIM_ICON_COLOR := Color(0.957, 0.945, 1.0, 0.4)
const DONE_COLOR := Color(0.549, 0.851, 0.4, 1.0)
# What the bus is doing, waiting with no route or charging.
const STATE_TEXTS := {
	FrameshiftBus.State.DOCKED: "No route",
	FrameshiftBus.State.CHARGING: "Charging frameshift",
}
const ROUTE_ICON := preload("res://game/bus/icons/route.svg")
const FUEL_ICON := preload("res://shared/icons/fuel.svg")
const DONE_ICON := preload("res://shared/icons/circle_check.svg")

## The bus whose route it shows.
var bus: FrameshiftBus

# Where the line starts: the stop the bus last reached, or where it waits.
var _origin: RouteStop
# The last planet on the route while the bus parks there, after it left the route.
var _arriving: RouteStop
# The route as it was last frame, to tell which stop the bus reached.
var _ahead: Array[RouteStop] = []
# The stop the leg the bus flies ends at, to start its progress again when that changes.
var _leg_end: RouteStop
# How far along the leg it flies the bus is. It never moves back: a planet that moves
# away slows it instead.
var _progress := 0.0
var _complete_left := 0.0
var _was_towing := false
var _open := false
var _started := false
# The open or close under way: where it started, how long it has run and takes. It runs
# in _process rather than a Tween: tweens step after every node, so the bus status panel
# and the HUD would place themselves by last frame's height and lag the bar.
var _resize_from := 0.0
var _resize_time := 0.0
var _resize_seconds := 0.0


func _ready() -> void:
	# Before the bus status panel and the HUD, which place themselves by its height.
	process_priority = -1
	var style := get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	style.content_margin_top = PADDING
	style.content_margin_bottom = PADDING
	add_theme_stylebox_override(&"panel", style)
	_set_openness(0.0)
	var strip := %RouteStrip as RouteStrip
	strip.can_remove = _can_remove
	strip.remove_pressed.connect(_on_remove_pressed)


func _process(delta: float) -> void:
	if not bus:
		return
	var route := bus.get_route_stops()
	_track(route)
	_complete_left = maxf(_complete_left - delta, 0.0) if route.is_empty() else 0.0
	var stops := _drawn_stops(route)
	var open := stops.size() > 1
	if open and stops[1] != _leg_end:
		_leg_end = stops[1]
		_progress = 0.0
	_show_status(open)
	if open:
		var legs := _legs(route)
		(%RouteStrip as RouteStrip).show_route(stops, legs, _bus_progress(legs), not _open)
		_show_totals()
	_set_open(open)
	_resize_step(delta)
	_was_towing = bus.is_towing()


func _can_remove(stop: RouteStop) -> bool:
	return bus != null and not bus.is_towing() and bus.get_route_stops().has(stop)


func _on_remove_pressed(stop: RouteStop) -> void:
	if bus:
		bus.remove_stop(stop)


## Whether [param waiting_bus] waits, docked or holding in space, with a course for the
## drive to charge for. A course always has fuel, and a tow is in flight.
static func is_ready(waiting_bus: FrameshiftBus) -> bool:
	var waiting := waiting_bus.state in [FrameshiftBus.State.DOCKED, FrameshiftBus.State.HOLDING]
	return waiting and waiting_bus.get_last_stop() != null


# Keeps where the line starts as the bus reaches stops: a planet it docks at on the way,
# the last planet once docked, or a point in space it ends at. Otherwise it is where the
# bus waits.
func _track(route: Array[RouteStop]) -> void:
	if not _ahead.is_empty() and not route.has(_ahead[0]):
		_reach(_ahead[0], route)
	_ahead = route
	if bus.state == FrameshiftBus.State.DOCKED and _arriving:
		_set_origin(_arriving)
		_arriving = null
		if route.is_empty() and not _was_towing:
			_complete_left = COMPLETE_SECONDS
	var docked := bus.get_docked_planet()
	if bus.is_at_planet() and (not _origin or _origin.planet != docked):
		_set_origin(RouteStop.at_planet(docked))
	elif bus.state == FrameshiftBus.State.HOLDING and not _is_at_origin_point():
		_set_origin(RouteStop.at_point(bus.global_position))
	elif not _origin:
		# Set off before the bar first saw it wait, as a script can make it.
		_set_origin(RouteStop.at_point(bus.global_position))


# [param stop] left the front of the route: reached, unless the player took it off.
func _reach(stop: RouteStop, route: Array[RouteStop]) -> void:
	var parking := bus.state == FrameshiftBus.State.PARKING
	if stop.planet and parking and stop.planet == bus.get_docked_planet():
		if route.is_empty():
			_arriving = stop
		else:
			_set_origin(stop)
	elif not stop.planet and route.is_empty() and bus.state == FrameshiftBus.State.HOLDING:
		_set_origin(stop)


func _set_origin(stop: RouteStop) -> void:
	_origin = stop
	_progress = 0.0


func _is_at_origin_point() -> bool:
	if not _origin or _origin.planet:
		return false
	var off := _origin.point - bus.global_position
	return Vector2(off.x, off.z).length() < 0.5


# The stops the line shows: where it starts, each planet ahead, and the point in space
# the route ends at, if it does.
func _drawn_stops(route: Array[RouteStop]) -> Array[RouteStop]:
	var drawn: Array[RouteStop] = []
	if _origin:
		drawn.append(_origin)
	if _arriving:
		drawn.append(_arriving)
	for i: int in route.size():
		if route[i].planet or i == route.size() - 1:
			drawn.append(route[i])
	return drawn


# The length of each leg the line draws, as straight lines through every stop, the
# checkpoints included. The first runs from where the line starts, through the bus.
func _legs(route: Array[RouteStop]) -> PackedFloat32Array:
	var legs := PackedFloat32Array()
	var at := bus.global_position
	var length := RouteStop.flat(_origin.get_target(at, bus.dock_gap)).distance_to(
		RouteStop.flat(at)
	)
	var ahead: Array[RouteStop] = []
	if _arriving:
		ahead.append(_arriving)
	ahead.append_array(route)
	for i: int in ahead.size():
		var to := ahead[i].get_target(at, bus.dock_gap)
		length += RouteStop.flat(at).distance_to(RouteStop.flat(to))
		at = to
		if ahead[i].planet or i == ahead.size() - 1:
			legs.append(length)
			length = 0.0
	return legs


# How far along the first leg the bus is, or -1 while it waits at the start: docked or
# holding, charging, or parking at a planet on its way.
func _bus_progress(legs: PackedFloat32Array) -> float:
	var flying := bus.state == FrameshiftBus.State.FLYING
	if not flying and not (bus.state == FrameshiftBus.State.PARKING and _arriving):
		return -1.0
	if _arriving and not flying:
		_progress = 1.0
	else:
		var at := bus.global_position
		var flown := RouteStop.flat(_origin.get_target(at, bus.dock_gap)).distance_to(
			RouteStop.flat(at)
		)
		# The bus is at the planet, its nose at the edge, where its glide into the dock
		# starts.
		var docks := bus.get_next_planet() != null
		var end := legs[0] - (FrameshiftBus.DOCK_DISTANCE if docks else 0.0)
		if end > 0.0:
			_progress = maxf(_progress, clampf(flown / end, 0.0, 1.0))
	return _progress


func _show_status(open: bool) -> void:
	var text := _status_text()
	var color := TEXT_COLOR if open else DIM_COLOR
	var icon := ROUTE_ICON
	var icon_color := DIM_ICON_COLOR
	if text.begins_with("Out of fuel"):
		icon = FUEL_ICON
		color = BusStatusPanel.FUEL_LOW_COLOR
		icon_color = color
	elif _complete_left > 0.0:
		icon = DONE_ICON
		color = TEXT_COLOR
		icon_color = DONE_COLOR
	var label := %StateLabel as MorphLabel
	label.morph_to(text)
	# After the morph starts, which keeps the old text's colour for its letters leaving.
	if label.get_theme_color(&"font_color") != color:
		label.add_theme_color_override(&"font_color", color)
	var state_icon := %StateIcon as TextureRect
	state_icon.texture = icon
	state_icon.self_modulate = icon_color


func _status_text() -> String:
	if bus.get_fuel_tank().is_empty() and not bus.is_towing():
		return "Out of fuel: refuel here" if bus.is_at_planet() else "Out of fuel"
	if _complete_left > 0.0:
		return "Route complete"
	if is_ready(bus):
		return "Press Frameshift to go on" if bus.get_warmth() > 0.0 else "Hold Frameshift to leave"
	match bus.state:
		FrameshiftBus.State.FLYING, FrameshiftBus.State.PARKING:
			return _flying_text()
	return STATE_TEXTS.get(bus.state, "Holding in space")


func _flying_text() -> String:
	if bus.is_stopping():
		return "Stopping"
	var next := bus.get_next_planet()
	if not next:
		return "Heading to a point in space"
	var verb := "Docking to" if bus.is_docking() else "Travelling to"
	if bus.is_towing():
		verb = "Towed to"
	return "%s %s" % [verb, next.display_name if next.display_name else String(next.name)]


# The time the whole route takes and, with the fuel forecast, the fuel it burns.
func _show_totals() -> void:
	_set_text(%TimeLabel, _time_text(RouteTime.estimate(bus)))
	var forecast := bus.get_stats().get_traits().has(BusTraits.Type.FUEL_FORECAST)
	var fuel_stat := %FuelStat as Control
	fuel_stat.visible = forecast and not bus.is_towing()
	if not fuel_stat.visible:
		return
	var tank := bus.get_fuel_tank()
	var burn := FuelForecast.estimate(bus)
	_set_text(%FuelLabel, "%d%%" % ceili(burn / tank.capacity * 100.0))
	var short := burn > tank.fuel
	var color := BusStatusPanel.FUEL_LOW_COLOR if short else BusStatusPanel.FUEL_COLOR
	(%FuelIcon as CanvasItem).self_modulate = color
	var label := %FuelLabel as Label
	if short:
		label.add_theme_color_override(&"font_color", color)
	else:
		label.remove_theme_color_override(&"font_color")


func _time_text(seconds: float) -> String:
	var whole := ceili(maxf(seconds, 0.0))
	if whole < 60:
		return "%d s" % whole
	return "%d:%02d" % [whole / 60, whole % 60]


# Opens to two rows or closes to one, easing from where it is. The first frame sets it.
func _set_open(open: bool) -> void:
	if open == _open and _started:
		return
	_open = open
	if not _started:
		_started = true
		_set_openness(1.0 if open else 0.0)
		return
	_resize_from = (%LineRoom as Control).modulate.a
	_resize_time = 0.0
	_resize_seconds = OPEN_SECONDS if open else CLOSE_SECONDS


# Moves the open or close on by [param delta] seconds, easing out (cubic).
func _resize_step(delta: float) -> void:
	if _resize_seconds <= 0.0:
		return
	_resize_time = minf(_resize_time + delta, _resize_seconds)
	var done := _resize_time / _resize_seconds
	var eased := 1.0 - pow(1.0 - done, 3.0)
	_set_openness(lerpf(_resize_from, 1.0 if _open else 0.0, eased))
	if done >= 1.0:
		_resize_seconds = 0.0


# 0 is one row, 1 two. Under Reduce motion the size goes straight to where it heads, and
# only the fade eases.
func _set_openness(amount: float) -> void:
	var size_amount := (1.0 if _open else 0.0) if Settings.reduce_motion else amount
	var line_room := %LineRoom as Control
	line_room.custom_minimum_size.y = LINE_ROOM * size_amount
	line_room.modulate.a = amount
	(%IconRoom as Control).custom_minimum_size.x = ICON_ROOM * (1.0 - size_amount)
	(%StateIcon as CanvasItem).modulate.a = 1.0 - amount
	(%Totals as CanvasItem).modulate.a = amount


# Sets text only when it changes, since this runs every frame.
func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text
