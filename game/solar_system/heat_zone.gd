class_name HeatZone
extends Node
## The heat zone round the star of the system the bus works in, or the nearest one once
## they are joined, as that [StarSystem] sizes and colours it. Every frame it drives the
## bus's temperature ([BusTemperature]) by how far the bus is from the star on the orbit
## plane and whether it flies or stands still. The temperature holds while the map is
## zoomed for the tutorial, which scales the distance to the star, and during a tow, whose
## route isn't the player's.
## It keeps the bus out of the star: while the line it heads along would touch the star, its
## speed is capped so it brakes to a stop [constant STAR_CLEARANCE] short of touching it,
## where it soon overheats. A line that clears the star isn't slowed, however near it passes.
## Not during a tow, which can't overheat, so a stop there would hold it for good.
## It puts [member zone], the disc drawn round the star, on that star and sizes it to the
## zone, with the hot zone's edge on it; a system with no heat zone shows none. While the
## bus is inside, the disc pulses brighter, more in the hot zone, easing in and out; under
## Reduce motion it brightens without pulsing, and its smoke holds still. The disc is the
## world's, not the star's, so the map zoom leaves its size alone.
## While the map is zoomed for the tutorial it doesn't show, and it fades in over
## [constant FADE_SECONDS] once the zoom out is over and the rest of the run starts.

## Pulses a second while the bus is inside.
const PULSE_RATE := 0.6
## How bright the pulse gets in the heat zone and in the hot zone, from 0 to 1.
const ZONE_FLASH := 0.5
const HOT_FLASH := 1.0
## How fast the pulse's strength eases in and out, per second.
const FLASH_EASE := 1.0
## How far from touching the star the bus stops, at its nearest.
const STAR_CLEARANCE := 0.1
## Seconds the disc takes to fade in after the zoom out.
const FADE_SECONDS := 0.8

@export var bus: FrameshiftBus
## Says which system's star the bus is near.
@export var star_map: StarMap
## Holds the temperature until the zoom out is over.
@export var map_zoom: MapZoom
## The disc on the orbit plane, 2 units across, whose material draws the zone.
@export var zone: MeshInstance3D

var _time := 0.0
# The system whose star heats the bus now.
var _system: StarSystem
# How strong the pulse is now, easing toward what where the bus is calls for.
var _flash := 0.0
var _fade: Tween


func _ready() -> void:
	_follow(star_map.get_nearest_system(bus.global_position))
	if map_zoom.is_zoomed():
		zone.visible = false
		map_zoom.zoomed_out.connect(_fade_in)


## Shows the glow at [param value] of its strength, from 0 (hidden) to 1, for fading it.
func set_opacity(value: float) -> void:
	(zone.material_override as ShaderMaterial).set_shader_parameter(&"opacity", value)


func _fade_in() -> void:
	# Placed while the world was scaled for the tutorial, the disc came out off the star.
	zone.global_position = _system.global_position
	var material := zone.material_override as ShaderMaterial
	material.set_shader_parameter(&"opacity", 0.0)
	zone.visible = true
	if _fade:
		_fade.kill()
	_fade = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_fade.tween_method(
		func(value: float) -> void: material.set_shader_parameter(&"opacity", value),
		0.0,
		1.0,
		FADE_SECONDS
	)


func _process(delta: float) -> void:
	_follow(star_map.get_nearest_system(bus.global_position))
	var offset := bus.global_position - _system.global_position
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
	var heating := bus.get_stats().get_stat(BusStats.Type.HEATING).get_value()
	temperature.advance(delta, distance, flying, to_star < INF, exempt, heating)
	bus.speed_cap = INF if exempt else sqrt(2.0 * bus.acceleration * maxf(to_star, 0.0))
	var target := 0.0
	if not exempt and distance < temperature.zone_radius:
		target = HOT_FLASH if distance < temperature.hot_zone_radius else ZONE_FLASH
	_pulse(delta, target)


# Makes [param system]'s star the one that heats the bus: the temperature takes its
# radii, and the disc moves to it and takes its size and colours.
func _follow(system: StarSystem) -> void:
	if system == _system:
		return
	_system = system
	var temperature := bus.temperature
	temperature.zone_radius = system.zone_radius
	temperature.hot_zone_radius = system.hot_zone_radius
	temperature.star_radius = system.star_radius
	zone.global_position = system.global_position
	zone.visible = system.zone_radius > 0.0 and not map_zoom.is_zoomed()
	if system.zone_radius <= 0.0:
		return
	zone.scale = Vector3.ONE * system.zone_radius
	var material := zone.material_override as ShaderMaterial
	material.set_shader_parameter(&"hot_share", system.hot_zone_radius / system.zone_radius)
	material.set_shader_parameter(&"zone_color", system.zone_color)
	material.set_shader_parameter(&"hot_color", system.hot_color)
	material.set_shader_parameter(&"smoke_color", system.smoke_color)


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
	ShaderValues.show(material, &"flash", _flash * pulse)
	ShaderValues.show(material, &"drift", 0.0 if Settings.reduce_motion else 1.0)
