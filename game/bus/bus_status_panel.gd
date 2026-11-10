class_name BusStatusPanel
extends VBoxContainer
## The bus's status on the bottom edge of the screen, in two bars. The route bar on top
## shows the leg the bus is on, as a track from the planet it left to the next one with the
## time left to it, or what the bus is doing when it has no leg. The bus bar under it shows
## its fuel, two small keys that are blank placeholders for now, and the Frameshift key
## ([FrameshiftKey]). With a course set and the bus waiting, holding the key charges the
## drive and the key fills as it does; let go, the charge drains. While the bus flies under
## its own power the key is Stop, and it is off otherwise. It reads [member bus] every frame.

const TRACK_COLOR := Color(1.0, 1.0, 1.0, 0.1412)
const ROUTE_COLOR := Color(1.0, 0.6, 0.22, 1.0)
const BUS_COLOR := Color(0.96, 0.78, 0.29, 1.0)
const END_FILL := Color(0.2, 0.161, 0.322, 1.0)
const FUEL_COLOR := Color(0.6, 0.95, 1.0, 1.0)
const FUEL_LOW_COLOR := Color(0.95, 0.3, 0.4, 1.0)
# At or under this share of a full tank, the fuel shows in FUEL_LOW_COLOR.
const FUEL_LOW := 0.25

## The bus whose status it shows.
@export var bus: FrameshiftBus

# The trip the track shows: the planet it runs to, its estimated time when the bus set off,
# and how far along it the bus is, from 0 to 1. The track never moves back, so a planet
# that moves away slows it down instead.
var _trip_planet: Planet
var _trip_time := 0.0
var _progress := 0.0
# The planet the bus left last, where the track starts. Null for a point in space.
var _from_planet: Planet
# The fuel bar's fill, a copy of the scene's, so its colour can change.
var _fuel_fill: StyleBoxFlat
var _fuel_low := false


func _ready() -> void:
	var bar := %FuelBar as ProgressBar
	_fuel_fill = (bar.get_theme_stylebox(&"fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
	bar.add_theme_stylebox_override(&"fill", _fuel_fill)
	(%Track as Control).draw.connect(_draw_track)
	_show()


func _process(_delta: float) -> void:
	_show()


func _show() -> void:
	if not bus:
		return
	if bus.is_at_planet():
		_from_planet = bus.get_docked_planet()
	elif bus.state == FrameshiftBus.State.HOLDING:
		_from_planet = null
	var next := bus.get_next_planet()
	var charging := bus.state == FrameshiftBus.State.CHARGING
	_set_text(%StateLabel, _state_text(next))
	_show_trip(next if not _is_ready() else null)
	var key := %FrameshiftKey as FrameshiftKey
	var flying := bus.state == FrameshiftBus.State.FLYING
	var can_stop := flying and not bus.is_stopping() and not bus.is_towing()
	key.disabled = not (charging or can_stop or _is_ready())
	key.stop = can_stop
	# A charge that hasn't moved yet, as while passengers board, still latches the key.
	key.charge = maxf(bus.get_charge_progress(), 0.02) if charging else 0.0
	_show_fuel()


func _state_text(next: Planet) -> String:
	if bus.get_fuel_tank().is_empty() and not bus.is_towing():
		return "Out of fuel: refuel here" if bus.is_at_planet() else "Out of fuel"
	if _is_ready():
		return "Hold Frameshift to leave"
	match bus.state:
		FrameshiftBus.State.DOCKED:
			return "No course"
		FrameshiftBus.State.CHARGING:
			return "Charging frameshift"
		FrameshiftBus.State.FLYING, FrameshiftBus.State.PARKING:
			return _flying_text(next)
	return "Holding in space"


func _flying_text(next: Planet) -> String:
	if bus.is_stopping():
		return "Stopping"
	if not next:
		return "Heading to a point in space"
	var verb := "Docking to" if bus.is_docking() else "Travelling to"
	if bus.is_towing():
		verb = "Towed to"
	return "%s %s" % [verb, _planet_name(next)]


# Whether the bus waits, docked or holding in space, with a course for the drive to charge
# for. A course always has fuel, and a tow is in flight.
func _is_ready() -> bool:
	var waiting := bus.state in [FrameshiftBus.State.DOCKED, FrameshiftBus.State.HOLDING]
	return waiting and bus.get_last_stop() != null


func _show_trip(next: Planet) -> void:
	var shown := next != null and not bus.is_stopping()
	for part: Control in [%RouteNudge, %StateLabel]:
		part.visible = not shown
	for part: Control in [%FromLabel, %Track, %ToLabel, %EtaLabel]:
		part.visible = shown
	if not shown:
		_trip_planet = null
		return
	var time_left := bus.estimate_time_to_next_planet()
	# Parking ends the flight, so the track carries on to the end.
	var flying := bus.state in [FrameshiftBus.State.FLYING, FrameshiftBus.State.PARKING]
	if next != _trip_planet or not flying:
		_trip_planet = next
		_trip_time = time_left
		_progress = 0.0
	elif _trip_time > 0.0:
		_progress = maxf(_progress, clampf(1.0 - time_left / _trip_time, 0.0, 1.0))
	(%Track as Control).queue_redraw()
	_set_text(%FromLabel, _planet_name(_from_planet) if _from_planet else "Space")
	_set_text(%ToLabel, _planet_name(next))
	_set_text(%EtaLabel, "%d s" % ceili(time_left))


func _show_fuel() -> void:
	var fraction := bus.get_fuel_tank().get_fraction()
	(%FuelBar as ProgressBar).value = fraction
	_set_text(%FuelAmount, "%d%%" % ceili(fraction * 100.0))
	var low := fraction <= FUEL_LOW
	if low == _fuel_low:
		return
	_fuel_low = low
	_fuel_fill.bg_color = FUEL_LOW_COLOR if low else FUEL_COLOR
	var amount := %FuelAmount as Label
	if low:
		amount.add_theme_color_override(&"font_color", FUEL_LOW_COLOR)
	else:
		amount.remove_theme_color_override(&"font_color")


# A line from end to end, orange up to the bus, with a ring at each end.
func _draw_track() -> void:
	var track := %Track as Control
	var size := track.size
	var y := size.y * 0.5
	var inset := 5.0
	var left := Vector2(inset, y)
	var right := Vector2(size.x - inset, y)
	var at := left.lerp(right, _progress)
	track.draw_line(left, right, TRACK_COLOR, 2.0)
	track.draw_line(left, at, ROUTE_COLOR, 2.0)
	for end: Vector2 in [left, right]:
		track.draw_circle(end, 4.5, END_FILL)
		track.draw_circle(end, 4.5, ROUTE_COLOR, false, 2.0)
	var bus_size := Vector2(12.0, 7.0)
	track.draw_rect(Rect2(at - bus_size * 0.5, bus_size), BUS_COLOR)


func _planet_name(planet: Planet) -> String:
	if not planet:
		return "?"
	return planet.display_name if planet.display_name else String(planet.name)


# Sets text only when it changes, since this runs every frame.
func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


# Stop acts at once. Otherwise the drive charges while the key stays down.
func _on_frameshift_key_button_down() -> void:
	if not bus:
		return
	if (%FrameshiftKey as FrameshiftKey).stop:
		bus.cancel_course()
	else:
		bus.frameshift_held = true


func _on_frameshift_key_button_up() -> void:
	if bus:
		bus.frameshift_held = false
