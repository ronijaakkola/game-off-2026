class_name PlanetPanel
extends SidePanel
## The open planet's panel down the right side of the screen: the planet's name, icon and
## tagline. Under them, a row for each passenger waiting there, longest waiting first,
## kept up to date as they arrive and board, and at its foot a few sentences of the
## planet's lore. It slides in when it opens and back out when it closes ([SidePanel]).
## Its close button only asks; the parent closes it.

## The close button was pressed.
signal close_pressed

const ROW := preload("res://game/solar_system/waiting_passenger_row.tscn")

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

var _planet: Planet


## Shows [param planet] and slides in, unless already open, then it only changes planet.
func open(planet: Planet) -> void:
	_planet = planet
	_show_planet()
	_show_waiting()
	slide_in()


## Slides out past the right edge, then hides: fast with [param swapped], when another
## panel takes its place.
func close(swapped := false) -> void:
	_planet = null
	slide_out(swapped)


## The planet shown, or null while closed.
func get_planet() -> Planet:
	return _planet


func _show_planet() -> void:
	(%PlanetIcon as PlanetIcon).planet = _planet
	(%PlanetNameLabel as Label).text = _planet_name()
	var tagline := %TaglineLabel as Label
	tagline.text = _planet.tagline
	tagline.visible = not _planet.tagline.is_empty()
	(%LoreLabel as Label).text = _planet.lore
	var has_lore := not _planet.lore.is_empty()
	(%Lore as Control).visible = has_lore
	(%LoreRule as Control).visible = has_lore


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


func _on_close_button_pressed() -> void:
	close_pressed.emit()
