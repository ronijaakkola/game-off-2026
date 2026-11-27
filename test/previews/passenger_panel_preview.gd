extends Node
## A full cabin for capturing the passenger cards: eight passengers going to five planets,
## so three planets group two each and two planets one, Commuters but for two
## Business passengers, so their badge shows, one in each mood and some in between, three
## of them asking for something, their happiness heading every which way. The cabin stands
## still, so every frame shows the same state. `-- Kick` puts the pointer over the second
## card, so its options slide out.
## `-- Scare` gives everyone a kick's scare a few frames in, so the bars drop and leave
## their red trail.
## `-- Reroute` sends the first passenger to Frost instead of Ember a few frames in, as an
## express quest does, so their card moves to Frost's group.
## `-- Frustrated` takes [constant FRUSTRATION] off what each seat can reach, so the bars'
## striped ends show, and gives the idle ones a line about why. With `Tooltip` as well,
## the first striped end's tooltip opens, as the pointer on it does.
## `-- RerouteAlone` sends the only passenger going to Giant to Dust, where nobody goes yet,
## so Giant's group folds as Dust's opens.
## The bus is in flight unless `-- Docked`, which holds every bar still under its pause
## mark, has the station serve the open requests and the others idle on a docked line.
## `-- PointBar`, `-- PointMark` and `-- PointCap` rest the pointer on the third seat's
## bar: near its start, on the docked mark (with `Docked`) and on the striped end (with
## `Frustrated`), so whichever tooltip belongs there opens.
## `-- Returning` makes the first two seats returning passengers, a Commuter and a
## Business one, so their badge shows alone and after the briefcase.
## `-- Vip` makes the first seat a VIP on a tour of three stops, the first made, so their
## gold group sits on top with their stops under their card; with `VipLate` too, their
## tour's time is gone, and with `VipNext` they make their next stop a second in.
## `-- Breakdown` opens the panel the pointer on a happiness bar opens, for the third
## seat, on a bus with Movies, after a stop too many and a quest failed.
## `-- Castaway` makes the last seat the castaway on a hop quest, going nowhere and as happy
## as can be, so their group shows under the planets'.

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
# What frustration takes off each seat's reach with `-- Frustrated`, one per seat.
const FRUSTRATION: Array[float] = [10.0, 15.0, 30.0, 45.0, 0.0, 30.0, 15.0, 60.0]
# The seats whose passenger has a request open.
const ASKING: Array[int] = [1, 4, 6]


func _ready() -> void:
	var cabin := %Cabin as Cabin
	cabin.seats = HAPPINESS.size()
	cabin.set_process(false)
	var args := OS.get_cmdline_user_args()
	# Before anyone boards, so leaving the planet doesn't reset their happiness.
	cabin.docked = "Docked" in args
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var planets: Array[Planet] = []
	for i: int in DESTINATIONS.size():
		var planet := Planet.new()
		planet.display_name = DESTINATIONS[i]
		planet.icon_color = ICON_COLORS[i]
		if i == RINGED:
			planet.ring_material = ShaderMaterial.new()
			planet.icon_ring_color = Color(0.72, 0.72, 1.0)
			planet.tilt = 18.0
		add_child(planet)
		planets.append(planet)
	for seat: int in HAPPINESS.size():
		# Seats wrap round the planets, so the first three go to the same as another seat.
		var destination := planets[seat % planets.size()]
		var type := BUSINESS if seat in BUSINESS_SEATS else COMMUTER
		var passenger := Passenger.new(type, destination, 60.0, 40.0, rng)
		passenger.trend = 0.0 if cabin.docked else TRENDS[seat]
		passenger.returning = seat < 2 and "Returning" in args
		if seat in ASKING:
			passenger.request = COMMUTER.needs[seat % COMMUTER.needs.size()]
			passenger.activity = passenger.request.request_line
			if cabin.docked:
				passenger.activity = Cabin.STATION_LINE % passenger.request.item
				passenger.serving = 0.6
		elif cabin.docked:
			# Past finding their seat, so the idle ones show a docked line.
			passenger.tick(Passenger.BOARDING_SECONDS, true)
		if "Frustrated" in OS.get_cmdline_user_args():
			passenger.frustration = FRUSTRATION[seat]
			if not passenger.request and not type.stop_lines.is_empty():
				passenger.activity = type.stop_lines[seat % type.stop_lines.size()]
		if seat == 0 and "Vip" in args:
			passenger = Passenger.new(Vip.TYPE, planets[1], 60.0, 40.0, rng)
			passenger.tour = Tour.new([planets[3], planets[1], planets[4]], 1)
			passenger.tick(Passenger.BOARDING_SECONDS, cabin.docked)
			Vip.dress(passenger)
			if "VipLate" in args:
				passenger.ride.clock = 200.0
		if seat == HAPPINESS.size() - 1 and "Castaway" in args:
			Castaway.dress(passenger, false)
			passenger.destination = null
			passenger.quest_line = HopGoal.new(passenger, Vector3.ZERO).get_text()
		cabin.board(passenger)
		# After they take their seat, which puts them at what the bus can give.
		passenger.happiness = Passenger.MAX_HAPPINESS * HAPPINESS[seat]
		if not passenger.destination:
			passenger.happiness = passenger.get_target()
	var panel := %PassengerPanel as PassengerPanel
	panel.portrait_studio = %PortraitStudio as PortraitStudio
	panel.cabin = cabin
	panel.kicks_allowed = "Kick" in args
	if "VipNext" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.2).timeout
		for passenger: Passenger in cabin.get_passengers():
			if passenger.tour:
				passenger.tour.advance()
	if "Scare" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await get_tree().process_frame
		cabin.shock(Cabin.KICK_SHOCK)
	if "Reroute" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await get_tree().process_frame
		cabin.get_passengers()[0].reroute(planets[DESTINATIONS.find("Frost")], 60.0, 40.0)
	if "RerouteAlone" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await get_tree().process_frame
		var dust := Planet.new()
		dust.display_name = "Dust"
		add_child(dust)
		cabin.get_passengers()[3].reroute(dust, 60.0, 40.0)
	if "Tooltip" in OS.get_cmdline_user_args():
		# The striped ends take a moment to slide in.
		await get_tree().create_timer(0.6).timeout
		for tooltip: Tooltip in panel.find_children("*", "Tooltip", true, false):
			if tooltip.sentence == HappinessCap.TOOLTIP_TEXT:
				tooltip.open()
				break
	if "Breakdown" in args:
		cabin.comfort.perks = ["Movies"]
		var asked := cabin.get_passengers()[2]
		asked.ride.stops = asked.ride.tolerance + 1
		asked.cause.mark(HappinessCause.Type.QUEST_FAILED)
		await get_tree().process_frame
		await get_tree().process_frame
		for tooltip: Tooltip in panel.get_card(asked).find_children("*", "Tooltip", true, false):
			if tooltip.target is HappinessBreakdown:
				tooltip.open()
	for spot: String in ["PointBar", "PointMark", "PointCap"]:
		if spot in args:
			# The cards lay out a frame in, and the striped ends take a moment to slide in.
			await get_tree().create_timer(0.6).timeout
			var third := panel.get_card(cabin.get_passengers()[2])
			var bar := third.get_happiness_bar() as ProgressBar
			var at := bar.get_global_rect().position + Vector2(4.0, bar.size.y * 0.5)
			if spot == "PointMark":
				at.x += bar.size.x * bar.value - 4.0
			elif spot == "PointCap":
				at.x += bar.size.x - 8.0
			var move := InputEventMouseMotion.new()
			move.position = at
			move.global_position = at
			get_viewport().push_input(move)
	if "Kick" in OS.get_cmdline_user_args():
		# The cards lay out a frame in.
		await get_tree().process_frame
		await get_tree().process_frame
		var card := panel.find_children("*", "PassengerCard", true, false)[1] as PassengerCard
		var motion := InputEventMouseMotion.new()
		motion.position = card.get_global_rect().get_center()
		motion.global_position = motion.position
		get_viewport().push_input(motion)
