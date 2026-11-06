class_name FrameshiftBus
extends Node3D
## The Frameshift Bus. Docked, it floats beside its planet and moves with it. A course from
## a planet first charges the frameshift drive for [member charge_time], then the bus turns
## toward its first stop and flies the route stop by stop. It docks at a planet that ends
## the route, and holds still at a point in space that ends it. A new course in flight or
## in space starts at once, with no charge.
## It moves on the orbit plane, in global space, and faces its +Z.

enum State { DOCKED, CHARGING, FLYING, HOLDING }

# How close the bus gets to a planet, and to a point in space, to arrive.
const DOCK_DISTANCE := 0.2
const STOP_DISTANCE := 0.05
# How fast a docked bus catches up with its moving planet.
const DOCK_SMOOTHING := 6.0
# How far the model leans per radian per second of turn.
const BANK := 0.12

## Where the bus starts docked. None starts it holding where it stands.
@export var start_planet: Planet
## Seconds the frameshift drive charges before the bus leaves a planet.
@export_range(0.0, 10.0, 0.1) var charge_time := 3.0
@export_range(0.1, 20.0, 0.1) var max_speed := 4.0
## Speed gained or lost per second.
@export_range(0.1, 20.0, 0.1) var acceleration := 3.0
## Radians per second.
@export_range(0.1, 20.0, 0.1) var turn_speed := 3.0
## From a planet's surface to the bus's centre, docked.
@export_range(0.0, 5.0, 0.01) var dock_gap := 0.6
## How close the bus passes a stop before it heads for the next one.
@export_range(0.05, 5.0, 0.01) var waypoint_radius := 0.5

@export_group("Float")
## How far the bus bobs up and down while still.
@export_range(0.0, 1.0, 0.01) var bob_height := 0.08
@export_range(0.1, 20.0, 0.1) var bob_period := 2.6
## How far the bus sways side to side while still.
@export_range(0.0, 1.0, 0.01) var sway := 0.04
@export_range(0.1, 20.0, 0.1) var sway_period := 4.3
## How far the bus shakes when the drive is fully charged. Reduce motion turns it off.
@export_range(0.0, 0.5, 0.005) var charge_shake := 0.025

var state := State.HOLDING

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
	# Draws the route line's material once while SceneFlow's fade covers the screen, so it
	# compiles now and not on the first click.
	%RouteLine.draw_route(PackedVector3Array([global_position, global_position + Vector3.LEFT]))
	await get_tree().process_frame
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
			state = State.CHARGING
			_charge_left = charge_time
		State.HOLDING:
			state = State.FLYING


## Clears the route. A charging drive stops and the bus stays docked; in flight it slows to
## a stop where it is.
func cancel_course() -> void:
	_route.clear()
	if state == State.CHARGING:
		state = State.DOCKED


## The planet the bus is docked at, or null.
func get_docked_planet() -> Planet:
	return _dock_planet


func _process(delta: float) -> void:
	_time += delta
	match state:
		State.DOCKED:
			_follow_dock(delta)
		State.CHARGING:
			_follow_dock(delta)
			_charge_left -= delta
			if _charge_left <= 0.0:
				_undock()
		State.FLYING:
			_fly(delta)
		State.HOLDING:
			_turn_rate = 0.0
	_animate_model(delta)
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
		if last:
			_arrive(stop)
		return
	var previous := rotation.y
	rotation.y = rotate_toward(rotation.y, atan2(to_target.x, to_target.z), turn_speed * delta)
	_turn_rate = angle_difference(previous, rotation.y) / delta
	# Slow to a crawl while facing away, so the bus turns toward a stop behind it rather
	# than circling it.
	var facing := maxf(_forward().dot(to_target / distance), 0.0)
	var limit := max_speed
	if last:
		# Brakes so it comes to rest on the last stop.
		limit = minf(limit, sqrt(2.0 * acceleration * distance))
	_speed = move_toward(_speed, limit * facing * facing, acceleration * delta)
	global_position += _forward() * minf(_speed * delta, distance)


func _reached(stop: RouteStop, distance: float, last: bool) -> bool:
	if not last:
		return distance < waypoint_radius
	if stop.planet:
		return distance < DOCK_DISTANCE
	return distance < STOP_DISTANCE


func _arrive(stop: RouteStop) -> void:
	_speed = 0.0
	_turn_rate = 0.0
	if stop.planet:
		_dock(stop.planet, global_position - stop.planet.get_body_global_position())
	else:
		state = State.HOLDING


func _dock(planet: Planet, direction: Vector3) -> void:
	_dock_planet = planet
	var flat := _flat(direction)
	_dock_direction = flat.normalized() if flat.length_squared() > 1e-6 else Vector3.BACK
	state = State.DOCKED


func _undock() -> void:
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


# The float while still, the shake while charging, and a lean into turns in flight. All of
# it moves the model, so the bus itself stays on its route.
func _animate_model(delta: float) -> void:
	var still := state != State.FLYING
	_float = move_toward(_float, 1.0 if still else 0.0, delta)
	var model := %Model as Node3D
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


func _draw_route() -> void:
	var points := PackedVector3Array([_flat(global_position)])
	var from := global_position
	for stop: RouteStop in _route:
		from = _stop_position(stop, from)
		points.append(from)
	%RouteLine.draw_route(points)


func _forward() -> Vector3:
	return _flat(global_basis.z).normalized()


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
