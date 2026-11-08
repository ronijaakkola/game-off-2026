extends Node
## The solar system with a planet open and passengers waiting there, for capturing the
## planet's panel and the camera framing the planet beside it. Terra, unless a planet's
## name follows `--`: `uv run tools/check.py capture <this scene> -- Giant`. `-- Bus` opens
## the bus instead, with +20 % top speed, -20 % fuel tank and +1 seat, so its rows show a
## bonus, a penalty and a seat, and the fuel forecast trait. `-- Forecast` opens nothing,
## and gives the bus the fuel forecast and waiting markers traits, a course to Terra and
## someone waiting there, so the forecast shows over it and the marker under it.


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
