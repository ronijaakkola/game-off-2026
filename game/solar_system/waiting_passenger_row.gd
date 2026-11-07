class_name WaitingPassengerRow
extends PanelContainer
## One passenger waiting at a planet, as a row in its panel: their portrait (a
## [PassengerPhoto]), their name, where they are going (an icon of the planet and its name),
## and their fare. It reads the passenger when [member passenger] is set; a passenger's
## details don't change while they wait.

var passenger: Passenger:
	set(value):
		passenger = value
		if is_node_ready():
			_show()
## Where the portrait is rendered. Set it before [member passenger].
var portrait_studio: PortraitStudio


func _ready() -> void:
	_show()


func _show() -> void:
	if not passenger:
		return
	var photo := %PassengerPhoto as PassengerPhoto
	photo.studio = portrait_studio
	photo.passenger = passenger
	(%NameLabel as Label).text = passenger.name
	(%DestinationIcon as PlanetIcon).planet = passenger.destination
	(%DestinationLabel as Label).text = "To %s" % _destination_name()
	(%FareLabel as Label).text = "%d credits" % roundi(passenger.fare)


func _destination_name() -> String:
	if not passenger.destination:
		return "?"
	if passenger.destination.display_name:
		return passenger.destination.display_name
	return passenger.destination.name
