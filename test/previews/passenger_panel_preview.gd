extends Node
## A full cabin for capturing the passenger cards: eight passengers, Commuters but for two
## Business passengers, so their badge shows, one in each mood and some in between, three
## of them asking for something, their happiness heading every which way. The cabin stands
## still, so every frame shows the same state. `-- Kick` puts the pointer over the second
## card, so its options slide out.
## `-- Scare` gives everyone a kick's scare a few frames in, so the bars drop and leave
## their red trail.

const COMMUTER := preload("res://game/passengers/types/commuter.tres")
const BUSINESS := preload("res://game/passengers/types/business.tres")
# The seats whose passenger is Business.
const BUSINESS_SEATS: Array[int] = [1, 5]
const DESTINATIONS: Array[String] = ["Ember", "Terra", "Moon", "Giant", "Frost"]
# Each destination's icon colour, copied by hand from game/solar_system/solar_system.tscn,
# so update both when a planet's colour changes. Giant has rings, also as copied.
const ICON_COLORS: Array[Color] = [
	Color(0.82, 0.58, 0.4),
	Color(0.5, 0.82, 0.34),
	Color(0.95, 0.93, 1.0),
	Color(1.0, 0.6, 0.25),
	Color(1.0, 0.62, 0.74),
]
const RINGED := 3
# Happiness, as a fraction of the most, one per seat.
const HAPPINESS: Array[float] = [0.9, 0.5, 0.2, 0.0, 0.75, 0.62, 0.35, 0.1]
# Where each seat's happiness is heading (Passenger.trend), so the bars show every count of
# chevrons both ways, inside the fill and, on the short ones, past its end.
const TRENDS: Array[float] = [5.0, -30.0, 10.0, 10.0, -30.0, 0.0, -3.0, -12.0]
# The seats whose passenger has a request open.
const ASKING: Array[int] = [1, 4, 6]


func _ready() -> void:
	var cabin := %Cabin as Cabin
	cabin.seats = HAPPINESS.size()
	cabin.set_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for seat: int in HAPPINESS.size():
		var destination := Planet.new()
		var planet := seat % DESTINATIONS.size()
		destination.display_name = DESTINATIONS[planet]
		destination.icon_color = ICON_COLORS[planet]
		if planet == RINGED:
			destination.ring_material = ShaderMaterial.new()
			destination.icon_ring_color = Color(0.72, 0.72, 1.0)
			destination.tilt = 18.0
		add_child(destination)
		var type := BUSINESS if seat in BUSINESS_SEATS else COMMUTER
		var passenger := Passenger.new(type, destination, 60.0, 40.0, rng)
		passenger.happiness = Passenger.MAX_HAPPINESS * HAPPINESS[seat]
		passenger.trend = TRENDS[seat]
		if seat in ASKING:
			passenger.request = COMMUTER.needs[seat % COMMUTER.needs.size()]
			passenger.activity = passenger.request.request_line
		cabin.board(passenger)
	# PROTOTYPE: `-- Serve:TIMING` shows that serve minigame on the asking cards.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("Serve:"):
			ServeMinigamePrototype.mode = ServeMinigamePrototype.Mode[arg.trim_prefix("Serve:")]
	var panel := %PassengerPanel as PassengerPanel
	panel.portrait_studio = %PortraitStudio as PortraitStudio
	panel.cabin = cabin
	if "Scare" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await get_tree().process_frame
		cabin.shock(Cabin.KICK_SHOCK)
	if "Kick" in OS.get_cmdline_user_args():
		# The cards lay out a frame in.
		await get_tree().process_frame
		await get_tree().process_frame
		var card := panel.find_children("*", "PassengerCard", true, false)[1] as PassengerCard
		var motion := InputEventMouseMotion.new()
		motion.position = card.get_global_rect().get_center()
		motion.global_position = motion.position
		get_viewport().push_input(motion)
