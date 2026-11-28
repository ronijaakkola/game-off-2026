class_name SystemJump
extends Node
## The bus's jump from one star system to the next, which [method start] begins. It plays
## as a scene change, so the player never sees two systems at once: the HUD goes and takes
## no clicks, and the camera closes in on the bus. The bus turns smoothly to face the planet
## it docks at in the next system ([member StarSystem.jump_planet]), its thrusters lighting,
## then winds up: it draws back a little as a rumble builds, and frameshifts out as the tow
## ship does ([FrameshiftShift]) while the [JumpIris] closes on where it was. In the black
## the next level's loading screen shows until the player presses Start ([SceneFlow]), then
## the old system hides and the camera cuts to the new one, beside that planet, on its side
## away from the star, 1 unit off its surface, about where a [Stargate] floats. The iris
## opens there, the bus frameshifts in, and as it flies in to dock, burning no fuel, the
## camera eases back out to the map; bringing the HUD back is the [Progression]'s, with
## The Boss's call ([FirstShiftCall]) once the bus has docked. The bus does nothing of its
## own through it. Under Reduce motion the camera cuts, the bus doesn't turn or shift, and the
## screen only fades to black and back.
## [method warp] plays only the bus's part of it through a [WarpGate] within the system:
## the bus turns to face the gate beside it, winds up and shifts out toward it, and after
## [constant WARP_GAP_SECONDS] shifts in out of the far gate, heading for its planet, and
## flies in to dock there, with no iris. While the far gate and its planet are in view,
## clear of the screen's edges, the camera stays where the player has it. Otherwise it
## glides there as the bus shifts out, as far as from the one planet to the other, so the
## bus comes out where on screen it left, and pan and zoom wait until it is out; under
## Reduce motion it cuts there as the bus comes out. The HUD stays up but takes no clicks
## until the bus is out. It sends only [signal came_through], as the bus comes out.

## The screen is black: the bus is about to come out at [param system].
signal crossed(system: StarSystem)
## The bus has come out of the jump at [param system] and is flying in to where it stops.
signal finished(system: StarSystem)
## The bus has come out of [param gate] on a warp ([method warp]) and is flying in to dock.
signal came_through(gate: WarpGate)

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
## How far off its planet's surface the bus comes out of the jump, and how fast it flies
## in from there, as a share of its top speed: about as far out as a [Stargate] floats,
## just outside where the bus starts gliding into its dock.
const ARRIVE_GAP := 1.0
const ARRIVE_SPEED := 0.6
## Seconds between the bus shifting out of one gate and into the other on a warp.
const WARP_GAP_SECONDS := 0.3
## Seconds the camera takes to glide to the far gate on a warp, easing in and out; the bus
## shifts in no sooner than it ends.
const WARP_GLIDE_SECONDS := CameraRig.GLIDE_SECONDS
## How much of the screen's width and height, at each edge, doesn't count as in view when a
## warp checks whether the far gate is: the HUD's panels are there.
const WARP_VIEW_MARGIN := 0.15
## How far the camera's look-at point may go during the jump: anywhere.
const CROSS_BOUNDS := 10000.0

@export var bus: FrameshiftBus
@export var rig: CameraRig
@export var hud: HudLayout
## Whether the black between the systems holds the next level's loading screen, which waits
## for the player. Off for a run nobody watches, such as a balance run.
@export var shows_loading_screen := true

var _phase := Phase.NONE
var _target: StarSystem
# The gate the bus comes out of on a warp, or null on a jump to another system.
var _exit: WarpGate
# The gate it goes in through on a warp.
var _entry: WarpGate
# Whether the camera goes to the far gate on this warp, and whether it is gliding there now
# from _glide_from, _glide_time seconds in.
var _camera_follows := false
var _gliding := false
var _glide_from := Vector3.ZERO
var _glide_time := 0.0
var _direction := Vector3.BACK
var _time := 0.0
# The bus's heading as the turn starts.
var _start_heading := 0.0


func _ready() -> void:
	(%Shift as FrameshiftShift).finished.connect(_on_shift_finished)


func _process(delta: float) -> void:
	(%Shift as FrameshiftShift).advance(delta)
	_time += delta
	if _gliding:
		_glide(delta)
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


## Jumps the bus to [param target], to dock at the planet that system says.
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
	_entry = from
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
	if shows_loading_screen:
		await SceneFlow.show_loading_screen(Campaign.find(String(_target.name)))
	crossed.emit(_target)
	var arrival := _arrival_point()
	# Heading in to the planet, from its side away from the star.
	var toward := _flat(_arrival_planet().get_body_global_position() - arrival)
	_direction = toward.normalized() if toward.length_squared() > 1e-6 else _direction
	bus.rotation.y = atan2(_direction.x, _direction.z)
	# Halfway from the star to where the bus comes out, so it shows with the star.
	rig.move_to(_flat(_target.global_position).lerp(arrival, 0.5))
	bus.global_position = arrival
	anchor.global_position = arrival
	await get_tree().create_timer(DARK_SECONDS, false).timeout
	_arrive_in(arrival)


# Out of the far gate, heading for its planet, with the camera left where it is.
func _warp_out() -> void:
	var wait := FrameshiftShift.SECONDS + WARP_GAP_SECONDS
	_camera_follows = not _is_exit_in_view()
	if _camera_follows:
		rig.locked = true
		_glide_from = rig.position
		_glide_time = 0.0
		_gliding = not Settings.reduce_motion
		if _gliding:
			wait = maxf(wait, WARP_GLIDE_SECONDS)
	await get_tree().create_timer(wait, false).timeout
	if _camera_follows:
		_gliding = false
		rig.move_to(_glide_from + _warp_shift())
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
	# The way in from a jump costs no fuel, as from the stargate: it docks on a full tank.
	bus.fly_in(_destination(), bus.max_speed * ARRIVE_SPEED, _exit == null)
	if _exit:
		if _camera_follows:
			rig.locked = false
		hud.uncover()
		came_through.emit(_exit)
		return
	rig.release_focus()
	rig.locked = false
	finished.emit(_target)


# Moves the camera on toward the far gate, easing in and out.
func _glide(delta: float) -> void:
	_glide_time += delta
	var done := clampf(_glide_time / WARP_GLIDE_SECONDS, 0.0, 1.0)
	rig.move_to(_glide_from + _warp_shift() * smoothstep(0.0, 1.0, done))


# From the planet the bus warps from to the one it warps to, as they are now.
func _warp_shift() -> Vector3:
	var from := _entry.planet.get_body_global_position()
	return _flat(_exit.planet.get_body_global_position() - from)


# Whether the far gate and its planet are on screen, clear of its edges, with the camera
# the player's to leave where it is: when something else holds it, it stays too.
func _is_exit_in_view() -> bool:
	var camera := get_viewport().get_camera_3d()
	if not camera or rig.locked or rig.is_focused():
		return true
	var view := get_viewport().get_visible_rect()
	var margin := view.size * WARP_VIEW_MARGIN
	var clear := view.grow_individual(-margin.x, -margin.y, -margin.x, -margin.y)
	for point: Vector3 in [_exit.get_exit_point(), _exit.planet.get_body_global_position()]:
		if (
			camera.is_position_behind(point)
			or not clear.has_point(camera.unproject_position(point))
		):
			return false
	return true


# Seconds the camera takes to close in on the bus: none under Reduce motion, where it cuts.
func _close_in_seconds() -> float:
	return 0.0 if Settings.reduce_motion or _exit else rig.get_focus_seconds()


# Where the bus comes out of the jump: off its planet's side away from the star, as from
# the stargate, or at the far gate on a warp.
func _arrival_point() -> Vector3:
	if _exit:
		return _exit.get_exit_point()
	var planet := _arrival_planet()
	var out := _flat(planet.get_body_global_position() - _target.global_position)
	out = out.normalized() if out.length_squared() > 1e-6 else Vector3.RIGHT
	return RouteStop.approach_point(planet, out, ARRIVE_GAP)


# Where the bus flies in to dock after the jump or the warp.
func _destination() -> RouteStop:
	return RouteStop.at_planet(_exit.planet if _exit else _arrival_planet())


# The planet the bus docks at in the system it jumps to.
func _arrival_planet() -> Planet:
	return _target.jump_planet if _target.jump_planet else _target.home


func _on_screen(point: Vector3) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return get_viewport().get_visible_rect().get_center()
	return camera.unproject_position(point)


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
