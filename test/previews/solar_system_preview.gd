extends Node
## The solar system with a planet open and passengers waiting there, for capturing the
## planet's panel and the camera framing the planet beside it. Terra, unless a planet's
## name follows `--`: `uv run tools/check.py capture <this scene> -- Giant`.


func _ready() -> void:
	var system := %SolarSystem as SolarSystem
	var name_given := OS.get_cmdline_user_args()
	var planet_name := name_given[0] if not name_given.is_empty() else "Terra"
	var planet := system.find_child(planet_name) as Planet
	assert(planet != null, "no planet named %s" % planet_name)
	var waiting := system.find_child("WaitingPassengers") as WaitingPassengers
	for i: int in waiting.max_per_planet:
		waiting.add(planet)
	system.open_planet(planet)
