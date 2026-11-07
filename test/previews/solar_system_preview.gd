extends Node
## The solar system with Terra open and three passengers waiting there, for capturing the
## planet's panel and the camera framing the planet beside it.


func _ready() -> void:
	var system := %SolarSystem as SolarSystem
	var terra := system.find_child("Terra") as Planet
	var waiting := system.find_child("WaitingPassengers") as WaitingPassengers
	for i: int in waiting.max_per_planet:
		waiting.add(terra)
	system.open_planet(terra)
