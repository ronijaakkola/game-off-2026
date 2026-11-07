class_name WaitingPassengerRow
extends PanelContainer
## One passenger waiting at a planet, as a row in its panel: their name, type and fare on
## top, and under them where they are going (an icon of the planet and its name). It reads
## the passenger when [member passenger] is set; a passenger's details don't change while
## they wait.

var passenger: Passenger:
	set(value):
		passenger = value
		if is_node_ready():
			_show()


func _ready() -> void:
	_show()


func _show() -> void:
	if not passenger:
		return
	(%NameLabel as Label).text = passenger.name
	(%TypeLabel as Label).text = passenger.type.display_name
	(%DestinationIcon as PlanetIcon).planet = passenger.destination
	(%DestinationLabel as Label).text = "To %s" % _destination_name()
	(%FareLabel as Label).text = "%d credits" % roundi(passenger.fare)


func _destination_name() -> String:
	if not passenger.destination:
		return "?"
	if passenger.destination.display_name:
		return passenger.destination.display_name
	return passenger.destination.name
