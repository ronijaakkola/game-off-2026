class_name PlanetPanel
extends MarginContainer
## The open planet's panel down the right side of the screen: the planet's name and icon,
## and a row for each passenger waiting there, longest waiting first, kept up to date as
## they arrive and board. It slides in from past the right edge when it opens and back out
## when it closes. Its close button only asks; the parent closes it.

## The close button was pressed.
signal close_pressed

const ROW := preload("res://game/solar_system/waiting_passenger_row.tscn")
const SLIDE_IN_SECONDS := 0.3
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

var _planet: Planet
# The one tween that slides the panel in and out.
var _slide: Tween


func _ready() -> void:
	hide()


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
		. tween_property(self, ^"position:x", _rest_x(), SLIDE_IN_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


## Slides out past the right edge, then hides.
func close() -> void:
	_planet = null
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


func _show_waiting() -> void:
	var rows := %WaitingRows as Control
	for row: Node in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	var line: Array[Passenger] = []
	if waiting and _planet:
		line = waiting.get_waiting(_planet)
	for passenger: Passenger in line:
		var row := ROW.instantiate() as WaitingPassengerRow
		row.passenger = passenger
		rows.add_child(row)
	(%EmptyLabel as Label).visible = line.is_empty()


func _planet_name() -> String:
	if not _planet:
		return ""
	return _planet.display_name if _planet.display_name else String(_planet.name)


func _on_waiting_changed(planet: Planet) -> void:
	if planet == _planet:
		_show_waiting()


func _on_close_button_pressed() -> void:
	close_pressed.emit()
