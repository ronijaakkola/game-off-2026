class_name FrameshiftBus
extends Node3D
## The Frameshift Bus. Docked, it floats beside its planet and moves with it. A course
## doesn't move it from a planet: the player charges the [FrameshiftDrive] by holding the
## Frameshift key for [member charge_time], the bus turning toward its next stop meanwhile,
## then it flies there. It passes through points in space and docks at every planet on its
## route, and holds still at a point in space that ends the route. Docking, unless towed,
## the drive is warm: once the passengers getting off are off it cools over
## [member cool_time]. A charge started warm starts from the warmth left and builds
## [member warm_boost] times as fast; let go, the drive goes cold. A new course in flight starts
## at once, with no charge, as does one in space up to [member warm_time] after stopping.
## Flying to a planet, it slows down as it nears it, then parks: it glides the last stretch
## and swings side-on, with its door toward the planet. It has docked once it is parked.
## Flying burns fuel from its [FuelTank] by distance. Run dry, it coasts to a stop unless
## [method tow_to] tows it, slowly and with no say over its route, to a planet.
## It moves on the orbit plane, in global space, and faces its +Z.

## The bus docked at [param planet] after flying there and parking: the end of its route,
## or a planet stop on it. Not emitted for [member start_planet].
signal docked(planet: Planet)
## The tank ran dry in flight or in space. The route is cleared, so it coasts to a stop.
signal ran_out_of_fuel
## A tow from [method tow_to] docked at [param planet] and the tank is full again. Emitted
## before [signal docked].
signal towed(planet: Planet)
## The bus left a planet on a charge started warm and never let go: a quick stop.
signal left_warm

enum State { DOCKED, CHARGING, FLYING, HOLDING, PARKING }

# How close the bus flies to where it docks at a planet before it glides the rest of the
# way, and how close it gets to a point in space to arrive.
const DOCK_DISTANCE := 0.5
const STOP_DISTANCE := 0.05
# How fast a docked bus glides into place beside its planet: the share of the way left it
# covers per second. The flight brakes to the glide's speed, so the two join smoothly.
const DOCK_SMOOTHING := 2.0
# How fast a docked bus eases out of its swing side-on, per second.
const DOCK_TURN_EASE := 4.0
# How close to its dock point, and to side-on, a parking bus gets to count as parked.
const PARK_DISTANCE := 0.03
const PARK_ANGLE := 0.05
# Where the thrusters leave their trail, from the bus: at the nozzles, behind it.
const TRAIL_START := Vector3(0.0, -0.035, -0.45)
## About half the bus's length: how big it is when the camera frames it and when a click
## picks it.
const RADIUS := 0.45
## Where the door is, from the bus: on its -X side, which faces the planet when docked,
## at the front of the cabin, just behind the nose.
const DOOR := Vector3(-0.19, 0.03, 0.095)

## Where the bus starts docked. None starts it holding where it stands.
@export var start_planet: Planet
## Plays each time the bus docks after flying to a planet.
@export var dock_sound: AudioStream
## Seconds of holding the Frameshift key before the bus leaves a planet, or space once cold.
@export_range(0.0, 10.0, 0.1) var charge_time := 3.0:
	set(value):
		charge_time = value
		_drive.charge_time = value
## Seconds the drive stays warm after the bus stops in space: a course set later waits for a charge.
@export_range(0.0, 30.0, 0.1) var warm_time := 1.0
## Seconds the drive stays warm at a planet, once the passengers getting off are off.
@export_range(0.0, 30.0, 0.1) var cool_time := 6.0:
	set(value):
		cool_time = value
		_drive.cool_time = value
## How many times as fast a charge started warm builds.
@export_range(1.0, 5.0, 0.05) var warm_boost := 1.25:
	set(value):
		warm_boost = value
		_drive.warm_boost = value
## Top speed before upgrades: the base of the MAX_SPEED stat ([method get_stats]). Planets
## orbit at under 0.5, so the bus can catch one.
@export_range(0.1, 20.0, 0.05) var max_speed := 1.2:
	set(value):
		max_speed = value
		_stats.get_stat(BusStats.Type.MAX_SPEED).base = value
## Speed gained or lost per second.
@export_range(0.1, 20.0, 0.05) var acceleration := 1.6
## Radians per second.
@export_range(0.1, 20.0, 0.1) var turn_speed := 2.0
## Towed, how much faster than its planet the bus goes, up to its top speed.
@export_range(0.05, 20.0, 0.05) var tow_speed := 0.4
## From a planet's surface to the bus's centre, docked.
@export_range(0.0, 5.0, 0.01) var dock_gap := 0.35
## From a planet's surface to the bus's centre while the drive charges: the bus pulls out
## from its dock so it has room to turn without its tail going through the planet.
@export_range(0.0, 5.0, 0.01) var charge_gap := 0.6
## How close the bus passes a stop before it heads for the next one.
@export_range(0.05, 5.0, 0.01) var pass_radius := 0.3

var state := State.HOLDING
## Which side of [member start_planet] the bus starts docked on: from the planet's centre
## toward the bus, on the orbit plane. Set it before the bus is ready.
var start_direction := Vector3.BACK
## Whether passengers are getting off or on. While they are, a docked bus doesn't start a
## charge, and a charge under way holds where it is. The scene that runs the passengers
## sets it.
var boarding := false
## Whether passengers are getting off. Meanwhile a warm drive doesn't cool. The scene that
## runs the passengers sets it.
var unloading := false
## Whether the player holds the Frameshift key. Docked or holding in space with a course,
## the drive charges while it is held and drains once let go. Leaving lets go, as does
## clearing the course.
var frameshift_held: bool:
	get:
		return _drive.held
	set(value):
		_drive.held = value

var _route: Array[RouteStop] = []
var _drive := FrameshiftDrive.new()
var _stats := BusStats.new()
var _towing := false
var _glide := DockGlide.new()
var _speed := 0.0
var _turn_rate := 0.0
var _holding_time := 0.0
var _felt := FeltPush.new()


# Sets the stats' bases from the exports' defaults. A value the scene sets comes later,
# through the export's setter.
func _init() -> void:
	_stats.get_stat(BusStats.Type.MAX_SPEED).base = max_speed
	_drive.charge_time = charge_time
	_drive.cool_time = cool_time
	_drive.warm_boost = warm_boost


func _ready() -> void:
	(%FuelTank as FuelTank).emptied.connect(_on_fuel_emptied)
	(%FuelTank as FuelTank).follow(_stats.get_stat(BusStats.Type.FUEL_CAPACITY))
	rotation.y = PI * 0.5
	if start_planet:
		global_position = RouteStop.approach_point(start_planet, start_direction, dock_gap)
		_dock(start_planet, start_direction)
		rotation.y = _glide.get_heading()
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


## Sets the route to [param stop], or with [param add] adds it to the end
## ([method RouteEditing.add]). In flight, or in space with the drive warm, the bus
## heads off at once; anywhere else it waits for the drive. Does nothing while towed or
## with an empty tank.
func plot_course(stop: RouteStop, add := false) -> void:
	if _towing or (%FuelTank as FuelTank).is_empty():
		return
	if not add:
		_route.clear()
	RouteEditing.add(_route, stop)
	if _route.size() == 1 and stop.planet and stop.planet == _glide.planet:
		cancel_course()
		return
	if state == State.HOLDING and _holding_time <= warm_time:
		state = State.FLYING


## Clears the route and lets go of the Frameshift key. A charging drive stops and the bus
## stays docked, or holds in space; in flight it slows to a stop where it is. Does nothing
## while towed.
func cancel_course() -> void:
	if _towing:
		return
	_route.clear()
	_drive.held = false
	if state == State.CHARGING:
		_stop_charge()


## Removes [param stop] from the route, wherever it is, with what
## [method RouteEditing.remove] takes along. With none left it is the same as
## [method cancel_course]. Does nothing while towed.
func remove_stop(stop: RouteStop) -> void:
	if _towing:
		return
	RouteEditing.remove(_route, stop, _glide.planet if is_at_planet() else null)
	if _route.is_empty():
		cancel_course()


## Tows the bus to [param planet], [member tow_speed] faster than the planet moves, where it
## docks with a full tank.
## The player can't change the route meanwhile.
func tow_to(planet: Planet) -> void:
	_towing = true
	_route = [RouteStop.at_planet(planet)]
	if state == State.HOLDING:
		state = State.FLYING


func is_towing() -> bool:
	return _towing


## The bus's stats and traits, where upgrades add their modifiers and unlock features.
func get_stats() -> BusStats:
	return _stats


## The bus's model, whose border shows while the pointer is over the bus.
func get_model() -> BusModel:
	return %Model as BusModel


## The bus's fuel tank.
func get_fuel_tank() -> FuelTank:
	return %FuelTank as FuelTank


## The last stop on the route, or null when there is no route.
func get_last_stop() -> RouteStop:
	return _route.back() if not _route.is_empty() else null


## Every stop on the route still ahead, in order.
func get_route_stops() -> Array[RouteStop]:
	return _route.duplicate()


## The planet the bus is docked at, or null.
func get_docked_planet() -> Planet:
	return _glide.planet


## Whether the bus waits at a planet: docked, or charging to leave it.
func is_at_planet() -> bool:
	return state == State.DOCKED or (state == State.CHARGING and _glide.planet != null)


## Every planet on the route still ahead.
func get_route_planets() -> Array[Planet]:
	var planets: Array[Planet] = []
	for stop: RouteStop in _route:
		if stop.planet:
			planets.append(stop.planet)
	return planets


## The first planet on the route still ahead, or null when the route has none. While the
## bus parks, the planet it parks at.
func get_next_planet() -> Planet:
	if state == State.PARKING:
		return _glide.planet
	var first := _route.find_custom(RouteStop.is_planet)
	return _route[first].planet if first >= 0 else null


## How far the frameshift drive has charged, from 0 to 1. 0 when it isn't charging.
func get_charge_progress() -> float:
	return _drive.get_progress() if state == State.CHARGING else 0.0


## How warm the drive is at a planet, from 1 just docked to 0 cold. While a charge started
## warm builds, before it is let go, how far it has charged.
func get_warmth() -> float:
	if state == State.CHARGING and _drive.is_warm_charge():
		return _drive.get_progress()
	return _drive.get_warmth() if state == State.DOCKED else 0.0


## Whether the bus is braking into its next stop, a planet, or parking there: the end of a
## flight to it.
func is_docking() -> bool:
	if state == State.PARKING:
		return true
	if state != State.FLYING or _route.is_empty() or not _route[0].planet:
		return false
	var distance := _flat(_stop_position(_route[0], global_position) - global_position).length()
	var glide := _glide_speed()
	return distance <= (_speed * _speed - glide * glide) / (2.0 * acceleration) + DOCK_DISTANCE


## Whether the bus is slowing to a stop in space after its course was cancelled.
func is_stopping() -> bool:
	return state == State.FLYING and _route.is_empty()


## The push someone on board feels as the bus speeds up, brakes and turns, in units per
## second squared: +x toward the bus's right, +y forward. Braking pushes forward, turning
## left pushes right, and parking eases off a forward push as the bus glides to a stop.
## Following a planet while docked pushes nothing.
func get_felt_acceleration() -> Vector2:
	return _felt.get_value()


## Seconds until the bus docks at [method get_next_planet], from where everything is now:
## the charge left (all of it while it waits for one), then the route's straight legs at
## top speed, with the speeding up and braking, then parking. Planets move and the bus
## turns, so it is an estimate. -1 with no planet ahead.
func estimate_time_to_next_planet() -> float:
	if not get_next_planet():
		return -1.0
	if state == State.PARKING:
		return DockGlide.park_seconds(_flat(_dock_point() - global_position).length())
	var from := _flat(global_position)
	var distance := 0.0
	for stop: RouteStop in _route:
		var to := _stop_position(stop, from)
		distance += from.distance_to(to)
		from = to
		if stop.planet:
			break
	var start_speed := _speed if state == State.FLYING else 0.0
	# It docks where the glide starts.
	var time := FlightTime.straight(
		maxf(distance - DOCK_DISTANCE, 0.0), start_speed, _glide_speed(), _top_speed(), acceleration
	)
	time += DockGlide.park_seconds(minf(distance, DOCK_DISTANCE))
	if state in [State.DOCKED, State.CHARGING, State.HOLDING]:
		time += _drive.get_time_left()
	return time


func _process(delta: float) -> void:
	match state:
		State.DOCKED:
			_follow_dock(delta)
			_face_dock_side(delta)
			if not unloading:
				_drive.cool(delta)
			_start_charge()
			if state == State.DOCKED:
				%ChargeRing.show_progress(global_position, get_warmth())
		State.CHARGING:
			_follow_dock(delta)
			_face_next_stop(delta)
			_drive.advance(delta, boarding)
			if _drive.is_charged() and not boarding:
				var quick := _drive.is_warm_charge()
				_undock()
				if quick:
					left_warm.emit()
			elif _drive.is_drained():
				_stop_charge()
			else:
				%ChargeRing.show_progress(global_position, _drive.get_progress())
		State.PARKING:
			_follow_dock(delta)
			_face_dock_side(delta)
			if _glide.is_parked(dock_gap, rotation.y):
				_finish_docking()
		State.FLYING:
			_holding_time = 0.0
			_fly(delta)
		State.HOLDING:
			_turn_rate = 0.0
			_holding_time += delta
			_start_charge()
	_feel(delta)
	# The thrusters light up as the drive charges, burn in flight (not towed) and fade after.
	var thrust := 1.0 if state == State.FLYING and not _towing else get_charge_progress()
	var still := state != State.FLYING
	(%Model as BusModel).animate(delta, still, get_charge_progress(), _turn_rate, thrust)
	var burn := (%Model as BusModel).thrust if state == State.FLYING else 0.0
	(%ThrusterTrail as ThrusterTrail).advance(global_transform * TRAIL_START, burn, delta)
	_draw_route()


func _fly(delta: float) -> void:
	if _route.is_empty():
		_speed = move_toward(_speed, 0.0, acceleration * delta)
		_move(_speed * delta)
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
	var limit := _top_speed()
	if stop.planet:
		# Brakes to the glide's speed where the glide into the dock starts.
		var glide := _glide_speed()
		var braking := maxf(distance - DOCK_DISTANCE, 0.0)
		limit = minf(limit, sqrt(glide * glide + 2.0 * acceleration * braking))
	elif last:
		# Brakes so it comes to rest at the end of the route.
		limit = minf(limit, sqrt(2.0 * acceleration * distance))
	_speed = move_toward(_speed, limit * facing * facing, acceleration * delta)
	_move(minf(_speed * delta, distance))


# Moves the bus forward, burning fuel unless it is towed.
func _move(distance: float) -> void:
	global_position += _forward() * distance
	if not _towing:
		(%FuelTank as FuelTank).burn(distance)


# At a planet it only drops the route and any charge: the player refuels there.
func _on_fuel_emptied() -> void:
	var in_space := not is_at_planet() and state != State.PARKING
	cancel_course()
	if in_space:
		ran_out_of_fuel.emit()


# Towed, tow_speed faster than the planet ahead moves now, so it always catches up.
func _top_speed() -> float:
	var planet := get_next_planet() if _towing else null
	var chase := planet.get_body_velocity().length() if planet else 0.0
	var top := _stats.get_stat(BusStats.Type.MAX_SPEED).get_value()
	return minf(chase + tow_speed, top) if _towing else top


# While charging, so the bus leaves the planet already facing where it goes.
func _face_next_stop(delta: float) -> void:
	if _route.is_empty():
		return
	var to_target := _flat(_stop_position(_route[0], global_position) - global_position)
	if to_target.length_squared() > 1e-6:
		_turn_toward(to_target, delta)


# Docked, so the door on the bus's left faces the planet. Eases out at the end of the swing.
func _face_dock_side(delta: float) -> void:
	var previous := rotation.y
	var left := absf(angle_difference(rotation.y, _glide.get_heading()))
	var step := minf(turn_speed * delta, left * (1.0 - exp(-DOCK_TURN_EASE * delta)))
	rotation.y = rotate_toward(rotation.y, _glide.get_heading(), step)
	_turn_rate = angle_difference(previous, rotation.y) / delta if delta > 0.0 else 0.0


# The speed the bus glides into its dock at, from where the glide starts.
func _glide_speed() -> float:
	return minf(DOCK_SMOOTHING * DOCK_DISTANCE, _top_speed())


func _turn_toward(direction: Vector3, delta: float) -> void:
	var previous := rotation.y
	rotation.y = rotate_toward(rotation.y, atan2(direction.x, direction.z), turn_speed * delta)
	_turn_rate = angle_difference(previous, rotation.y) / delta if delta > 0.0 else 0.0


func _reached(stop: RouteStop, distance: float, last: bool) -> bool:
	if stop.planet:
		return distance < DOCK_DISTANCE
	if last:
		return distance < STOP_DISTANCE
	return distance < pass_radius


func _arrive(stop: RouteStop) -> void:
	_speed = 0.0
	_turn_rate = 0.0
	if not stop.planet:
		state = State.HOLDING
		return
	_dock(stop.planet, global_position - stop.planet.get_body_global_position())
	state = State.PARKING


# Parked side-on: the bus has docked. It waits there, course or not, for the drive.
func _finish_docking() -> void:
	state = State.DOCKED
	_drive.warm_up(not _towing)
	if dock_sound:
		Audio.play_sfx(dock_sound)
	if _towing:
		_towing = false
		(%FuelTank as FuelTank).fill()
		towed.emit(_glide.planet)
	docked.emit(_glide.planet)


func _dock(planet: Planet, direction: Vector3) -> void:
	_glide.dock(planet, direction, global_position)
	state = State.DOCKED


# Starts a charge while the key is held with a course set, unless passengers are boarding.
func _start_charge() -> void:
	if _drive.held and not boarding and not _route.is_empty():
		state = State.CHARGING
		_drive.start()


# Drained or cancelled: the bus waits where it was, docked or holding in space.
func _stop_charge() -> void:
	_drive.clear()
	state = State.DOCKED if _glide.planet else State.HOLDING
	%ChargeRing.show_progress(global_position, 0.0)


func _undock() -> void:
	%ChargeRing.show_progress(global_position, 0.0)
	_drive.clear()
	_drive.held = false
	_drive.warm_up(false)
	_glide.planet = null
	state = State.FLYING if not _route.is_empty() else State.HOLDING


# Glides toward the dock point, measured from the planet, so the bus keeps up with a
# moving planet without lagging behind it.
func _follow_dock(delta: float) -> void:
	_turn_rate = 0.0
	if _glide.planet:
		global_position = _glide.follow(delta, _dock_gap())


func _dock_point() -> Vector3:
	return _glide.get_point(_dock_gap())


func _dock_gap() -> float:
	return charge_gap if state == State.CHARGING else dock_gap


func _stop_position(stop: RouteStop, from: Vector3) -> Vector3:
	return stop.get_target(from, dock_gap)


# Parking, the bus moves by its glide, measured from the planet.
func _feel(delta: float) -> void:
	var velocity := _glide.velocity if state == State.PARKING else _forward() * _speed
	_felt.feel(velocity, _forward(), delta)


# The line through the route still ahead.
func _draw_route() -> void:
	(%RouteLine as RouteLine).draw_stops(global_position, _route, null)


func _forward() -> Vector3:
	return _flat(global_basis.z).normalized()


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
