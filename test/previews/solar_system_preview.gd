extends Node
## The solar system with a planet open and passengers waiting there, for capturing the
## planet's panel and the camera framing the planet beside it. Terra, unless a planet's
## name follows `--`: `uv run tools/check.py capture <this scene> -- Giant`. `-- Bus` opens
## the bus instead, with +20 % top speed, -20 % fuel tank and +1 seat, so its rows show a
## bonus, a penalty and a seat, and the fuel forecast trait. `-- Forecast` opens nothing,
## and gives the bus the fuel forecast and waiting markers traits, a course to Terra and
## someone waiting there, so the forecast shows over it and the marker under it. `-- Trip`
## opens nothing, puts two passengers in line at Ember, where the bus is docked, and pins
## the first one's row in the dock panel, so their trip arc shows. `-- Research` opens
## Ember, where the bus is docked, on its Research tab with Frost's blue tree, with credits
## and points to spend and the first upgrade researched, and the pointer over the second so
## its card shows. `-- Research green` and `-- Research orange` take Terra's and Giant's
## trees instead, and `away` after either opens the tree's own planet, away from the bus,
## so the tree is dimmed: `-- Research orange away`. `plain` leaves out the card,
## and `dock` opens nothing, so the dock panel shows its Research button. `-- Tow` opens
## the bus, so the camera follows it, and sends it off with fuel for eight units, so it runs
## dry and the tow is offered (about 10 s in, `--frames 660`), then requests it 2 s later;
## the whole tow takes about 32 s (`--frames 1900`).

const COMMUTER := preload("res://game/passengers/types/commuter.tres")


func _ready() -> void:
	var system := %SolarSystem as SolarSystem
	var name_given := OS.get_cmdline_user_args()
	var planet_name := name_given[0] if not name_given.is_empty() else "Terra"
	if planet_name == "Forecast":
		var forecast_bus := system.find_child("Bus") as FrameshiftBus
		forecast_bus.get_stats().get_traits().add(BusTraits.Type.FUEL_FORECAST)
		forecast_bus.get_stats().get_traits().add(BusTraits.Type.WAITING_MARKERS)
		var terra := system.find_child("Terra") as Planet
		(system.find_child("WaitingPassengers") as WaitingPassengers).add(terra)
		forecast_bus.plot_course(RouteStop.at_planet(terra))
		return
	if planet_name == "Trip":
		var trip_bus := system.find_child("Bus") as FrameshiftBus
		var line := system.find_child("WaitingPassengers") as WaitingPassengers
		line.add(trip_bus.get_docked_planet())
		line.add(trip_bus.get_docked_planet())
		# The dock panel lists the line once it has shown the planet, a frame in.
		await get_tree().process_frame
		await get_tree().process_frame
		var dock := system.find_child("DockPanel") as DockPanel
		dock.pin(line.get_waiting(trip_bus.get_docked_planet())[0])
		return
	if planet_name == "Tow":
		var tow_bus := system.find_child("Bus") as FrameshiftBus
		var tank := tow_bus.get_fuel_tank()
		tank.fuel = 8.0 * tank.burn_per_unit
		system.get_ledger().credits = 60
		tow_bus.plot_course(RouteStop.at_point(tow_bus.global_position + Vector3(16.0, 0.0, 8.0)))
		system.open_bus()
		await tow_bus.ran_out_of_fuel
		await get_tree().create_timer(2.0).timeout
		(system.find_child("TowOffer") as TowOffer).requested.emit()
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
	if planet_name in ["Research", "Showcase"]:
		if planet_name == "Research":
			await _open_research(system, name_given)
		else:
			await _showcase(system, "clean" in name_given)
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
	var home := system.find_child("Frost") as Planet
	if "green" in args:
		home = system.find_child("Terra") as Planet
	elif "orange" in args:
		home = system.find_child("Giant") as Planet
	var tree := home.research_tree
	var ember := system.find_child("Ember") as Planet
	ember.research_tree = tree
	var ledger := system.get_ledger()
	ledger.credits = 60
	ledger.earn_research(tree.upgrades[0].get_race(), 5)
	var lab := system.find_child("ResearchLab") as ResearchLab
	lab.research_at(tree.upgrades[0], ember)
	if "dock" in args:
		return
	system.open_planet(home if "away" in args else ember)
	var tabs := system.find_child("Tabs") as TabBar
	tabs.current_tab = PlanetPanel.RESEARCH_TAB
	if "plain" in args:
		return
	# The panel slides in with the camera; hover the second upgrade once it is in place.
	await get_tree().create_timer(1.0).timeout
	for node: Node in system.find_children("*", "UpgradeButton", true, false):
		var button := node as UpgradeButton
		if button.upgrade == tree.upgrades[1]:
			button.mouse_entered.emit()


# A busy mid-game moment for a screenshot: a full-ish cabin, people waiting at every planet,
# credits, research and a rating, a course plotted, and one waiting trip's arc pinned.
# `clean` hides the HUD.
func _showcase(system: SolarSystem, clean: bool) -> void:
	var bus := system.find_child("Bus") as FrameshiftBus
	bus.get_stats().get_traits().add(BusTraits.Type.WAITING_MARKERS)
	bus.get_stats().get_traits().add(BusTraits.Type.FUEL_FORECAST)
	var line := system.find_child("WaitingPassengers") as WaitingPassengers
	var cabin := system.find_child("Cabin") as Cabin
	var home := bus.get_docked_planet()
	for i: int in 3:
		var rider := line.create(home)
		rider.happiness = [92.0, 64.0, 38.0][i]
		cabin.board(rider)
	for name: String in ["Ember", "Terra", "Giant", "Frost"]:
		var planet := system.find_child(name) as Planet
		for i: int in line.max_per_planet:
			line.add(planet)
	var ledger := system.get_ledger()
	ledger.credits = 1240
	ledger.earn_research(Race.Type.BLUE, 7)
	ledger.earn_research(Race.Type.ORANGE, 4)
	ledger.earn_research(Race.Type.GREEN, 11)
	for stars: float in [5.0, 4.0, 5.0, 4.5, 3.5]:
		ledger.rate(stars)
	(system.find_child("RatingCounter") as RatingCounter).commit()
	# Long enough for the riders to settle in and start doing something.
	await get_tree().create_timer(3.5).timeout
	bus.plot_course(RouteStop.at_planet(system.find_child("Giant") as Planet))
	if clean:
		(system.find_child("Hud") as CanvasLayer).visible = false
		return
	# Pin a trip that stays clear of the panels on the right, where Frost can sit.
	var shown := line.get_waiting(home)[0]
	shown.destination = system.find_child("Terra") as Planet
	(system.find_child("DockPanel") as DockPanel).pin(shown)
