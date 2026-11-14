extends Node
## The solar system with a planet open and passengers waiting there, for capturing the
## planet's panel and the camera framing the planet beside it. Terra, unless a planet's
## name follows `--`: `uv run tools/check.py capture <this scene> -- Giant`. `-- Bus` opens
## the bus instead, with +20 % top speed, -20 % fuel tank and +1 seat, so its rows show a
## bonus, a penalty and a seat, and the fuel forecast trait. `-- Forecast` opens nothing,
## and gives the bus the fuel forecast, waiting markers and station cameras traits, a
## course by Giant to Terra and lines of one, two and three, so the forecast shows over
## Terra, each leg's cost over it and the dots under the names; `hover` puts the pointer on
## Giant, so its line shows as photos, and `hover leave` takes it off again after 40 frames.
## `chime` leaves out the station cameras, so the hover shows how many wait in a tooltip.
## `-- Trip`
## opens nothing, puts two passengers in line at Ember, where the bus is docked, boards one
## going where the first one is, so their row shows "1 aboard", and pins the first one's
## row in the dock panel, so their trip arc shows. `-- Research` opens the research screen
## with a few upgrades of each tree researched, credits and points to spend on some of
## the rest, and the pointer over one the player can research so its card shows.
## `-- Research promoted` opens the second stage too, `plain` leaves out the tooltip,
## `lacking` hovers one the player can't afford instead, `hold`
## presses the upgrade down and keeps it held, so its fill sweeps up (`--frames 40` shows
## it part way), and
## `dock` gives Ember, where the bus is docked, a lab and opens nothing, so the dock panel
## shows its Research button; `rich` gives credits and points too, so its outline shows.
## `-- Tow` opens the bus, so the camera follows it, and sends it off with fuel for eight units, so
## it runs dry and the tow is offered (about 10 s in, `--frames 660`), then requests it 2 s later;
## the whole tow takes about 32 s (`--frames 1900`).
## `-- Quick` opens nothing and shows a quick text over the bus, a remark; `gain` or `loss`
## shows that kind instead. It holds from about frame 20 to 80.
## `-- Full` opens nothing, fills every seat and puts one in line at Ember, then clicks
## their Board button once the dock panel has slid in, so the bus full notice shows.

const COMMUTER := preload("res://game/passengers/types/commuter.tres")
const TIMER := preload("res://game/bus/icons/timer.svg")
const CHECK := preload("res://shared/icons/circle_check.svg")
const FUEL := preload("res://shared/icons/fuel.svg")


func _ready() -> void:
	var system := %SolarSystem as SolarSystem
	var name_given := OS.get_cmdline_user_args()
	var planet_name := name_given[0] if not name_given.is_empty() else "Terra"
	if planet_name == "Forecast":
		var forecast_bus := system.find_child("Bus") as FrameshiftBus
		forecast_bus.get_stats().get_traits().add(BusTraits.Type.FUEL_FORECAST)
		forecast_bus.get_stats().get_traits().add(BusTraits.Type.WAITING_MARKERS)
		if "chime" not in name_given:
			forecast_bus.get_stats().get_traits().add(BusTraits.Type.STATION_CAMERAS)
		var terra := system.find_child("Terra") as Planet
		var giant := system.find_child("Giant") as Planet
		var line := system.find_child("WaitingPassengers") as WaitingPassengers
		for planet: Planet in [terra, giant, giant, giant, forecast_bus.get_docked_planet()]:
			line.add(planet)
		forecast_bus.plot_course(RouteStop.at_planet(giant))
		forecast_bus.plot_course(RouteStop.at_planet(terra), true)
		if "hover" in name_given:
			# With `leave`, the pointer moves off after 40 frames, so the card closes.
			var frames := 0
			while not ("leave" in name_given and frames >= 40):
				await get_tree().process_frame
				_point_at(giant)
				frames += 1
			_point_at(null)
		return
	if planet_name == "Trip":
		var trip_bus := system.find_child("Bus") as FrameshiftBus
		var line := system.find_child("WaitingPassengers") as WaitingPassengers
		line.add(trip_bus.get_docked_planet())
		line.add(trip_bus.get_docked_planet())
		# The dock panel lists the line once it has shown the planet, a frame in.
		await get_tree().process_frame
		await get_tree().process_frame
		var first := line.get_waiting(trip_bus.get_docked_planet())[0]
		var cabin := system.find_child("Cabin") as Cabin
		cabin.board(Passenger.new(COMMUTER, first.destination, 60.0, 40.0))
		var dock := system.find_child("DockPanel") as DockPanel
		dock.pin(first)
		return
	if planet_name == "Tow":
		var tow_bus := system.find_child("Bus") as FrameshiftBus
		var tank := tow_bus.get_fuel_tank()
		tank.fuel = 8.0 * tank.burn_per_unit
		system.get_ledger().credits = 60
		tow_bus.plot_course(RouteStop.at_point(tow_bus.global_position + Vector3(16.0, 0.0, 8.0)))
		tow_bus.frameshift_held = true
		system.open_bus()
		await tow_bus.ran_out_of_fuel
		await get_tree().create_timer(2.0).timeout
		(system.find_child("Notices") as NoticeStack).get_notices()[0].action_pressed.emit()
		return
	if planet_name == "Kick":
		var cabin := system.find_child("Cabin") as Cabin
		var terra := system.find_child("Terra") as Planet
		for i: int in 3:
			cabin.board(Passenger.new(COMMUTER, terra, 60.0, 40.0))
		system.open_bus()
		await get_tree().create_timer(1.0).timeout
		cabin.kick(cabin.get_passengers()[1])
		return
	if planet_name in ["Research", "Quick", "Full"]:
		if planet_name == "Research":
			await _open_research(system, name_given)
		elif planet_name == "Quick":
			await _show_quick_text(system, name_given)
		else:
			await _board_on_a_full_bus(system)
		return
	if planet_name == "Bus":
		var bus := system.find_child("Bus") as FrameshiftBus
		var stats := bus.get_stats()
		stats.add_modifier(
			StatModifier.new(BusStats.Type.MAX_SPEED, StatModifier.Kind.PERCENT, 20.0)
		)
		stats.add_modifier(
			StatModifier.new(BusStats.Type.FUEL_CAPACITY, StatModifier.Kind.PERCENT, -20.0)
		)
		stats.add_modifier(StatModifier.new(BusStats.Type.SEATS, StatModifier.Kind.FLAT, 1.0))
		stats.get_traits().add(BusTraits.Type.FUEL_FORECAST)
		system.open_bus()
		return
	var planet := system.find_child(planet_name) as Planet
	assert(planet != null, "no planet named %s" % planet_name)
	var waiting := system.find_child("WaitingPassengers") as WaitingPassengers
	for i: int in waiting.max_per_planet:
		waiting.add(planet)
	system.open_planet(planet)


func _open_research(system: SolarSystem, args: PackedStringArray) -> void:
	var lab := system.find_child("ResearchLab") as ResearchLab
	if "dock" in args:
		(system.find_child("Ember") as Planet).has_lab = true
		if "rich" in args:
			system.get_ledger().credits = 500
			for value: int in Race.Type.values():
				system.get_ledger().earn_research(value as Race.Type, 20)
		return
	var research := lab.get_research()
	for tree: ResearchTree in lab.trees:
		for upgrade: Upgrade in tree.upgrades:
			if upgrade.tier == 0 and upgrade.column % 2 == 0:
				research.research(upgrade)
	if "promoted" in args:
		research.open_next_stage()
	var ledger := system.get_ledger()
	ledger.credits = 120
	ledger.earn_research(Race.Type.BLUE, 5)
	ledger.earn_research(Race.Type.ORANGE, 3)
	ledger.earn_research(Race.Type.GREEN, 11)
	(system.find_child("ResourceBar") as ResourceBar).commit()
	lab.open_screen()
	if "plain" in args:
		return
	# Hover an upgrade the player can research once the screen has grown to full size. The
	# timer runs while the game is paused under the screen.
	await get_tree().create_timer(ResearchScreen.OPEN_SECONDS + 0.05).timeout
	var screen := system.find_child("ResearchScreen") as ResearchScreen
	for node: Node in screen.find_children("*", "UpgradeButton", true, false):
		var button := node as UpgradeButton
		var wanted := Research.State.AVAILABLE
		if "lacking" in args:
			wanted = Research.State.UNAFFORDABLE
		if button.get_state() == wanted:
			if "hold" in args:
				_press(button)
			button.mouse_entered.emit()
			return


func _show_quick_text(system: SolarSystem, args: PackedStringArray) -> void:
	var quick := system.find_child("BusQuickText") as BusQuickText
	await get_tree().process_frame
	if "gain" in args:
		quick.show_text("Straight to the Moon!", CHECK, BusQuickText.Kind.GAIN)
	elif "loss" in args:
		quick.show_text("Rough stop!", FUEL, BusQuickText.Kind.LOSS)
	else:
		quick.show_text("Quick stop!", TIMER)


func _board_on_a_full_bus(system: SolarSystem) -> void:
	var bus := system.find_child("Bus") as FrameshiftBus
	var cabin := system.find_child("Cabin") as Cabin
	for i: int in cabin.get_free_seats():
		cabin.board(Passenger.new(COMMUTER, bus.get_docked_planet(), 60.0, 40.0))
	(system.find_child("WaitingPassengers") as WaitingPassengers).add(bus.get_docked_planet())
	# Once the dock panel has slid in.
	await get_tree().create_timer(0.6).timeout
	_press(system.find_child("BoardButton", true, false) as Control)


# Moves the pointer onto [param control] and presses the left button there, without letting go.
func _press(control: Control) -> void:
	var at := get_viewport().get_final_transform() * control.get_global_rect().get_center()
	# The window's own pointer too, or its next move takes the hover, and the hold, away.
	get_viewport().warp_mouse(control.get_global_rect().get_center())
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = at
	press.global_position = at
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()


# Moves the pointer onto [param planet] as the camera sees it, or with null to the top
# left corner, over nothing.
func _point_at(planet: Planet) -> void:
	var camera := get_viewport().get_camera_3d()
	var at := Vector2(4.0, 300.0)
	if planet:
		at = camera.unproject_position(planet.get_body_global_position())
	get_viewport().warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
