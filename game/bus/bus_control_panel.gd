class_name BusControlPanel
extends MarginContainer
## The bus's control panel at the bottom middle of the screen, a wide, low strip. On the
## left, what the bus is doing with the time left to the next planet, over a track from the
## planet it left to that one; then its fuel over a person for each seat, filled while
## taken. On the right, the frameshift
## button: held down, it charges the drive for the route ([member FrameshiftBus.drive_held]),
## filling as the drive charges, and letting go before the bus leaves stops the charge.
## While the bus flies under its own power, it is a red Emergency stop that cancels the
## course at once. Off, it reads why. It reads [member bus] and [member cabin] every frame.

enum Mode { FRAMESHIFT, STOP, OFF }

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
## The Emergency stop's colour, and its colour under the pointer and pressed.
const STOP_COLOR := Color(0.78, 0.16, 0.22, 1.0)
const STOP_HOVER_COLOR := Color(0.9, 0.22, 0.28, 1.0)
const STOP_PRESSED_COLOR := Color(0.6, 0.1, 0.16, 1.0)
## The charge's fill behind the frameshift button's label.
const CHARGE_FILL_COLOR := Color(0.6, 0.95, 1.0, 0.35)

## The bus whose status it shows and whose drive it holds.
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
var _mode := Mode.OFF
# Whether the frameshift button is held down since it was pressed as the frameshift.
var _held := false
# The Emergency stop's look, by the button's stylebox names: copies of the theme's.
var _stop_styles: Dictionary[StringName, StyleBoxFlat] = {}
var _charge_style := StyleBoxFlat.new()


func _ready() -> void:
	var bar := %FuelBar as ProgressBar
	_fuel_fill = (bar.get_theme_stylebox(&"fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
	bar.add_theme_stylebox_override(&"fill", _fuel_fill)
	(%Track as Control).draw.connect(_draw_track)
	(%Seats as Control).draw.connect(_draw_seats)
	_make_button_styles()
	_show()


func _process(_delta: float) -> void:
	_show()


func _notification(what: int) -> void:
	# Hidden while held, it may never see the release.
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_held = false


func _show() -> void:
	if not bus:
		return
	if bus.is_at_planet():
		_from_planet = bus.get_docked_planet()
	elif bus.state == FrameshiftBus.State.HOLDING:
		_from_planet = null
	var next := bus.get_next_planet()
	_set_text(%StateLabel, _state_text(next))
	_show_trip(next)
	_show_fuel()
	_show_seats()
	_show_button()


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
	# Faded rather than hidden, so the panel keeps its height.
	(%Ends as Control).modulate.a = 1.0 if shown else 0.0
	if not shown:
		_trip_planet = null
		_set_text(%EtaLabel, "")
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


# The frameshift button's mode, label, look and charge fill, and the drive's hold.
func _show_button() -> void:
	var mode := _button_mode()
	if mode != _mode:
		_mode = mode
		# A hold that set the bus off doesn't carry over to the next stop.
		_held = false
		_set_stop_look(mode == Mode.STOP)
	var button := %FrameshiftButton as Button
	button.disabled = mode == Mode.OFF
	if button.disabled:
		_held = false
	bus.drive_held = _held and mode == Mode.FRAMESHIFT
	_set_text(%ButtonLabel, _button_text(mode))
	(%ButtonLabel as Label).modulate.a = 0.5 if button.disabled else 1.0
	var fill := %ChargeFill as Control
	fill.position = Vector2.ZERO
	fill.size = Vector2(button.size.x * bus.get_charge_progress(), button.size.y)


func _button_mode() -> Mode:
	var flying := bus.state == FrameshiftBus.State.FLYING
	if bus.is_towing() or bus.get_fuel_tank().is_empty():
		return Mode.OFF
	if flying and not bus.is_stopping():
		return Mode.STOP
	if bus.state == FrameshiftBus.State.CHARGING and not bus.hold_to_charge:
		return Mode.STOP
	var waiting := bus.state != FrameshiftBus.State.PARKING and not flying
	return Mode.FRAMESHIFT if waiting and bus.get_last_stop() else Mode.OFF


func _button_text(mode: Mode) -> String:
	match mode:
		Mode.STOP:
			return "Emergency stop"
		Mode.FRAMESHIFT:
			if bus.state == FrameshiftBus.State.CHARGING:
				return "Frameshifting..."
			return "Boarding..." if _held and bus.boarding else "Hold to frameshift"
	return _off_text()


# Why the button is off.
func _off_text() -> String:
	var text := "Set a course"
	if bus.is_towing():
		text = "Under tow"
	elif bus.get_fuel_tank().is_empty():
		text = "Out of fuel"
	elif bus.is_stopping():
		text = "Stopping"
	elif bus.state == FrameshiftBus.State.PARKING:
		text = "Docking"
	return text


func _make_button_styles() -> void:
	var button := %FrameshiftButton as Button
	var colors := {
		&"normal": STOP_COLOR,
		&"hover": STOP_HOVER_COLOR,
		&"pressed": STOP_PRESSED_COLOR,
		&"hover_pressed": STOP_PRESSED_COLOR,
	}
	for style_name: StringName in colors:
		var style := button.get_theme_stylebox(style_name).duplicate() as StyleBoxFlat
		if not style:
			continue
		style.bg_color = colors[style_name]
		_stop_styles[style_name] = style
	var normal := button.get_theme_stylebox(&"normal") as StyleBoxFlat
	if normal:
		for corner: int in 4:
			_charge_style.set_corner_radius(corner, normal.get_corner_radius(corner))
		_charge_style.corner_detail = normal.corner_detail
	_charge_style.bg_color = CHARGE_FILL_COLOR
	(%ChargeFill as Panel).add_theme_stylebox_override(&"panel", _charge_style)


func _set_stop_look(stop: bool) -> void:
	var button := %FrameshiftButton as Button
	for style_name: StringName in _stop_styles:
		if stop:
			button.add_theme_stylebox_override(style_name, _stop_styles[style_name])
		else:
			button.remove_theme_stylebox_override(style_name)


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


# The Emergency stop acts on the press, so it never waits for a release, and a hold that
# set the bus off can't trigger it by letting go.
func _on_frameshift_button_down() -> void:
	if _mode == Mode.STOP:
		bus.cancel_course()
	elif _mode == Mode.FRAMESHIFT:
		_held = true


func _on_frameshift_button_up() -> void:
	_held = false
