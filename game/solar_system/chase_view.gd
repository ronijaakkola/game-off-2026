class_name ChaseView
extends Node
## A third-person view from behind and above the bus, to try flying it by hand. V turns it
## on and off, as does its button on the debug panel. While on, %ChaseShot outranks the
## map's shots, and the scene's PhantomCameraHost blends to it, or cuts under Reduce motion.
## Meanwhile:
## - Dragging with the left mouse button turns the camera round the bus and tilts it, and
##   moves nothing else. A left press over the 3D view starts the drag, so it opens no
##   planet; over the HUD, it clicks the HUD as usual. The camera keeps its angle to the
##   bus as the bus turns, swinging round after it a little late.
## - The mouse wheel zooms in and out, between [member min_distance] and [member max_distance].
## - WASD or the arrow keys fly the bus: W ahead, S brakes, A and D turn it. At a planet,
##   W charges the drive to leave, as holding the Frameshift key does.
## - E near a planet sets a course to it: let go of the steering keys and the bus flies in
##   and docks.
## - The map camera is locked, since its pan keys steer, and it comes back over the bus.
## The view widens the camera's field of view to [member fov] meanwhile, and puts it back
## after. It does so itself: the plugin's Camera3DResource would, but its script's .uid file
## is malformed, so a scene can't keep a stable reference to it.

## Turns the view on and off. A physical key, so it is the same on every keyboard layout.
const TOGGLE_KEY := KEY_V
## Sets a course to the nearest planet in [member dock_reach].
const DOCK_KEY := KEY_E
## The shot's priority while on, over the camera rig's.
const PRIORITY := 10

@export var bus: FrameshiftBus
@export var rig: CameraRig
## Where the planets are, searched through for [Planet]s at any depth.
@export var world: Node3D
## The vertical field of view behind the bus, in degrees.
@export_range(10.0, 120.0, 1.0) var fov := 55.0
## How far the camera sits from the bus at the start.
@export_range(0.5, 20.0, 0.1) var distance := 2.3
## The closest and farthest the wheel zooms.
@export_range(0.5, 20.0, 0.1) var min_distance := 1.2
@export_range(0.5, 50.0, 0.1) var max_distance := 8.0
## How much one wheel notch changes the distance, as a share of it.
@export_range(0.0, 0.5, 0.01) var zoom_step := 0.12
## How fast the zoom catches up with the wheel. Higher is snappier.
@export_range(0.1, 50.0, 0.1) var zoom_smoothing := 10.0
## How far ahead of the bus, the way the camera faces, it looks.
@export_range(0.0, 10.0, 0.1) var look_ahead := 1.2
## How fast the camera swings round after the bus as it turns. Higher is stiffer.
@export_range(0.1, 30.0, 0.1) var turn_smoothing := 3.0
## How far the camera turns per pixel the mouse moves, in degrees.
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity := 0.2
## How far the camera may tilt down to look at the bus, in degrees: from just above the
## orbit plane to well overhead.
@export_range(-80.0, 89.0, 1.0) var min_pitch := 5.0
@export_range(-80.0, 89.0, 1.0) var max_pitch := 70.0
## How far from a planet's surface [constant DOCK_KEY] still finds it.
@export_range(0.0, 20.0, 0.1) var dock_reach := 3.0

var _blend: PhantomCameraTween
var _blend_seconds := 0.0
# The camera's field of view before the view came on, to go back to.
var _map_fov := 0.0
var _fov_tween: Tween
# The bus's heading as the camera trails it, how far the mouse has turned the camera from
# behind it, and how far down it looks, in radians.
var _heading := 0.0
var _orbit := 0.0
var _pitch := deg_to_rad(19.0)
# The distance the zoom eases toward.
var _target_distance := 0.0
# Whether the rig was locked before the view came on, to give it back that way.
var _rig_was_locked := false
# Whether the steering keys hold the drive at a planet, so letting go of them lets go of it.
var _holding_drive := false
# Whether the left button is down after a press over the 3D view, so motion turns the camera.
var _rotating := false
var _planets: Array[Planet] = []


func _ready() -> void:
	# After the bus has moved this frame, and before the host moves the camera.
	process_priority = 1
	var shot := %ChaseShot as PhantomCamera3D
	# Its own copy, so changing its duration leaves the scene's alone.
	_blend = shot.tween_resource.duplicate() as PhantomCameraTween
	shot.tween_resource = _blend
	_blend_seconds = _blend.duration
	_target_distance = clampf(distance, min_distance, max_distance)
	distance = _target_distance
	if world:
		_collect_planets(world)
	DebugPanel.add_button("Chase view", _debug_toggle, self)
	# The window never sees the button come up once it has lost focus.
	get_window().focus_exited.connect(_stop_rotating)


# _input, not _unhandled_input: a Control under the pointer must not take the drag's motion
# or its release. While the button is held the window keeps getting the pointer's motion
# past its edge, so a drag doesn't stop there.
func _input(event: InputEvent) -> void:
	if not is_on() or not bus:
		return
	var click := event as InputEventMouseButton
	if click and click.button_index == MOUSE_BUTTON_LEFT:
		if not click.pressed:
			_stop_rotating()
		elif not get_viewport().gui_get_hovered_control():
			_rotating = true
			get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion and _rotating:
		var turn := deg_to_rad(mouse_sensitivity)
		_orbit -= motion.relative.x * turn
		_pitch = clampf(
			_pitch + motion.relative.y * turn, deg_to_rad(min_pitch), deg_to_rad(max_pitch)
		)


# Unhandled, so the wheel over a scrolling panel scrolls the panel. The rig ignores the
# wheel while locked, as it is while the view is on.
func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel and wheel.pressed and is_on():
		# A touchpad sends fractions of a notch in factor; a wheel sends 1 or 0.
		var notches := wheel.factor if wheel.factor > 0.0 else 1.0
		if event.is_action(&"camera_zoom_in"):
			_zoom(1.0 - zoom_step * notches)
		elif event.is_action(&"camera_zoom_out"):
			_zoom(1.0 + zoom_step * notches)
		else:
			return
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	if key.physical_keycode == TOGGLE_KEY:
		toggle()
	elif key.physical_keycode == DOCK_KEY and is_on():
		_dock_nearby()
	else:
		return
	get_viewport().set_input_as_handled()


# Placed even while off, behind the bus, so turning it on blends to where the bus is now.
func _process(delta: float) -> void:
	if not bus:
		return
	var weight := 1.0 - exp(-turn_smoothing * delta)
	if not is_on():
		_heading = bus.global_rotation.y
	else:
		_heading = lerp_angle(_heading, bus.global_rotation.y, weight)
		_steer()
	distance = lerpf(distance, _target_distance, 1.0 - exp(-zoom_smoothing * delta))
	var facing := _facing()
	var back := -facing * cos(_pitch) + Vector3.UP * sin(_pitch)
	var from := bus.global_position + back * distance
	var to := bus.global_position + facing * look_ahead
	(%ChaseShot as PhantomCamera3D).look_at_from_position(from, to, Vector3.UP)


## Turns the view on when it is off, and off when it is on.
func toggle() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera or not bus or not rig:
		return
	var turning_on := not is_on()
	if turning_on:
		_map_fov = camera.fov
		_orbit = 0.0
		_rig_was_locked = rig.locked
		rig.locked = true
	else:
		_stop_rotating()
		bus.steering = Vector2.ZERO
		_let_go_of_drive()
		rig.locked = _rig_was_locked
		rig.move_to(bus.global_position)
	var seconds := 0.0 if Settings.reduce_motion else _blend_seconds
	_blend.duration = seconds
	(%ChaseShot as PhantomCamera3D).priority = PRIORITY if turning_on else 0
	if _fov_tween:
		_fov_tween.kill()
	_fov_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fov_tween.tween_property(camera, ^"fov", fov if turning_on else _map_fov, seconds)


func is_on() -> bool:
	return (%ChaseShot as PhantomCamera3D).priority >= PRIORITY


# The steering keys, as the bus sees them. At a planet, W holds the drive.
func _steer() -> void:
	rig.locked = true
	bus.steering = Vector2(
		Input.get_axis(&"camera_pan_left", &"camera_pan_right"),
		Input.get_axis(&"camera_pan_back", &"camera_pan_forward")
	)
	if bus.steering.y > 0.0 and bus.is_at_planet():
		bus.frameshift_held = true
		_holding_drive = true
	elif bus.steering.y <= 0.0:
		_let_go_of_drive()


func _zoom(factor: float) -> void:
	_target_distance = clampf(_target_distance * factor, min_distance, max_distance)


func _stop_rotating() -> void:
	_rotating = false


func _let_go_of_drive() -> void:
	if _holding_drive:
		bus.frameshift_held = false
		_holding_drive = false


# Sets a course to the shown planet nearest the bus, surface to bus, within reach.
func _dock_nearby() -> void:
	if not _in_space():
		return
	var nearest: Planet = null
	var nearest_gap := dock_reach
	for planet: Planet in _planets:
		if not planet.is_visible_in_tree():
			continue
		var to_planet := planet.get_body_global_position() - bus.global_position
		var gap := to_planet.length() - planet.get_body_radius()
		if gap <= nearest_gap:
			nearest = planet
			nearest_gap = gap
	if nearest:
		bus.plot_course(RouteStop.at_planet(nearest))


func _in_space() -> bool:
	return not bus.is_at_planet() and bus.state != FrameshiftBus.State.PARKING


# Flat on the orbit plane: the way the camera faces round the bus.
func _facing() -> Vector3:
	return Basis(Vector3.UP, _heading + _orbit) * Vector3.BACK


func _collect_planets(node: Node) -> void:
	for child: Node in node.get_children():
		var planet := child as Planet
		if planet:
			_planets.append(planet)
		_collect_planets(child)


func _debug_toggle() -> void:
	toggle()
