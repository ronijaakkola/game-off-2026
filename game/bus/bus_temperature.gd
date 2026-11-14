class_name BusTemperature
extends Node
## The bus's temperature, in degrees, driven by how far it is from the star. Outside the
## heat zone it falls back to [member rest_temperature]. Inside it, it rises while the bus
## flies, faster the nearer the star and much faster in the hot zone, rises very slowly
## while the bus waits at a planet there, and holds while it is stopped anywhere else. At
## [member overheat_temperature] it overheats: it emits [signal overheated] and cools back
## to rest over [member cooldown_time], wherever the bus stands. Then, until it leaves the
## heat zone, it rises only [member escape_share] as fast while the bus flies away from the
## star, so getting out is easy; heading back in heats it as usual. It starts at rest.
## Whoever knows where the star is calls [method advance].

## It reached [member overheat_temperature]. The cooldown has started.
signal overheated

## Where the heat zone ends, from the star's centre.
@export_range(0.0, 50.0, 0.1) var zone_radius := 6.3
## Where the hot zone, the inner part of the heat zone, ends, from the star's centre.
@export_range(0.0, 50.0, 0.1) var hot_zone_radius := 4.5
## The star's surface, from its centre, where the rise in the hot zone peaks.
@export_range(0.0, 50.0, 0.1) var star_radius := 2.4
## Degrees the bus starts at, and falls back to outside the heat zone.
@export var rest_temperature := 21.0
## Degrees at which it overheats.
@export var overheat_temperature := 60.0
## Degrees a second it falls outside the heat zone.
@export_range(0.0, 100.0, 0.01) var fall_rate := 3.9
## Degrees a second it rises in flight at the heat zone's edge, rising to [member hot_rate]
## at the hot zone's edge.
@export_range(0.0, 100.0, 0.01) var edge_rate := 0.78
## Degrees a second it rises in flight at the hot zone's edge, rising to [member surface_rate]
## at the star's surface.
@export_range(0.0, 100.0, 0.01) var hot_rate := 2.34
@export_range(0.0, 500.0, 0.1) var surface_rate := 46.8
## Degrees a second it rises while the bus waits at a planet in the heat zone.
@export_range(0.0, 10.0, 0.01) var docked_rate := 0.2
## Seconds the cooldown takes, from overheated back to rest.
@export_range(0.0, 60.0, 0.1) var cooldown_time := 8.0
## After a cooldown, until the bus leaves the heat zone, the share of the usual rise it
## gets while flying away from the star.
@export_range(0.0, 1.0, 0.01) var escape_share := 0.1

## The temperature now, in degrees.
var temperature := rest_temperature

var _cooldown_left := 0.0
# Whether it has cooled down and the bus hasn't left the heat zone since.
var _escaping := false


func _ready() -> void:
	temperature = rest_temperature


## Moves the temperature on by [param delta] seconds, the bus [param distance] from the
## star's centre and [param flying] ([param heading_out] when away from the star),
## [param docked] at a planet or stopped elsewhere. While [param exempt] it holds and can't
## overheat, but a cooldown under way goes on.
func advance(
	delta: float, distance: float, flying: bool, heading_out: bool, docked: bool, exempt := false
) -> void:
	if is_cooling():
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)
		_escaping = _cooldown_left == 0.0
		var cooled := 1.0 - _cooldown_left / cooldown_time if cooldown_time > 0.0 else 1.0
		temperature = lerpf(overheat_temperature, rest_temperature, cooled)
		return
	if exempt:
		return
	if distance >= zone_radius:
		_escaping = false
		temperature = maxf(temperature - fall_rate * delta, rest_temperature)
	elif flying:
		var share := escape_share if _escaping and heading_out else 1.0
		set_temperature(temperature + get_rise_rate(distance) * share * delta)
	elif docked:
		set_temperature(temperature + docked_rate * delta)


## Degrees a second the temperature rises in flight [param distance] from the star's
## centre: 0 outside the heat zone.
func get_rise_rate(distance: float) -> float:
	if distance >= zone_radius:
		return 0.0
	if distance >= hot_zone_radius:
		return lerpf(edge_rate, hot_rate, inverse_lerp(zone_radius, hot_zone_radius, distance))
	var into := clampf(inverse_lerp(hot_zone_radius, star_radius, distance), 0.0, 1.0)
	return lerpf(hot_rate, surface_rate, into)


## Sets the temperature to [param degrees], no lower than rest. Reaching
## [member overheat_temperature] overheats it. Does nothing while it cools down.
func set_temperature(degrees: float) -> void:
	if is_cooling():
		return
	temperature = maxf(degrees, rest_temperature)
	if temperature >= overheat_temperature:
		temperature = overheat_temperature
		_cooldown_left = cooldown_time
		overheated.emit()


## Whether it cooled down after overheating and the bus hasn't left the heat zone since:
## flying away from the star then heats it only [member escape_share] as fast.
func is_escaping() -> bool:
	return _escaping


## Whether it overheated and is cooling down. Meanwhile no course can be set and the drive
## can't charge.
func is_cooling() -> bool:
	return _cooldown_left > 0.0


## Seconds until the cooldown is over. 0 when it isn't cooling.
func get_cooldown_left() -> float:
	return _cooldown_left
