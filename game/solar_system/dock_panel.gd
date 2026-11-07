class_name DockPanel
extends PanelContainer
## What the bus can do at the planet it is docked at, just above the bus status in the
## bottom right corner. For now, who waits there, longest waiting first, each with their
## portrait and a button to pick them up. It is shown while [member planet] is set, and
## kept up to date as they arrive and board; the parent sets [member planet] while the bus
## is docked or charging. The buttons are off while every seat is taken. It only asks;
## the parent picks the passenger up.

## The player pressed the button to pick up [param passenger].
signal board_pressed(passenger: Passenger)

const ROW := preload("res://game/solar_system/boarding_row.tscn")

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
## The seats the buttons check.
@export var cabin: Cabin
## Where the rows' portraits are rendered.
var portrait_studio: PortraitStudio

## The planet the bus is docked at, or null to hide the panel.
var planet: Planet:
	set(value):
		if value == planet:
			return
		planet = value
		if is_node_ready():
			_show_waiting()


func _ready() -> void:
	_show_waiting()


func _process(_delta: float) -> void:
	if not visible:
		return
	var rows := %Rows as Control
	var free := cabin.get_free_seats() > 0 if cabin else true
	for row: Node in rows.get_children():
		(row as BoardingRow).can_board = free
	(%FullLabel as Control).visible = not free and rows.get_child_count() > 0


func _show_waiting() -> void:
	var rows := %Rows as Control
	for row: Node in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	visible = planet != null
	if not planet:
		return
	(%TitleLabel as Label).text = "Waiting at %s" % _planet_name()
	var line: Array[Passenger] = waiting.get_waiting(planet) if waiting else []
	for passenger: Passenger in line:
		var row := ROW.instantiate() as BoardingRow
		row.portrait_studio = portrait_studio
		row.passenger = passenger
		row.board_pressed.connect(board_pressed.emit)
		rows.add_child(row)
	(%EmptyLabel as Control).visible = line.is_empty()


func _planet_name() -> String:
	return planet.display_name if planet.display_name else String(planet.name)


func _on_waiting_changed(changed_planet: Planet) -> void:
	if changed_planet == planet:
		_show_waiting()
