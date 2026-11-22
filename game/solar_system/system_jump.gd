class_name SystemJump
extends Node
## The bus's jump from one star system to the next, which [method start] begins. It plays
## as a scene change, so the player never sees two systems at once: the HUD goes and takes
## no clicks, and the camera closes in on the bus. The bus turns smoothly to face the next
## system's home planet, its thrusters lighting, then winds up: it draws back a little as a
## rumble builds, and frameshifts out as the tow ship does ([FrameshiftShift]) while the
## [JumpIris] closes on where it was. In the black
## the old system hides and the camera cuts to the new one, a little way off its home
## planet, or at the point in space where that system has the bus come to rest. The iris
## opens there, the bus frameshifts in, and as it flies in to dock, or stops there at rest
## on a full tank, the camera eases back out to the map; bringing the HUD back is the
## [Progression]'s, with The Boss's call ([FirstShiftCall]). The bus does nothing of its
## own through it. Under Reduce motion the camera cuts, the bus doesn't turn or shift, and the
## screen only fades to black and back.
## [method warp] plays only the bus's part of it through a [WarpGate] within the system:
## the bus turns to face the gate beside it, winds up and shifts out toward it, and after
## [constant WARP_GAP_SECONDS] shifts in out of the far gate, heading for its planet, and
## flies in to dock there. The camera stays where the player has it, with no iris, and the
## HUD stays up but takes no clicks until the bus is out. Neither signal is sent.

## The screen is black: the bus is about to come out at [param system].
signal crossed(system: StarSystem)
## The bus has come out of the jump at [param system] and is flying in to where it stops.
signal finished(system: StarSystem)

enum Phase { NONE, CLOSING_IN, TURNING, WINDING_UP, LEAVING, ARRIVING }

## Seconds the bus takes to turn to face the next system, easing in and out.
const TURN_SECONDS := 0.6
## Seconds it then winds up before it shifts out: it draws back [constant PULL_BACK] units
## along its heading, easing in and out, as a rumble grows to [constant RUMBLE] units.
const WIND_UP_SECONDS := 0.7
const PULL_BACK := 0.2
const RUMBLE := 0.02
## The rumble's waves, a second: a few that don't line up, so it never repeats or jitters.
const RUMBLE_RATES: Array[float] = [17.0, 23.0, 29.0]
## Seconds the screen stays black between the systems.
const DARK_SECONDS := 0.4
## Seconds after the iris starts to open that the bus shifts in.
const SHIFT_IN_DELAY := 0.35
## How far off its home planet's surface the bus comes out of the jump, and how fast it
## flies in from there, as a share of its top speed.
const ARRIVE_GAP := 2.0
const ARRIVE_SPEED := 0.6
## Seconds between the bus shifting out of one gate and into the other on a warp.
const WARP_GAP_SECONDS := 0.3
## How far the camera's look-at point may go during the jump: anywhere.
const CROSS_BOUNDS := 10000.0

@export var bus: FrameshiftBus
@export var rig: CameraRig
@export var hud: HudLayout

var _phase := Phase.NONE
var _target: StarSystem
# The gate the bus comes out of on a warp, or null on a jump to another system.
var _exit: WarpGate
var _direction := Vector3.BACK
var _time := 0.0
# The bus's heading as the turn starts.
var _start_heading := 0.0


func _ready() -> void:
	(%Shift as FrameshiftShift).finished.connect(_on_shift_finished)


func _process(delta: float) -> void:
	(%Shift as FrameshiftShift).advance(delta)
	_time += delta
	match _phase:
		Phase.CLOSING_IN:
			if _time >= _close_in_seconds():
				_time = 0.0
				_start_heading = bus.rotation.y
				_phase = Phase.TURNING
				if Settings.reduce_motion:
					_leave()
		Phase.TURNING:
			_turn(delta)
		Phase.WINDING_UP:
			_wind_up(delta)


## Whether a jump is under way.
func is_jumping() -> bool:
	return _phase != Phase.NONE


## Jumps the bus to [param target], to dock at its home planet or come to rest where that
## system says.
func start(target: StarSystem) -> void:
	if is_jumping() or not target.home:
		return
	_target = target
	_exit = null
	_begin(_destination().get_target(bus.global_position, 0.0))


## Warps the bus through [param from], the gate beside the planet it is docked at, and out
## of [param to], to dock at that gate's planet.
func warp(from: WarpGate, to: WarpGate) -> void:
	if is_jumping():
		return
	_target = null
	_exit = to
	_face(from.global_position)
	hud.cover()
	_time = 0.0
	_phase = Phase.CLOSING_IN


# Starts closing in on the bus, which will leave toward [param toward].
func _begin(toward: Vector3) -> void:
	_face(toward)
	hud.cover()
	hud.hide_all()
	rig.locked = true
	rig.bounds_radius = CROSS_BOUNDS
	var anchor := %Anchor as Node3D
	anchor.global_position = bus.global_position
	# The whole screen, wide enough for the shift out to stay in it.
	rig.focus_rect = Rect2()
	rig.focus(anchor, FrameshiftBus.RADIUS, FrameshiftShift.DISTANCE)
	_time = 0.0
	_phase = Phase.CLOSING_IN


# Holds the bus still, to leave toward [param toward].
func _face(toward: Vector3) -> void:
	_direction = _flat(toward - bus.global_position)
	_direction = _direction.normalized() if _direction.length_squared() > 1e-6 else Vector3.BACK
	bus.process_mode = Node.PROCESS_MODE_DISABLED


# Swings the bus round to face the next system, banking into the turn.
func _turn(delta: float) -> void:
	var before := bus.rotation.y
	var heading := atan2(_direction.x, _direction.z)
	var done := clampf(_time / TURN_SECONDS, 0.0, 1.0)
	bus.rotation.y = lerp_angle(_start_heading, heading, smoothstep(0.0, 1.0, done))
	var turn_rate := angle_difference(before, bus.rotation.y) / maxf(delta, 1e-6)
	bus.get_model().animate(delta, true, 0.0, turn_rate, 1.0)
	if done >= 1.0:
		_time = 0.0
		_phase = Phase.WINDING_UP


# Draws the bus back as a smooth rumble builds, then lets it go.
func _wind_up(delta: float) -> void:
	var model := bus.get_model()
	model.animate(delta, true, 0.0, 0.0, 1.0)
	var done := clampf(_time / WIND_UP_SECONDS, 0.0, 1.0)
	var rumble := Vector2.ZERO
	for i: int in RUMBLE_RATES.size():
		var phase := TAU * RUMBLE_RATES[i] * _time
		rumble += Vector2(sin(phase + i), cos(phase * 1.3 + i * 2.0)) / RUMBLE_RATES.size()
	rumble *= RUMBLE * done * done
	# The model's own space: x across, y up, z forward along its heading.
	model.position += Vector3(rumble.x, rumble.y, -PULL_BACK * smoothstep(0.0, 1.0, done))
	if done >= 1.0:
		_leave()


# Out of the old system: the bus shifts out as the iris closes on where it was, and in
# the black the new system takes its place.
func _leave() -> void:
	_phase = Phase.LEAVING
	bus.get_model().position = Vector3.ZERO
	var anchor := %Anchor as Node3D
	if Settings.reduce_motion:
		bus.get_model().hide()
	else:
		var from := bus.global_position
		var to := from + _direction * FrameshiftShift.DISTANCE
		(%Shift as FrameshiftShift).shift_out(bus, bus.get_model(), from, to)
	if _exit:
		_warp_out()
		return
	await (%Iris as JumpIris).close(_on_screen(anchor.global_position))
	# Halfway to where the bus comes to rest in space, so it shows with the star.
	rig.move_to(_target.position + _target.jump_arrival * 0.5)
	crossed.emit(_target)
	bus.rotation.y = atan2(_direction.x, _direction.z)
	var arrival := _arrival_point()
	bus.global_position = arrival
	anchor.global_position = arrival
	await get_tree().create_timer(DARK_SECONDS, false).timeout
	_arrive_in(arrival)


# Out of the far gate, heading for its planet, with the camera left where it is.
func _warp_out() -> void:
	await get_tree().create_timer(FrameshiftShift.SECONDS + WARP_GAP_SECONDS, false).timeout
	var toward := _flat(_exit.planet.get_body_global_position() - _exit.get_exit_point())
	_direction = toward.normalized() if toward.length_squared() > 1e-6 else _direction
	bus.rotation.y = atan2(_direction.x, _direction.z)
	var arrival := _arrival_point()
	bus.global_position = arrival
	_phase = Phase.ARRIVING
	if Settings.reduce_motion:
		_arrive()
		return
	var from := arrival - _direction * FrameshiftShift.DISTANCE
	(%Shift as FrameshiftShift).shift_in(bus, bus.get_model(), from, arrival)


# Into the new system: the iris opens on where the bus comes out, and it shifts in.
func _arrive_in(arrival: Vector3) -> void:
	_phase = Phase.ARRIVING
	var iris := %Iris as JumpIris
	iris.open(_on_screen(arrival))
	if Settings.reduce_motion:
		bus.get_model().show()
		await iris.opened
		_arrive()
		return
	await get_tree().create_timer(SHIFT_IN_DELAY, false).timeout
	var from := arrival - _direction * FrameshiftShift.DISTANCE
	(%Shift as FrameshiftShift).shift_in(bus, bus.get_model(), from, arrival)


func _on_shift_finished() -> void:
	if _phase == Phase.ARRIVING:
		_arrive()


func _arrive() -> void:
	_phase = Phase.NONE
	bus.get_model().show()
	bus.process_mode = Node.PROCESS_MODE_INHERIT
	# Coming out where it rests, it is there at once, with nothing to fly.
	bus.fly_in(_destination(), bus.max_speed * ARRIVE_SPEED)
	if _exit:
		hud.uncover()
		return
	rig.release_focus()
	rig.locked = false
	finished.emit(_target)


# Seconds the camera takes to close in on the bus: none under Reduce motion, where it cuts.
func _close_in_seconds() -> float:
	return 0.0 if Settings.reduce_motion or _exit else rig.get_focus_seconds()


# Where the bus comes out of the jump: off the home planet's side it came from, or where it
# comes to rest, or at the far gate on a warp.
func _arrival_point() -> Vector3:
	if _exit:
		return _exit.get_exit_point()
	if _target.jump_arrival == Vector3.ZERO:
		return RouteStop.approach_point(_target.home, -_direction, ARRIVE_GAP)
	return _flat(_target.global_position + _target.jump_arrival)


# Where the bus flies in to after the jump: its home planet, or a point in space.
func _destination() -> RouteStop:
	if _exit:
		return RouteStop.at_planet(_exit.planet)
	if _target.jump_arrival == Vector3.ZERO:
		return RouteStop.at_planet(_target.home)
	return RouteStop.at_point(_flat(_target.global_position + _target.jump_arrival))


func _on_screen(point: Vector3) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return get_viewport().get_visible_rect().get_center()
	return camera.unproject_position(point)


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
