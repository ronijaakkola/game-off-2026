class_name FrameshiftBus
extends Node3D
## The Frameshift Bus. Docked, it floats beside its planet and moves with it. Leaving a
## planet first charges the frameshift drive for [member charge_time], turning the bus
## toward its next stop while it charges, then it flies there. It passes through points in
## space and docks at every planet on its route, charging again before it leaves each one,
## and holds still at a point in space that ends the route. A new course in flight or in
## space starts at once, with no charge.
## It moves on the orbit plane, in global space, and faces its +Z.

## The bus docked at [param planet] after flying there: the end of its route, or a
## planet stop on it. Not emitted for [member start_planet]. Emitted before the drive
## charges for the next stop, so a listener can set [member boarding] first.
signal docked(planet: Planet)

enum State { DOCKED, CHARGING, FLYING, HOLDING }

# How close the bus gets to a planet, and to a point in space, to arrive.
const DOCK_DISTANCE := 0.2
const STOP_DISTANCE := 0.05
# How fast a docked bus catches up with its moving planet.
const DOCK_SMOOTHING := 6.0
# How far the model leans per radian per second of turn.
const BANK := 0.12
# How fast the thrusters' glow fades, per second.
const THRUST_FADE := 2.0
# Where the thrusters leave their trail, from the bus: at the nozzles, behind it.
const TRAIL_START := Vector3(0.0, -0.035, -0.45)

## Where the bus starts docked. None starts it holding where it stands.
@export var start_planet: Planet
## Plays each time the bus docks after flying to a planet.
@export var dock_sound: AudioStream
## Seconds the frameshift drive charges before the bus leaves a planet.
@export_range(0.0, 10.0, 0.1) var charge_time := 3.0
## Top speed. Planets orbit at under 0.5, so the bus can catch one.
@export_range(0.1, 20.0, 0.05) var max_speed := 1.2
## Speed gained or lost per second.
@export_range(0.1, 20.0, 0.05) var acceleration := 1.6
## Radians per second.
@export_range(0.1, 20.0, 0.1) var turn_speed := 2.0
## From a planet's surface to the bus's centre, docked.
@export_range(0.0, 5.0, 0.01) var dock_gap := 0.6
## How close the bus passes a stop before it heads for the next one.
@export_range(0.05, 5.0, 0.01) var waypoint_radius := 0.3

@export_group("Float")
## How far the bus bobs up and down while still.
@export_range(0.0, 1.0, 0.01) var bob_height := 0.02
@export_range(0.1, 20.0, 0.1) var bob_period := 2.6
## How far the bus sways side to side while still.
@export_range(0.0, 1.0, 0.01) var sway := 0.01
@export_range(0.1, 20.0, 0.1) var sway_period := 4.3
## How far the bus shakes when the drive is fully charged. Reduce motion turns it off.
@export_range(0.0, 0.5, 0.005) var charge_shake := 0.012

var state := State.HOLDING
## Whether passengers are getting off or on. While they are, a docked bus doesn't charge:
## a course set meanwhile charges once they are done. The scene that runs the passengers
## sets it.
var boarding := false:
	set(value):
		boarding = value
		if not boarding and state == State.DOCKED and not _route.is_empty():
			_start_charge()
## The stop on the route under the pointer. A point in space draws its diamond white. The
## scene that handles the pointer sets it.
var hovered_stop: RouteStop

var _route: Array[RouteStop] = []
var _dock_planet: Planet
# From the docked planet's centre toward the bus, on the orbit plane.
var _dock_direction := Vector3.BACK
var _speed := 0.0
var _turn_rate := 0.0
var _charge_left := 0.0
var _time := 0.0
# How much of the float shows: 1 while still, 0 in flight.
var _float := 1.0


func _ready() -> void:
	rotation.y = PI * 0.5
	if start_planet:
		_dock(start_planet, Vector3.BACK)
		global_position = _dock_point()
	# Draws the route line and charge ring once while SceneFlow's fade covers the screen,
	# so their materials compile now and not on the first click.
	%RouteLine.draw_route(
		PackedVector3Array([global_position, global_position + Vector3.LEFT]),
		PackedVector3Array([global_position + Vector3.LEFT]),
		0
	)
	%ChargeRing.show_progress(global_position, 1.0)
	await get_tree().process_frame
	%ChargeRing.show_progress(global_position, 0.0)
	_draw_route()


## Sets the route to [param stop], or adds it to the end with [param append]. From a planet
## the drive charges first; anywhere else the bus heads off at once.
func plot_course(stop: RouteStop, append := false) -> void:
	if append:
		_route.append(stop)
	else:
		_route = [stop]
	if _route.size() == 1 and stop.planet and stop.planet == _dock_planet:
		cancel_course()
		return
	match state:
		State.DOCKED:
			_start_charge()
		State.HOLDING:
			state = State.FLYING


## Clears the route. A charging drive stops and the bus stays docked; in flight it slows to
## a stop where it is.
func cancel_course() -> void:
	_route.clear()
	if state == State.CHARGING:
		state = State.DOCKED
		%ChargeRing.show_progress(global_position, 0.0)


## Removes the last stop on the route. With none left it is the same as
## [method cancel_course].
func remove_last_stop() -> void:
	_route.pop_back()
	if _route.is_empty():
		cancel_course()


## The last stop on the route, or null when there is no route.
func get_last_stop() -> RouteStop:
	return _route.back() if not _route.is_empty() else null


## Every stop on the route still ahead, in order.
func get_route_stops() -> Array[RouteStop]:
	return _route.duplicate()


## The size of the diamond drawn at a point in space on the route, in world units.
func get_marker_size() -> float:
	return (%RouteLine as RouteLine).marker_size


## The planet the bus is docked at, or null.
func get_docked_planet() -> Planet:
	return _dock_planet


## Whether the bus waits at a planet: docked, or charging to leave it.
func is_at_planet() -> bool:
	return state == State.DOCKED or state == State.CHARGING


## Every planet on the route still ahead.
func get_route_planets() -> Array[Planet]:
	var planets: Array[Planet] = []
	for stop: RouteStop in _route:
		if stop.planet:
			planets.append(stop.planet)
	return planets


## The first planet on the route still ahead, or null when the route has none.
func get_next_planet() -> Planet:
	for stop: RouteStop in _route:
		if stop.planet:
			return stop.planet
	return null


## How far the frameshift drive has charged, from 0 to 1. 0 when it isn't charging.
func get_charge_progress() -> float:
	if state != State.CHARGING or charge_time <= 0.0:
		return 0.0
	return clampf(1.0 - _charge_left / charge_time, 0.0, 1.0)


## Whether the bus is braking into its next stop, a planet: the end of a flight to it.
func is_docking() -> bool:
	if state != State.FLYING or _route.is_empty() or not _route[0].planet:
		return false
	var distance := _flat(_stop_position(_route[0], global_position) - global_position).length()
	return distance <= _speed * _speed / (2.0 * acceleration) + DOCK_DISTANCE


## Whether the bus is slowing to a stop in space after its course was cancelled.
func is_stopping() -> bool:
	return state == State.FLYING and _route.is_empty()


## Seconds until the bus docks at [method get_next_planet], from where everything is now:
## the charge left, then the route's straight legs at top speed, with the speeding up and
## braking. Planets move and the bus turns, so it is an estimate. -1 with no planet ahead.
func estimate_time_to_next_planet() -> float:
	if not get_next_planet():
		return -1.0
	var from := _flat(global_position)
	var distance := 0.0
	for stop: RouteStop in _route:
		var to := _stop_position(stop, from)
		distance += from.distance_to(to)
		from = to
		if stop.planet:
			break
	var start_speed := _speed if state == State.FLYING else 0.0
	var time := _travel_time(distance, start_speed)
	if state == State.CHARGING:
		time += _charge_left
	return time


func _process(delta: float) -> void:
	_time += delta
	match state:
		State.DOCKED:
			_follow_dock(delta)
		State.CHARGING:
			_follow_dock(delta)
			_face_next_stop(delta)
			_charge_left -= delta
			if _charge_left <= 0.0:
				_undock()
			else:
				%ChargeRing.show_progress(global_position, 1.0 - _charge_left / charge_time)
		State.FLYING:
			_fly(delta)
		State.HOLDING:
			_turn_rate = 0.0
	_animate_model(delta)
	var burn := (%Model as BusModel).thrust if state == State.FLYING else 0.0
	(%ThrusterTrail as ThrusterTrail).advance(global_transform * TRAIL_START, burn, delta)
	_draw_route()


func _fly(delta: float) -> void:
	if _route.is_empty():
		_speed = move_toward(_speed, 0.0, acceleration * delta)
		global_position += _forward() * _speed * delta
		_turn_rate = 0.0
		if _speed == 0.0:
			state = State.HOLDING
		return
	var stop := _route[0]
	var last := _route.size() == 1
	var target := _stop_position(stop, global_position)
	var to_target := _flat(target - global_position)
	var distance := to_target.length()
	if _reached(stop, distance, last):
		_route.pop_front()
		if stop.planet or last:
			_arrive(stop)
		return
	_turn_toward(to_target, delta)
	# Slow to a crawl while facing away, so the bus turns toward a stop behind it rather
	# than circling it.
	var facing := maxf(_forward().dot(to_target / distance), 0.0)
	var limit := max_speed
	if last or stop.planet:
		# Brakes so it comes to rest where it stops: a planet, or the end of the route.
		limit = minf(limit, sqrt(2.0 * acceleration * distance))
	_speed = move_toward(_speed, limit * facing * facing, acceleration * delta)
	global_position += _forward() * minf(_speed * delta, distance)


# While charging, so the bus leaves the planet already facing where it goes.
func _face_next_stop(delta: float) -> void:
	if _route.is_empty():
		return
	var to_target := _flat(_stop_position(_route[0], global_position) - global_position)
	if to_target.length_squared() > 1e-6:
		_turn_toward(to_target, delta)


func _turn_toward(direction: Vector3, delta: float) -> void:
	var previous := rotation.y
	rotation.y = rotate_toward(rotation.y, atan2(direction.x, direction.z), turn_speed * delta)
	_turn_rate = angle_difference(previous, rotation.y) / delta


func _reached(stop: RouteStop, distance: float, last: bool) -> bool:
	if stop.planet:
		return distance < DOCK_DISTANCE
	if last:
		return distance < STOP_DISTANCE
	return distance < waypoint_radius


func _arrive(stop: RouteStop) -> void:
	_speed = 0.0
	_turn_rate = 0.0
	if not stop.planet:
		state = State.HOLDING
		return
	_dock(stop.planet, global_position - stop.planet.get_body_global_position())
	if dock_sound:
		Audio.play_sfx(dock_sound)
	# Before charging, so a listener can set boarding and hold the charge.
	docked.emit(stop.planet)
	if state == State.DOCKED and not _route.is_empty():
		_start_charge()


func _dock(planet: Planet, direction: Vector3) -> void:
	_dock_planet = planet
	var flat := _flat(direction)
	_dock_direction = flat.normalized() if flat.length_squared() > 1e-6 else Vector3.BACK
	state = State.DOCKED


# Charges, unless passengers are boarding: then the bus stays docked until they are done.
func _start_charge() -> void:
	if boarding:
		return
	state = State.CHARGING
	_charge_left = charge_time


func _undock() -> void:
	%ChargeRing.show_progress(global_position, 0.0)
	_dock_planet = null
	state = State.FLYING if not _route.is_empty() else State.HOLDING


func _follow_dock(delta: float) -> void:
	_turn_rate = 0.0
	if not _dock_planet:
		return
	var weight := 1.0 - exp(-DOCK_SMOOTHING * delta)
	global_position = global_position.lerp(_dock_point(), weight)


func _dock_point() -> Vector3:
	return _approach_point(_dock_planet, _dock_direction)


# Where the bus heads for a stop, coming from [param from]: a planet's near side, or the
# point itself.
func _stop_position(stop: RouteStop, from: Vector3) -> Vector3:
	if not stop.planet:
		return _flat(stop.point)
	var flat := _flat(from - stop.planet.get_body_global_position())
	var direction := flat.normalized() if flat.length_squared() > 1e-6 else Vector3.BACK
	return _approach_point(stop.planet, direction)


func _approach_point(planet: Planet, direction: Vector3) -> Vector3:
	var center := _flat(planet.get_body_global_position())
	return center + direction * (planet.get_body_radius() + dock_gap)


# The float while still, the shake while charging, a lean into turns in flight, and the
# thrusters' glow. All of it is on the model, so the bus itself stays on its route.
func _animate_model(delta: float) -> void:
	var still := state != State.FLYING
	_float = move_toward(_float, 1.0 if still else 0.0, delta)
	var model := %Model as BusModel
	var offset := Vector3(
		sin(TAU * _time / sway_period) * sway, sin(TAU * _time / bob_period) * bob_height, 0.0
	)
	model.position = offset * _float
	if state == State.CHARGING and not Settings.reduce_motion and charge_time > 0.0:
		var charged := 1.0 - _charge_left / charge_time
		var shake := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0)
		model.position += shake * charge_shake * charged
	var lean := clampf(-_turn_rate * BANK, -0.5, 0.5)
	model.rotation.z = lerp_angle(model.rotation.z, lean, 1.0 - exp(-8.0 * delta))
	# The thrusters light up as the drive charges, burn in flight and fade after.
	var thrust := 1.0 if state == State.FLYING else get_charge_progress()
	model.thrust = move_toward(model.thrust, thrust, delta * THRUST_FADE)


# The line through the route still ahead. It runs to a planet's surface rather than to
# where the bus docks, so the planet reads as part of the route, and leaves it from the
# side facing the next stop. Points in space get a marker.
func _draw_route() -> void:
	var legs := PackedVector3Array()
	var markers := PackedVector3Array()
	var hovered := -1
	var from := _flat(global_position)
	var from_planet: Planet
	for stop: RouteStop in _route:
		var end := _flat(stop.point)
		if stop.planet:
			end = _flat(stop.planet.get_body_global_position())
		var start := _surface_point(from_planet, end) if from_planet else from
		if stop.planet:
			legs.append_array([start, _surface_point(stop.planet, start)])
		else:
			legs.append_array([start, end])
			if stop == hovered_stop:
				hovered = markers.size()
			markers.append(end)
		from = end
		from_planet = stop.planet
	%RouteLine.draw_route(legs, markers, hovered)


# The point on planet's surface, on the orbit plane, that faces toward.
func _surface_point(planet: Planet, toward: Vector3) -> Vector3:
	var center := _flat(planet.get_body_global_position())
	var flat := _flat(toward - center)
	var direction := flat.normalized() if flat.length_squared() > 1e-6 else Vector3.BACK
	return center + direction * planet.get_body_radius()


# Seconds to cover [param distance] in a straight line from [param start_speed], speeding
# up toward top speed and braking to rest at the end.
func _travel_time(distance: float, start_speed: float) -> float:
	var speed_up := (max_speed * max_speed - start_speed * start_speed) / (2.0 * acceleration)
	var brake := max_speed * max_speed / (2.0 * acceleration)
	if speed_up + brake <= distance:
		var cruise := (distance - speed_up - brake) / max_speed
		return (max_speed - start_speed) / acceleration + cruise + max_speed / acceleration
	# Never reaches top speed: speeds up to a peak, then brakes.
	var peak := sqrt(maxf(acceleration * distance + start_speed * start_speed * 0.5, 0.0))
	if peak < start_speed:
		return start_speed / acceleration
	return (peak - start_speed) / acceleration + peak / acceleration


func _forward() -> Vector3:
	return _flat(global_basis.z).normalized()


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
