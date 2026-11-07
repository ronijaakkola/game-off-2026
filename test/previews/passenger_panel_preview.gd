extends Node
## A full cabin for capturing the passenger cards: eight passengers on the Commuter type,
## one in each mood and some in between, three of them asking for something. The cabin
## stands still, so every frame shows the same state.

const COMMUTER := preload("res://game/passengers/types/commuter.tres")
const DESTINATIONS: Array[String] = ["Ember", "Terra", "Moon", "Giant", "Frost"]
# Patience left, as a fraction of the full amount, one per seat.
const PATIENCE: Array[float] = [0.9, 0.5, 0.2, 0.0, 0.75, 0.62, 0.35, 0.1]
# The seats whose passenger has a request open.
const ASKING: Array[int] = [1, 4, 6]


func _ready() -> void:
	var cabin := %Cabin as Cabin
	cabin.seats = PATIENCE.size()
	cabin.set_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for seat: int in PATIENCE.size():
		var destination := Planet.new()
		destination.display_name = DESTINATIONS[seat % DESTINATIONS.size()]
		add_child(destination)
		var passenger := Passenger.new(COMMUTER, destination, 60.0, 40.0, rng)
		passenger.patience = passenger.patience_max * PATIENCE[seat]
		if seat in ASKING:
			passenger.request = COMMUTER.needs[seat % COMMUTER.needs.size()]
			passenger.activity = passenger.request.request_line
		cabin.board(passenger)
	(%PassengerPanel as PassengerPanel).cabin = cabin
