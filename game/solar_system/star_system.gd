class_name StarSystem
extends Node3D
## A star at this node's origin and the planets that orbit it: one of the star systems on
## the [StarMap]. Its planets are its [Planet] descendants, moons included. It lights each
## one from its star every frame, so a system lights its own planets wherever it sits on
## the map and however the tutorial's zoom scales it. It says how far its heat zone
## reaches and how it looks, and the sky's colours while the bus works in it.

## Pulses a second at rest and at its most unsettled, and how much the star grows on each,
## as a share of its size: kept under the 0.1 the bus stops short of touching it.
const CALM_PULSE_RATE := 0.25
const UNREST_PULSE_RATE := 1.0
const CALM_PULSE := 0.015
const UNREST_PULSE := 0.035

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
## What the mechanic says with the call that opens this system's research stage, in place of
## their usual words. Empty for the usual ones.
@export_multiline var mechanic_call := ""
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
## How far from the star the heat zone and the hot zone reach at rest, and the star's
## radius, for the [BusTemperature]. A heat zone of 0 has none, but the star still stops
## the bus. An unstable star's swell widens the first two for a while ([method
## get_zone_radius]).
@export_range(0.0, 50.0, 0.1) var zone_radius := 6.3
@export_range(0.0, 50.0, 0.1) var hot_zone_radius := 4.5
@export_range(0.0, 50.0, 0.1) var star_radius := 2.4
## The heat zone's glow, where the hot zone starts, and its smoke. Their alpha is how
## strongly each shows.
@export var zone_color := Color(0.98, 0.72, 0.38, 0.07)
@export var hot_color := Color(1.0, 0.42, 0.28, 0.12)
@export var smoke_color := Color(1.0, 0.6, 0.3, 0.07)

@export_group("Swell")
## An unstable star's heat zone swells out to this radius and back, over and over, and its
## hot zone to the next. No wider than [member zone_radius] holds it steady.
@export_range(0.0, 50.0, 0.1) var swell_zone_radius := 0.0
@export_range(0.0, 50.0, 0.1) var swell_hot_zone_radius := 0.0
## Seconds the zone rests, swells, holds at its widest and shrinks back, in a cycle that
## holds at rest from the bus's arrival until [method start_swell].
@export_range(0.0, 600.0, 0.5) var swell_rest_seconds := 40.0
@export_range(0.1, 600.0, 0.5) var swell_grow_seconds := 20.0
@export_range(0.0, 600.0, 0.5) var swell_hold_seconds := 15.0
@export_range(0.1, 600.0, 0.5) var swell_shrink_seconds := 15.0
## How many times as fast the zone heats the bus at its widest, flying and standing still,
## easing up from 1 at rest: flying, so its far reaches still matter; standing still, so
## waiting a swell out costs more than flying out ahead of it.
@export_range(1.0, 10.0, 0.05) var swell_heating := 2.0
@export_range(1.0, 10.0, 0.05) var swell_standing_heating := 1.0
## Seconds before a swell that the star's pulse starts to quicken.
@export_range(0.0, 60.0, 0.5) var swell_warning_seconds := 6.0
## The star's body and halo, which pulse slowly while it swells and faster as it is about
## to, through the swell. They are what is left of the system on the [StarChart].
@export var star: Node3D

@export_group("Sky")
## The [SpaceSky]'s colours while the bus works here.
@export var background_color := Color(0.11, 0.1, 0.24)
@export var fog_color := Color(0.13, 0.12, 0.3)
@export var fog_accent_color := Color(0.17, 0.1, 0.26)
@export var sky_star_color := Color(0.9, 0.88, 1.0)

var _planets: Array[Planet] = []
# Seconds into the swell's cycle.
var _swell_time := 0.0
# Whether the cycle runs, or holds at rest until start_swell().
var _swelling := false
# How far round the star's pulse is, in radians.
var _pulse_phase := 0.0


func _ready() -> void:
	_get_planets()
	if swells():
		DebugPanel.add_button("Swell %s's star" % display_name, _debug_swell, self)


func _process(delta: float) -> void:
	for planet: Planet in _get_planets():
		planet.light_source = global_position
	if not swells():
		return
	if _swelling:
		_swell_time = fmod(_swell_time + delta, _get_cycle_seconds())
	_pulse_star(delta)


## Whether its star is unstable, its heat zone swelling and shrinking.
func swells() -> bool:
	return zone_radius > 0.0 and swell_zone_radius > zone_radius


## Holds the swell at rest, the star pulsing calmly, until [method start_swell]: as the bus
## arrives.
func hold_swell() -> void:
	_swell_time = 0.0
	_swelling = false


## Starts the held swell's cycle where the star's pulse starts to quicken, so the zone swells
## [member swell_warning_seconds] later. Nothing changes while it runs already.
func start_swell() -> void:
	if swells() and not _swelling:
		_swelling = true
		_swell_time = maxf(swell_rest_seconds - swell_warning_seconds, 0.0)


## Moves the swell's cycle on by [param seconds], as if they had passed, starting it if held.
func skip_swell(seconds: float) -> void:
	if swells():
		_swelling = true
		_swell_time = fposmod(_swell_time + seconds, _get_cycle_seconds())


## How far the heat zone reaches now, swollen or not.
func get_zone_radius() -> float:
	return lerpf(zone_radius, maxf(swell_zone_radius, zone_radius), get_swell())


## How far the hot zone reaches now, swollen or not.
func get_hot_zone_radius() -> float:
	return lerpf(hot_zone_radius, maxf(swell_hot_zone_radius, hot_zone_radius), get_swell())


## How many times as fast the heat zone heats the bus now, [param flying] or standing still:
## 1 at rest, [member swell_heating] or [member swell_standing_heating] at its widest.
func get_swell_heating(flying: bool) -> float:
	return lerpf(1.0, swell_heating if flying else swell_standing_heating, get_swell())


## How swollen the heat zone is now, from 0 at rest to 1 at its widest, easing in and out.
func get_swell() -> float:
	if not swells():
		return 0.0
	var t := _swell_time - swell_rest_seconds
	if t < 0.0:
		return 0.0
	if t < swell_grow_seconds:
		return smoothstep(0.0, 1.0, t / swell_grow_seconds)
	t -= swell_grow_seconds
	if t < swell_hold_seconds:
		return 1.0
	t -= swell_hold_seconds
	return 1.0 - smoothstep(0.0, 1.0, t / swell_shrink_seconds)


# How unsettled the star is, from 0 to 1: rising over the warning before a swell, unsettled
# through it, and settling again as the zone shrinks.
func _get_unrest() -> float:
	var warning_from := swell_rest_seconds - swell_warning_seconds
	if _swell_time < swell_rest_seconds:
		if swell_warning_seconds <= 0.0:
			return 0.0
		return clampf((_swell_time - warning_from) / swell_warning_seconds, 0.0, 1.0)
	if _swell_time < swell_rest_seconds + swell_grow_seconds + swell_hold_seconds:
		return 1.0
	return get_swell()


# The debug panel's button: on to the warning before the next swell.
func _debug_swell() -> void:
	skip_swell(swell_rest_seconds - swell_warning_seconds - _swell_time)


func _get_cycle_seconds() -> float:
	return swell_rest_seconds + swell_grow_seconds + swell_hold_seconds + swell_shrink_seconds


# Swells the star a touch and back, slowly at rest and faster as it grows unsettled. Under
# Reduce motion it doesn't pulse, but holds as swollen as its unrest.
func _pulse_star(delta: float) -> void:
	if not star:
		return
	var unrest := _get_unrest()
	var size := lerpf(CALM_PULSE, UNREST_PULSE, unrest)
	if Settings.reduce_motion:
		star.scale = Vector3.ONE * (1.0 + size * unrest)
		return
	_pulse_phase = fmod(
		_pulse_phase + TAU * lerpf(CALM_PULSE_RATE, UNREST_PULSE_RATE, unrest) * delta, TAU
	)
	star.scale = Vector3.ONE * (1.0 + size * (0.5 - 0.5 * cos(_pulse_phase)))


## Every planet and moon in it.
func get_planets() -> Array[Planet]:
	return _get_planets().duplicate()


## Whether [param planet] is in it.
func has_planet(planet: Planet) -> bool:
	return planet in _get_planets()


## What orbits its star: every child but [member star], such as its planets, an asteroid
## field or a warp gate.
func get_contents() -> Array[Node3D]:
	var contents: Array[Node3D] = []
	for child: Node in get_children():
		if child is Node3D and child != star:
			contents.append(child as Node3D)
	return contents


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
