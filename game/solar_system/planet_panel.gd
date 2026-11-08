class_name PlanetPanel
extends MarginContainer
## The open planet's panel down the right side of the screen: the planet's name and icon,
## and a row for each passenger waiting there, longest waiting first, kept up to date as
## they arrive and board. Under them, the bus's fuel, a full tank's price here, and a
## button to hold down to refuel, with a note under it; the parent pumps the fuel while
## [method is_refuel_held] and sets what shows with [method show_fuel]. It slides in from
## past the right edge when it opens, over [member slide_in_seconds] so it can arrive with
## the camera, and back out when it closes. Its close button only asks; the parent closes
## it.

## The close button was pressed.
signal close_pressed

const ROW := preload("res://game/solar_system/waiting_passenger_row.tscn")
const SLIDE_OUT_SECONDS := 0.2

## Who waits at each planet.
@export var waiting: WaitingPassengers:
	set(value):
		if waiting:
			waiting.changed.disconnect(_on_waiting_changed)
		waiting = value
		if waiting:
			waiting.changed.connect(_on_waiting_changed)
		if is_node_ready():
			_show_waiting()

## Where the rows' portraits are rendered. Without one, their photos stay empty.
var portrait_studio: PortraitStudio

## Seconds to slide in. It eases in and out, as the camera's blend does.
var slide_in_seconds := 0.7

var _planet: Planet
# The one tween that slides the panel in and out.
var _slide: Tween
var _refuel_held := false
# The fuel bar's fill, a copy of the scene's, so its colour can change. Low fuel shows in
# the bus status's low colour, at the same share of a tank.
var _fuel_fill: StyleBoxFlat
var _fuel_low := false


func _ready() -> void:
	hide()
	var bar := %FuelBar as ProgressBar
	_fuel_fill = (bar.get_theme_stylebox(&"fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
	bar.add_theme_stylebox_override(&"fill", _fuel_fill)


## Shows [param planet] and slides in, unless already open, then it only changes planet.
func open(planet: Planet) -> void:
	_planet = planet
	_show_planet()
	_show_waiting()
	if _slide:
		_slide.kill()
	if not visible:
		show()
		position.x = _off_right()
	_slide = create_tween()
	(
		_slide
		. tween_property(self, ^"position:x", _rest_x(), slide_in_seconds)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN_OUT)
	)


## Slides out past the right edge, then hides.
func close() -> void:
	_planet = null
	_refuel_held = false
	if _slide:
		_slide.kill()
	_slide = create_tween()
	(
		_slide
		. tween_property(self, ^"position:x", _off_right(), SLIDE_OUT_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)
	_slide.tween_callback(hide)


## The planet shown, or null while closed.
func get_planet() -> Planet:
	return _planet


## Whether the refuel button is held down.
func is_refuel_held() -> bool:
	return _refuel_held


## Shows the bus's fuel at [param fraction] of a full tank, [param full_tank_cost] credits
## for a full tank here, and [param note] under the refuel button. With [param can_refuel]
## false the button is off and lets go.
func show_fuel(fraction: float, full_tank_cost: int, can_refuel: bool, note: String) -> void:
	(%FuelBar as ProgressBar).value = fraction
	_set_text(%FuelAmount, "%d%%" % ceili(fraction * 100.0))
	_show_fuel_low(fraction <= BusStatusPanel.FUEL_LOW)
	_set_text(%PriceLabel, "Full tank %d credits" % full_tank_cost)
	_set_text(%FuelNote, note)
	var button := %RefuelButton as Button
	button.disabled = not can_refuel
	if not can_refuel:
		_refuel_held = false
	button.text = "Refuelling..." if _refuel_held else "Hold to refuel"


## How wide the panel is, margins included, so the parent can keep the planet clear of it.
func get_width() -> float:
	return get_combined_minimum_size().x


# Where the anchors put the panel, flush with the right edge.
func _rest_x() -> float:
	return get_parent_area_size().x - size.x


func _off_right() -> float:
	return get_parent_area_size().x


func _show_planet() -> void:
	(%PlanetIcon as PlanetIcon).planet = _planet
	(%PlanetNameLabel as Label).text = _planet_name()


# Keeps the rows of passengers still waiting as they are, so their photos don't change,
# drops those who have gone, and adds a row for each newcomer in their place in the line.
# With [param animate], a newcomer's row slides in from the right.
func _show_waiting(animate: bool = false) -> void:
	var rows := %WaitingRows as Control
	var line: Array[Passenger] = []
	if waiting and _planet:
		line = waiting.get_waiting(_planet)
	var kept: Dictionary[Passenger, WaitingPassengerRow] = {}
	for node: Node in rows.get_children():
		var row := node as WaitingPassengerRow
		if row.passenger in line:
			kept[row.passenger] = row
		else:
			rows.remove_child(row)
			row.queue_free()
	for i: int in line.size():
		var row: WaitingPassengerRow = kept.get(line[i])
		if not row:
			row = ROW.instantiate() as WaitingPassengerRow
			row.portrait_studio = portrait_studio
			row.passenger = line[i]
			rows.add_child(row)
			if animate:
				row.slide_in()
		rows.move_child(row, i)
	(%EmptyLabel as Label).visible = line.is_empty()


func _planet_name() -> String:
	if not _planet:
		return ""
	return _planet.display_name if _planet.display_name else String(_planet.name)


func _on_waiting_changed(planet: Planet) -> void:
	if planet == _planet:
		_show_waiting(true)


func _show_fuel_low(low: bool) -> void:
	if low == _fuel_low:
		return
	_fuel_low = low
	_fuel_fill.bg_color = BusStatusPanel.FUEL_LOW_COLOR if low else BusStatusPanel.FUEL_COLOR
	var amount := %FuelAmount as Label
	if low:
		amount.add_theme_color_override(&"font_color", BusStatusPanel.FUEL_LOW_COLOR)
	else:
		amount.remove_theme_color_override(&"font_color")


# Sets text only when it changes, since the parent calls show_fuel() every frame.
func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


func _on_refuel_button_down() -> void:
	_refuel_held = true


func _on_refuel_button_up() -> void:
	_refuel_held = false


func _on_close_button_pressed() -> void:
	close_pressed.emit()
