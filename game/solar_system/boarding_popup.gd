class_name BoardingPopup
extends PanelContainer
## A small popup beside the planet the bus is docked at, listing who waits there, longest
## waiting first, each with a button to pick them up. It is shown while [member planet] is
## set and someone waits there, and kept up to date as they arrive and board. The buttons
## are off while every seat is taken. It only asks; the parent picks the passenger up.

## The player pressed the button to pick up [param passenger].
signal board_pressed(passenger: Passenger)

const ROW := preload("res://game/solar_system/boarding_row.tscn")
## Pixels between the point [method place] is given and the popup's left edge.
const GAP := 12.0
## Pixels the popup keeps from the screen's edges.
const MARGIN := 8.0

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

## The planet the bus is docked at, or null while it isn't at one.
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
	var free := cabin.get_free_seats() > 0 if cabin else true
	for row: Node in %Rows.get_children():
		(row as BoardingRow).can_board = free
	(%FullLabel as Control).visible = not free


## Puts the popup just right of [param screen_point], centred on it vertically, kept inside
## [param bounds].
func place(screen_point: Vector2, bounds: Rect2) -> void:
	var at := Vector2(screen_point.x + GAP, screen_point.y - size.y * 0.5)
	var low := bounds.position + Vector2.ONE * MARGIN
	var high := bounds.end - size - Vector2.ONE * MARGIN
	position = at.clamp(low, high.max(low))


func _show_waiting() -> void:
	var rows := %Rows as Control
	for row: Node in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	var line: Array[Passenger] = []
	if waiting and planet:
		line = waiting.get_waiting(planet)
	for passenger: Passenger in line:
		var row := ROW.instantiate() as BoardingRow
		row.passenger = passenger
		row.board_pressed.connect(board_pressed.emit)
		rows.add_child(row)
	visible = not line.is_empty()
	# Shrinks back to fit the rows left.
	reset_size()


func _on_waiting_changed(changed_planet: Planet) -> void:
	if changed_planet == planet:
		_show_waiting()
