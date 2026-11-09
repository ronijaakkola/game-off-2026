class_name BusStatusPanel
extends MarginContainer
## The bus's status in the bottom right corner: what it is doing, a track from the planet
## it left to the next one with the time left to it, its fuel, a person for each seat,
## filled while taken, and a button that cancels the course while the bus charges or flies
## under its own power. It reads [member bus] and [member cabin] every frame.

const TRACK_COLOR := Color(1.0, 1.0, 1.0, 0.18)
const ROUTE_COLOR := Color(1.0, 0.6, 0.22, 1.0)
const BUS_COLOR := Color(0.96, 0.78, 0.29, 1.0)
const END_FILL := Color(0.2, 0.16, 0.32, 1.0)
const SEAT_EMPTY := Color(1.0, 1.0, 1.0, 0.18)
# The gap between people, in pixels.
const SEAT_GAP := 2.0
const FUEL_COLOR := Color(0.6, 0.95, 1.0, 1.0)
const FUEL_LOW_COLOR := Color(0.95, 0.3, 0.4, 1.0)
# At or under this share of a full tank, the fuel shows in FUEL_LOW_COLOR.
const FUEL_LOW := 0.25

## The bus whose status it shows.
@export var bus: FrameshiftBus
## The cabin whose seats it shows.
@export var cabin: Cabin

# The trip the track shows: the planet it runs to, its estimated time when the bus set off,
# and how far along it the bus is, from 0 to 1. The track never moves back, so a planet
# that moves away slows it down instead.
var _trip_planet: Planet
var _trip_time := 0.0
var _progress := 0.0
# The planet the bus left last, where the track starts. Null for a point in space.
var _from_planet: Planet
var _seats_shown := Vector2i(-1, -1)
# The fuel bar's fill, a copy of the scene's, so its colour can change.
var _fuel_fill: StyleBoxFlat
var _fuel_low := false


func _ready() -> void:
	var bar := %FuelBar as ProgressBar
	_fuel_fill = (bar.get_theme_stylebox(&"fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
	bar.add_theme_stylebox_override(&"fill", _fuel_fill)
	(%Track as Control).draw.connect(_draw_track)
	(%Seats as Control).draw.connect(_draw_seats)
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
	_show_trip(next)
	(%ChargeBar as ProgressBar).visible = charging
	(%ChargeBar as ProgressBar).value = bus.get_charge_progress()
	var button := %CancelButton as Button
	var flying := bus.state == FrameshiftBus.State.FLYING
	button.visible = charging or (flying and not bus.is_stopping() and not bus.is_towing())
	_set_text(button, "Cancel" if charging else "Cancel route")
	_show_fuel()
	_show_seats()


func _state_text(next: Planet) -> String:
	if bus.get_fuel_tank().is_empty() and not bus.is_towing():
		return "Out of fuel: refuel here" if bus.is_at_planet() else "Out of fuel: tow on its way"
	match bus.state:
		FrameshiftBus.State.DOCKED:
			return "Docked"
		FrameshiftBus.State.CHARGING:
			return "Charging frameshift"
		FrameshiftBus.State.FLYING, FrameshiftBus.State.PARKING:
			return _flying_text(next)
	return "Holding in space"


func _flying_text(next: Planet) -> String:
	if bus.is_stopping():
		return "Stopping"
	if not next:
		return "Heading to waypoint"
	var verb := "Docking to" if bus.is_docking() else "Travelling to"
	if bus.is_towing():
		verb = "Towed to"
	return "%s %s" % [verb, _planet_name(next)]


func _show_trip(next: Planet) -> void:
	var shown := next != null and not bus.is_stopping()
	(%Track as Control).visible = shown
	(%Ends as Control).visible = shown
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


func _show_seats() -> void:
	if not cabin:
		return
	var shown := Vector2i(cabin.get_passengers().size(), cabin.seats)
	if shown == _seats_shown:
		return
	_seats_shown = shown
	_set_text(%SeatLabel, "%d/%d seats" % [shown.x, shown.y])
	var seats := %Seats as Control
	seats.custom_minimum_size = Vector2(
		shown.y * PersonIcon.SIZE.x + maxi(shown.y - 1, 0) * SEAT_GAP, PersonIcon.SIZE.y
	)
	seats.queue_redraw()


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


# A person for each seat, filled while the seat is taken.
func _draw_seats() -> void:
	var seats := %Seats as Control
	for seat: int in _seats_shown.y:
		var color := BUS_COLOR if seat < _seats_shown.x else SEAT_EMPTY
		PersonIcon.draw_person(seats, Vector2(seat * (PersonIcon.SIZE.x + SEAT_GAP), 0.0), color)


func _planet_name(planet: Planet) -> String:
	if not planet:
		return "?"
	return planet.display_name if planet.display_name else String(planet.name)


# Sets text only when it changes, since this runs every frame.
func _set_text(control: Control, text: String) -> void:
	if control is Label and (control as Label).text != text:
		(control as Label).text = text
	elif control is Button and (control as Button).text != text:
		(control as Button).text = text


func _on_cancel_button_pressed() -> void:
	if bus:
		bus.cancel_course()
