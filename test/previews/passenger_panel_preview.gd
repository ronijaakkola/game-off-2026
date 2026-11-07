extends Node
## A full cabin for capturing the passenger cards: eight passengers on the Commuter type,
## one in each mood and some in between, three of them asking for something. The cabin
## stands still, so every frame shows the same state.

const COMMUTER := preload("res://game/passengers/types/commuter.tres")
const DESTINATIONS: Array[String] = ["Ember", "Terra", "Moon", "Giant", "Frost"]
# Each destination's icon colour, as in the solar system. Giant has rings.
const ICON_COLORS: Array[Color] = [
	Color(0.82, 0.58, 0.4),
	Color(0.5, 0.82, 0.34),
	Color(0.95, 0.93, 1.0),
	Color(1.0, 0.6, 0.25),
	Color(1.0, 0.62, 0.74),
]
const RINGED := 3
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
		var planet := seat % DESTINATIONS.size()
		destination.display_name = DESTINATIONS[planet]
		destination.icon_color = ICON_COLORS[planet]
		if planet == RINGED:
			destination.ring_material = ShaderMaterial.new()
			destination.icon_ring_color = Color(0.72, 0.72, 1.0)
			destination.tilt = 18.0
		add_child(destination)
		var passenger := Passenger.new(COMMUTER, destination, 60.0, 40.0, rng)
		passenger.patience = passenger.patience_max * PATIENCE[seat]
		if seat in ASKING:
			passenger.request = COMMUTER.needs[seat % COMMUTER.needs.size()]
			passenger.activity = passenger.request.request_line
		cabin.board(passenger)
	(%PassengerPanel as PassengerPanel).cabin = cabin
