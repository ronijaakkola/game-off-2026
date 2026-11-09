class_name PlanetPanel
extends SidePanel
## The open planet's panel down the right side of the screen: the planet's name and icon,
## and a row for each passenger waiting there, longest waiting first, kept up to date as
## they arrive and board. Under them, the bus's fuel, a full tank's price here, and a
## button to hold down to refuel, with a note under it; the parent pumps the fuel while
## [method is_refuel_held] and sets what shows with [method show_fuel]. All of that is its
## Services tab. A planet with a research tree also has a Research tab, which draws it
## ([ResearchTreeView]); the parent sets what it shows with [method show_research] and
## researches what the player clicks. With one tab, there is no tab bar. It opens on
## Services, and moving straight on to another planet keeps the Research tab where that
## planet has a tree. It slides in when it opens and back out when it closes ([SidePanel]).
## Its close button only asks; the parent closes it.

## The close button was pressed.
signal close_pressed
## The player clicked [param upgrade] in the Research tab, available, with the bus docked.
signal upgrade_clicked(upgrade: Upgrade)

const SERVICES_TAB := 0
const RESEARCH_TAB := 1

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
## Which upgrades are researched, for the Research tab. Without it, the tab shows no states.
var research: Research

var _planet: Planet
var _refuel_held := false
# The fuel bar's fill, a copy of the scene's, so its colour can change. Low fuel shows in
# the bus status's low colour, at the same share of a tank.
var _fuel_fill: StyleBoxFlat
var _fuel_low := false


func _ready() -> void:
	super()
	var bar := %FuelBar as ProgressBar
	_fuel_fill = (bar.get_theme_stylebox(&"fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
	bar.add_theme_stylebox_override(&"fill", _fuel_fill)


## Shows [param planet] and slides in, unless already open, then it only changes planet.
func open(planet: Planet) -> void:
	var moving_on := _planet != null
	_planet = planet
	var tree := planet.research_tree
	var tabs := %Tabs as TabBar
	tabs.visible = tree != null
	if not moving_on or not tree:
		tabs.current_tab = SERVICES_TAB
	(%ResearchView as ResearchTreeView).tree = tree
	_show_tab()
	_show_planet()
	_show_waiting()
	slide_in()


## Slides out past the right edge, then hides: fast with [param swapped], when another
## panel takes its place.
func close(swapped := false) -> void:
	_planet = null
	_refuel_held = false
	slide_out(swapped)


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


## Shows the Research tab's upgrades as [member research] has them, with [param credits]
## and [param points] the player has, and [param can_research] whether the bus is docked
## here. Only what changed is redrawn, so the parent can call it every frame.
func show_research(credits: int, points: Dictionary[Race.Type, int], can_research: bool) -> void:
	if research:
		(%ResearchView as ResearchTreeView).show_state(research, credits, points, can_research)


## Switches to [param tab], [constant SERVICES_TAB] or [constant RESEARCH_TAB]. The
## Research tab only opens where the planet has a tree.
func show_tab(tab: int) -> void:
	if tab == RESEARCH_TAB and not (_planet and _planet.research_tree):
		return
	(%Tabs as TabBar).current_tab = tab
	_show_tab()


func _show_tab() -> void:
	var on_research := (%Tabs as TabBar).current_tab == RESEARCH_TAB
	(%Services as Control).visible = not on_research
	(%ResearchView as Control).visible = on_research


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


func _on_tabs_tab_changed(_tab: int) -> void:
	_show_tab()


func _on_research_view_upgrade_clicked(upgrade: Upgrade) -> void:
	upgrade_clicked.emit(upgrade)


func _on_close_button_pressed() -> void:
	close_pressed.emit()
