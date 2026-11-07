class_name WaitingMarkers
extends Control
## Under each planet where someone waits, a small person and how many wait there, so the
## player sees who waits where while planning a route. Kept up to date as passengers arrive
## and board. The parent places each marker on screen.

## The person's colour, the same off-white lilac as the planets' names.
const COLOR := Color(0.93, 0.92, 1.0, 0.85)
## A thin outline in the sky's navy, as on the planets' names.
const OUTLINE_COLOR := Color(0.08, 0.07, 0.18, 0.7)
const FONT_SIZE := 12
const OUTLINE_SIZE := 3
## Pixels between the person and the count.
const SPACING := 3

## Who waits at each planet.
@export var waiting: WaitingPassengers:
	set(value):
		if waiting:
			waiting.changed.disconnect(_on_waiting_changed)
		waiting = value
		if waiting:
			waiting.changed.connect(_on_waiting_changed)
		for planet: Planet in _markers:
			_show_waiting(planet)

var _markers: Dictionary[Planet, HBoxContainer] = {}
var _counts: Dictionary[Planet, int] = {}


## The planets to show a marker for. Replaces any markers from before.
func set_planets(planets: Array[Planet]) -> void:
	for marker: HBoxContainer in _markers.values():
		marker.queue_free()
	_markers.clear()
	_counts.clear()
	for planet: Planet in planets:
		var marker := _marker()
		add_child(marker)
		_markers[planet] = marker
		_show_waiting(planet)


## Centres [param planet]'s marker on [param screen_point] horizontally, its top edge on
## it, and shows it while someone waits there, or hides it with [param shown] false.
func place(planet: Planet, screen_point: Vector2, shown := true) -> void:
	var marker: HBoxContainer = _markers.get(planet)
	if not marker:
		return
	marker.visible = shown and count_at(planet) > 0
	marker.reset_size()
	marker.position = screen_point - Vector2(marker.size.x * 0.5, 0.0)


## How many the marker under [param planet] says wait there.
func count_at(planet: Planet) -> int:
	return _counts.get(planet, 0)


## Whether the marker under [param planet] shows.
func is_shown(planet: Planet) -> bool:
	var marker: HBoxContainer = _markers.get(planet)
	return marker != null and marker.visible


func _marker() -> HBoxContainer:
	var marker := HBoxContainer.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_theme_constant_override(&"separation", SPACING)
	var person := PersonIcon.new()
	person.color = COLOR
	marker.add_child(person)
	var count := Label.new()
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_theme_font_size_override(&"font_size", FONT_SIZE)
	count.add_theme_color_override(&"font_color", COLOR)
	count.add_theme_color_override(&"font_outline_color", OUTLINE_COLOR)
	count.add_theme_constant_override(&"outline_size", OUTLINE_SIZE)
	marker.add_child(count)
	return marker


func _show_waiting(planet: Planet) -> void:
	var marker: HBoxContainer = _markers.get(planet)
	if not marker:
		return
	_counts[planet] = waiting.count_at(planet) if waiting else 0
	(marker.get_child(1) as Label).text = str(_counts[planet])


func _on_waiting_changed(planet: Planet) -> void:
	_show_waiting(planet)
