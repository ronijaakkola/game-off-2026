class_name HeatZone
extends Node
## The heat zone round the star. Every frame it drives the bus's temperature
## ([BusTemperature]) by how far the bus is from the star on the orbit plane and whether it
## flies or stands still, and overheating clears the bus's route so it coasts to a
## stop. The temperature holds while the map is zoomed for the tutorial, which scales the
## distance to the star, and during a tow, whose route isn't the player's.
## It keeps the bus out of the star: while the line it heads along would touch the star, its
## speed is capped so it brakes to a stop [constant STAR_CLEARANCE] short of touching it,
## where it soon overheats. A line that clears the star isn't slowed, however near it passes.
## Not during a tow, which can't overheat, so a stop there would hold it for good.
## It sizes [member zone], the disc drawn round the star, to the zone, with the hot zone's
## edge on it. While the bus is inside, the disc pulses brighter, more in the hot zone,
## easing in and out; under Reduce motion it brightens without pulsing, and its smoke holds
## still.

## Pulses a second while the bus is inside.
const PULSE_RATE := 0.6
## How bright the pulse gets in the heat zone and in the hot zone, from 0 to 1.
const ZONE_FLASH := 0.5
const HOT_FLASH := 1.0
## How fast the pulse's strength eases in and out, per second.
const FLASH_EASE := 1.0
## How far from touching the star the bus stops, at its nearest.
const STAR_CLEARANCE := 0.1

@export var bus: FrameshiftBus
@export var star: Node3D
## Holds the temperature until the zoom out is over.
@export var map_zoom: MapZoom
## The disc on the orbit plane, 2 units across, whose material draws the zone.
@export var zone: MeshInstance3D

var _time := 0.0
# How strong the pulse is now, easing toward what where the bus is calls for.
var _flash := 0.0


func _ready() -> void:
	var temperature := bus.temperature
	temperature.overheated.connect(bus.cancel_course)
	zone.scale = Vector3.ONE * temperature.zone_radius
	var share := temperature.hot_zone_radius / temperature.zone_radius
	(zone.material_override as ShaderMaterial).set_shader_parameter(&"hot_share", share)


func _process(delta: float) -> void:
	var offset := bus.global_position - star.global_position
	offset.y = 0.0
	var flying := bus.state == FrameshiftBus.State.FLYING
	var exempt := map_zoom.is_zoomed() or bus.is_towing()
	var temperature := bus.temperature
	var distance := offset.length()
	var forward := bus.global_basis.z
	forward.y = 0.0
	# How much of the bus's heading points at the star: 1 straight at it, below 0 away.
	var closing := forward.normalized().dot(-offset.normalized())
	var to_star := _distance_to_star(distance, closing)
	temperature.advance(delta, distance, flying, to_star < INF, exempt)
	bus.speed_cap = INF if exempt else sqrt(2.0 * bus.acceleration * maxf(to_star, 0.0))
	var target := 0.0
	if not exempt and distance < temperature.zone_radius:
		target = HOT_FLASH if distance < temperature.hot_zone_radius else ZONE_FLASH
	_pulse(delta, target)


# How far the bus can fly along its heading, distance from the star, before it is
# STAR_CLEARANCE short of touching it: INF when that line clears the star.
func _distance_to_star(distance: float, closing: float) -> float:
	var touch := bus.temperature.star_radius + FrameshiftBus.RADIUS
	# How near the star's centre the line along its heading passes.
	var nearest := distance * sqrt(maxf(1.0 - closing * closing, 0.0))
	if closing <= 0.0 or nearest >= touch:
		return INF
	return distance * closing - sqrt(touch * touch - nearest * nearest) - STAR_CLEARANCE


# Eases the pulse's strength toward target and shows it on the disc.
func _pulse(delta: float, target: float) -> void:
	_flash = move_toward(_flash, target, FLASH_EASE * delta)
	_time = _time + delta if _flash > 0.0 else 0.0
	var pulse := 0.5
	if not Settings.reduce_motion:
		pulse = 0.5 - 0.5 * cos(TAU * PULSE_RATE * _time)
	var material := zone.material_override as ShaderMaterial
	material.set_shader_parameter(&"flash", _flash * pulse)
	material.set_shader_parameter(&"drift", 0.0 if Settings.reduce_motion else 1.0)
