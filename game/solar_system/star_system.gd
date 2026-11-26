class_name StarSystem
extends Node3D
## A star at this node's origin and the planets that orbit it: one of the star systems on
## the [StarMap]. Its planets are its [Planet] descendants, moons included. It lights each
## one from its star every frame, so a system lights its own planets wherever it sits on
## the map and however the tutorial's zoom scales it. It says how far its heat zone
## reaches and how it looks, and the sky's colours while the bus works in it.

## Its name as the player reads it, in notices and on the Jump button.
@export var display_name := ""
## The music while the bus works here, which [SystemMusic] plays.
@export var music: AudioStream
## Where the bus docks when it jumps in, and where the first passengers wait.
@export var home: Planet
## Where the bus comes to rest in space when it jumps in, from the star, on the orbit
## plane. At the star itself, the default, it docks at [member home] instead.
@export var jump_arrival := Vector3.ZERO
## How far the camera's look-at point may go from the star while the bus works here, on
## the orbit plane.
@export_range(1.0, 200.0, 0.1, "or_greater") var bounds_radius := 18.0
## How far out the camera may zoom while the bus works here, so the whole system fits.
@export_range(1.0, 400.0, 0.1, "or_greater") var max_distance := 55.0
## What The Boss says as the bus arrives here after a jump, with only the bus bars showing.
@export_multiline var arrival_call := ""
## What The Boss says with the promotion out of here, answered, in place of their usual
## words. Empty for the usual ones.
@export_multiline var promotion_call := ""
## The share of the passengers who turn up here that are Business, whatever the rating.
## Below 0, the band the recent rating is in sets it.
@export_range(-1.0, 1.0, 0.05) var business_share := -1.0
## How many times the fare per unit flown every fare here is, so the systems further on,
## whose upgrades cost more, pay for them.
@export_range(0.1, 10.0, 0.05) var fare_multiplier := 1.0

@export_group("Goals")
## The goals a promotion takes here: deliver this many passengers, this many of them
## Business (0 for no such goal), and keep this recent rating.
@export_range(1, 1000, 1) var deliveries := 30
@export_range(0, 1000, 1) var business_deliveries := 0
@export_range(0.0, 5.0, 0.05) var rating := 3.5

@export_group("Heat zone")
## How far from the star the heat zone and the hot zone reach, and the star's radius, for
## the [BusTemperature]. A heat zone of 0 has none, but the star still stops the bus.
@export_range(0.0, 50.0, 0.1) var zone_radius := 6.3
@export_range(0.0, 50.0, 0.1) var hot_zone_radius := 4.5
@export_range(0.0, 50.0, 0.1) var star_radius := 2.4
## The heat zone's glow, where the hot zone starts, and its smoke. Their alpha is how
## strongly each shows.
@export var zone_color := Color(0.98, 0.72, 0.38, 0.07)
@export var hot_color := Color(1.0, 0.42, 0.28, 0.12)
@export var smoke_color := Color(1.0, 0.6, 0.3, 0.07)

@export_group("Sky")
## The [SpaceSky]'s colours while the bus works here.
@export var background_color := Color(0.11, 0.1, 0.24)
@export var fog_color := Color(0.13, 0.12, 0.3)
@export var fog_accent_color := Color(0.17, 0.1, 0.26)
@export var sky_star_color := Color(0.9, 0.88, 1.0)

var _planets: Array[Planet] = []


func _ready() -> void:
	_get_planets()


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
			(child as Planet).star_system = self
			_planets.append(child as Planet)
		_collect(child)
