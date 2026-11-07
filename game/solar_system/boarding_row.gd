class_name BoardingRow
extends PanelContainer
## One passenger waiting at the planet the bus is docked at, as a row in the boarding
## popup: where they are going (an icon of the planet and its name), their fare, and a
## button that picks them up. It reads the passenger when [member passenger] is set; a
## passenger's details don't change while they wait.

## The player pressed the button to pick up [member passenger].
signal board_pressed(passenger: Passenger)

var passenger: Passenger:
	set(value):
		passenger = value
		if is_node_ready():
			_show()

## Whether the button can be pressed: false while every seat is taken.
var can_board := true:
	set(value):
		can_board = value
		if is_node_ready():
			(%BoardButton as Button).disabled = not can_board


func _ready() -> void:
	_show()
	(%BoardButton as Button).disabled = not can_board


func _show() -> void:
	if not passenger:
		return
	(%DestinationIcon as PlanetIcon).planet = passenger.destination
	(%DestinationLabel as Label).text = "To %s" % _destination_name()
	(%FareLabel as Label).text = "%d cr" % roundi(passenger.fare)


func _destination_name() -> String:
	if not passenger.destination:
		return "?"
	if passenger.destination.display_name:
		return passenger.destination.display_name
	return passenger.destination.name


func _on_board_button_pressed() -> void:
	board_pressed.emit(passenger)
