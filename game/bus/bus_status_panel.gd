class_name BusStatusPanel
extends VBoxContainer
## The bus's status on the bottom edge of the screen, in two bars. The route bar on top
## ([RouteBar]) shows what the bus is doing and the route ahead. The bus bar under it shows
## its fuel, its temperature and the Frameshift key ([FrameshiftKey]), which Space works
## too. With a course set and the bus waiting, holding the key charges the drive and the key
## fills as it does; let go, the charge drains. Charged, the key pops up by itself as the
## bus leaves. While the bus flies under its own power the key is Stop, and it is off
## otherwise. It reads [member bus] every frame. It stays anchored to the bottom edge as the
## route bar opens and closes.

const FUEL_COLOR := Color(0.6, 0.95, 1.0, 1.0)
const FUEL_LOW_COLOR := Color(0.95, 0.3, 0.4, 1.0)
# At or under this share of a full tank, the fuel shows in FUEL_LOW_COLOR.
const FUEL_LOW := 0.25
const TEMPERATURE_COLOR := Color(0.549, 0.851, 0.4, 1.0)
const TEMPERATURE_HIGH_COLOR := Color(0.98, 0.8, 0.38, 1.0)
## Degrees from which the temperature shows in TEMPERATURE_HIGH_COLOR and a warning shows.
## Overheated, it shows in FUEL_LOW_COLOR until it has cooled down.
const TEMPERATURE_HIGH := 45.0

## The bus whose status it shows.
@export var bus: FrameshiftBus:
	set(value):
		bus = value
		if is_node_ready():
			(%RouteBar as RouteBar).bus = bus

# The fuel bar's fill, a copy of the scene's, so its colour can change.
var _fuel_fill: StyleBoxFlat
var _fuel_low := false
var _temperature_color := TEMPERATURE_COLOR
# Whether the drive charged last frame, to pop the key up the moment the bus leaves.
var _was_charging := false


func _ready() -> void:
	var bar := %FuelBar as ProgressBar
	_fuel_fill = (bar.get_theme_stylebox(&"fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
	bar.add_theme_stylebox_override(&"fill", _fuel_fill)
	(%RouteBar as RouteBar).bus = bus
	_show()


func _process(_delta: float) -> void:
	_show()
	# Anchored to the bottom, it grows up as the route bar opens, and shrinks back down.
	# Any room left over sits above the bars (alignment end), so the bus bar never lifts
	# off the bottom edge.
	offset_top = offset_bottom - get_combined_minimum_size().y


func _show() -> void:
	if not bus:
		return
	var charging := bus.state == FrameshiftBus.State.CHARGING
	var key := %FrameshiftKey as FrameshiftKey
	var flying := bus.state == FrameshiftBus.State.FLYING
	var can_stop := flying and not bus.is_stopping() and not bus.is_towing()
	key.disabled = not (charging or can_stop or RouteBar.is_ready(bus))
	key.stop = can_stop
	if _was_charging and flying:
		key.release()
	_was_charging = charging
	# A charge that hasn't moved yet, as while passengers board, still latches the key.
	key.charge = maxf(bus.get_charge_progress(), 0.02) if charging else 0.0
	_show_fuel()
	_show_temperature()


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


func _show_temperature() -> void:
	var temperature := bus.temperature
	(%TemperatureBar as TemperatureGauge).degrees = temperature.temperature
	var amount := %TemperatureAmount as Label
	_set_text(amount, "%d°" % roundi(temperature.temperature))
	var color := TEMPERATURE_COLOR
	if temperature.is_cooling():
		color = FUEL_LOW_COLOR
	elif temperature.temperature >= TEMPERATURE_HIGH:
		color = TEMPERATURE_HIGH_COLOR
	if color == _temperature_color:
		return
	_temperature_color = color
	(%TemperatureIcon as TextureRect).self_modulate = color
	if color == TEMPERATURE_COLOR:
		amount.remove_theme_color_override(&"font_color")
	else:
		amount.add_theme_color_override(&"font_color", color)


# Sets text only when it changes, since this runs every frame.
func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


# The frameshift action (Space) works the key as a click does, whatever has focus, so it
# needn't be clicked first. _input, not _unhandled_input: a focused button would take Space
# as its own press. Not while text is typed, as in the dev console, or while the bar hides.
func _input(event: InputEvent) -> void:
	if not event.is_action(&"frameshift") or event.is_echo():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	var key := %FrameshiftKey as FrameshiftKey
	if not key.is_visible_in_tree():
		return
	if event.is_pressed():
		if key.disabled:
			return
		Audio.play_sfx(BusKey.CLICK)
		_on_frameshift_key_button_down()
	else:
		_on_frameshift_key_button_up()
	get_viewport().set_input_as_handled()


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
