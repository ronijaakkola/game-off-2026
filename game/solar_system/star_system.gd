class_name StarSystem
extends Node3D
## A star at this node's origin and the planets that orbit it: one of the star systems on
## the [StarMap]. Its planets are its [Planet] descendants, moons included. It lights each
## one from its star every frame, so a system lights its own planets wherever it sits on
## the map and however the tutorial's zoom scales it.

## Its name as the player reads it, in notices and on the Jump button.
@export var display_name := ""
## Where the bus docks when it jumps in.
@export var home: Planet
## How far the camera's look-at point may go from the star while the bus works here, on
## the orbit plane.
@export_range(1.0, 200.0, 0.1, "or_greater") var bounds_radius := 18.0

@export_group("Goals")
## The goals a promotion takes here: deliver this many passengers, and keep this recent
## rating.
@export_range(1, 1000, 1) var deliveries := 30
@export_range(0.0, 5.0, 0.05) var rating := 3.5

var _planets: Array[Planet] = []


func _process(_delta: float) -> void:
	for planet: Planet in _get_planets():
		planet.light_source = global_position


## Every planet and moon in it.
func get_planets() -> Array[Planet]:
	return _get_planets().duplicate()


## Whether [param planet] is in it.
func has_planet(planet: Planet) -> bool:
	return planet in _get_planets()


func _get_planets() -> Array[Planet]:
	if _planets.is_empty():
		_collect(self)
	return _planets


func _collect(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Planet:
			_planets.append(child as Planet)
		_collect(child)
