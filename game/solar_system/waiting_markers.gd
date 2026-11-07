class_name WaitingMarkers
extends Control
## A row of small destination icons under each planet, one for each passenger waiting
## there, longest waiting first, so the player sees who waits where while planning a route.
## Kept up to date as passengers arrive and board. The parent places each row on screen.

const ICON_SHADER := preload("res://game/passengers/planet_icon.gdshader")
## Each icon's size on screen, in pixels.
const ICON_PIXELS := 12.0
## Pixels between icons.
const SPACING := 3

## Who waits at each planet.
@export var waiting: WaitingPassengers:
	set(value):
		if waiting:
			waiting.changed.disconnect(_on_waiting_changed)
		waiting = value
		if waiting:
			waiting.changed.connect(_on_waiting_changed)
		for planet: Planet in _rows:
			_show_waiting(planet)

var _rows: Dictionary[Planet, HBoxContainer] = {}


## The planets to show a row for. Replaces any rows from before.
func set_planets(planets: Array[Planet]) -> void:
	for row: HBoxContainer in _rows.values():
		row.queue_free()
	_rows.clear()
	for planet: Planet in planets:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override(&"separation", SPACING)
		add_child(row)
		_rows[planet] = row
		_show_waiting(planet)


## Centres [param planet]'s row on [param screen_point] horizontally, its top edge on it,
## and shows it, or hides it with [param shown] false.
func place(planet: Planet, screen_point: Vector2, shown := true) -> void:
	var row: HBoxContainer = _rows.get(planet)
	if not row:
		return
	row.visible = shown and row.get_child_count() > 0
	row.reset_size()
	row.position = (screen_point - Vector2(row.size.x * 0.5, 0.0)).round()


## How many icons [param planet]'s row shows.
func count_at(planet: Planet) -> int:
	var row: HBoxContainer = _rows.get(planet)
	return row.get_child_count() if row else 0


func _show_waiting(planet: Planet) -> void:
	var row: HBoxContainer = _rows.get(planet)
	if not row:
		return
	for icon: Node in row.get_children():
		row.remove_child(icon)
		icon.queue_free()
	if not waiting:
		return
	for passenger: Passenger in waiting.get_waiting(planet):
		row.add_child(_icon(passenger.destination))


func _icon(destination: Planet) -> PlanetIcon:
	var icon := PlanetIcon.new()
	var shader_material := ShaderMaterial.new()
	shader_material.shader = ICON_SHADER
	icon.material = shader_material
	icon.custom_minimum_size = Vector2.ONE * ICON_PIXELS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.planet = destination
	return icon


func _on_waiting_changed(planet: Planet) -> void:
	_show_waiting(planet)
