class_name OrbitClock
extends Node
## How fast the planets orbit. They orbit at full speed only while the bus frameshifts, and
## ease down to [member idle_orbit_speed] once it starts parking at a planet, comes to rest
## in space, or starts coasting to a stop because its course was cleared or its tank ran
## dry, and speed up again once it heads off: a trip takes far longer than it looks, and the
## time spent stopped is partly wound back. While the map is zoomed ([MapZoom]), each
## planet runs at the share of that speed the zoom gives it.

## How fast the planets' speed changes once the bus stops frameshifting, and once it heads
## off: the seconds it would take to go all the way between full speed and still. Linear
## in speed, so the planets ease out as they slow.
const STOP_SECONDS := 1.2
const START_SECONDS := 0.6

@export var bus: FrameshiftBus
## Holds planets still, or slows them, while the map is zoomed. None leaves every planet at
## the speed.
@export var map_zoom: MapZoom
## How fast the planets orbit while the bus isn't frameshifting, from 0 (still) to 1 (full
## speed).
@export_range(0.0, 1.0, 0.01) var idle_orbit_speed := 0.5

var _planets: Array[Planet] = []
# How fast the planets orbit, from 0 to 1: full speed while the bus frameshifts,
# idle_orbit_speed otherwise.
var _speed := 1.0


## Starts running [param planets]' orbits, at the speed the bus calls for now.
func start(planets: Array[Planet]) -> void:
	_planets = planets
	_speed = 1.0 if _is_frameshifting() else idle_orbit_speed
	run(0.0)


## Eases the speed [param delta] seconds toward what the bus calls for, and sets it on every
## planet. The solar system calls it every frame, before anything reads where they are.
func run(delta: float) -> void:
	var shifting := _is_frameshifting()
	var seconds := START_SECONDS if shifting else STOP_SECONDS
	var target := 1.0 if shifting else idle_orbit_speed
	_speed = move_toward(_speed, target, delta / seconds)
	for planet: Planet in _planets:
		var share := map_zoom.get_orbit_share(planet) if map_zoom else 1.0
		planet.orbit_speed = _speed * share


# Whether the bus flies a course, towed or not, rather than waiting, parking, charging or
# coasting to a stop.
func _is_frameshifting() -> bool:
	return bus.state == FrameshiftBus.State.FLYING and not bus.is_stopping()
