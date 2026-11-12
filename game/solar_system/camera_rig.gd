class_name CameraRig
extends Node3D
## An RTS camera. WASD, the arrow keys or the pointer at a window edge (unless
## [code]Settings.edge_pan[/code] is off) pan it across the orbit plane, holding the
## middle mouse button drags it (the point under the pointer stays under it), and the mouse
## wheel zooms it toward the point under the pointer. This node sits at the point the
## camera looks at, and its rotation is the viewing angle; its shot,
## %Shot, sits [member distance] back along that angle, and the scene's PhantomCameraHost
## moves the camera to it.
## The look-at point stays within [member bounds_radius] of [member bounds_center], and the
## zoom between [member min_distance] and [member max_distance]. A zoom eases the look-at
## point and the distance to their target; a pan eases its speed and moves the look-at point
## and its target together, so zooming mid-pan doesn't hold the pan back.
## [method focus] hands the camera to a second shot, %FocusShot, which follows a target
## from the same angle, centred in [member focus_rect]. It comes close enough that the
## target's body fills a share of the rect's height that grows with the body's radius, so a
## bigger body looks bigger, but stays far enough back that its widest part, such as rings,
## fits across the rect. The host blends to it and, on [method release_focus], back to
## %Shot, which waited where it was: pan and zoom do nothing while the rig is focused.
## While [member locked], they do nothing either, so a script can move the look-at point
## with [method move_to].

## The camera has finished blending in to a focused target, and follows it from here on.
signal focus_blend_finished

## %FocusShot's priority while focused, over %Shot's.
const FOCUSED_PRIORITY := 2

## How far from [member bounds_center] the look-at point may go, on the orbit plane.
@export_range(0.0, 200.0, 0.1, "or_greater") var bounds_radius := 20.0
## The closest zoom.
@export_range(1.0, 200.0, 0.1, "or_greater") var min_distance := 12.0
## The farthest zoom.
@export_range(1.0, 400.0, 0.1, "or_greater") var max_distance := 60.0
## The zoom at the start, from the shot to the look-at point.
@export_range(1.0, 400.0, 0.1, "or_greater") var distance := 40.0
## Pan speed, in multiples of the zoom distance per second, so a pan crosses the same share
## of the screen at any zoom.
@export_range(0.0, 5.0, 0.01) var pan_speed := 0.6
## How close to a window edge, in pixels, the pointer pans the camera. 0 turns edge pan off.
@export_range(0.0, 100.0, 1.0) var edge_pan_margin := 12.0
## How much one wheel notch changes the zoom distance, as a share of it.
@export_range(0.0, 0.5, 0.01) var zoom_step := 0.12
## How fast pan and zoom catch up with their target. Higher is snappier.
@export_range(0.1, 100.0, 0.1, "or_greater") var smoothing := 5.0
@export_group("Focus")
## How much of [member focus_rect]'s height a focused body fills, edge to edge, at
## [member focus_radius_min] and smaller.
@export_range(0.05, 1.0, 0.01) var focus_fill_min := 0.32
## The same at [member focus_radius_max] and larger. In between, it grows linearly.
@export_range(0.05, 1.0, 0.01) var focus_fill_max := 0.5
@export_range(0.0, 100.0, 0.01, "or_greater") var focus_radius_min := 0.15
@export_range(0.0, 100.0, 0.01, "or_greater") var focus_radius_max := 1.0
## How much of [member focus_rect]'s width a focused target's widest part may take.
@export_range(0.05, 1.0, 0.01) var focus_width_share := 0.92

## The part of the screen a focused target is framed in, in viewport pixels. Empty frames it
## in the whole viewport. Read every frame, so a parent can follow a window resize.
var focus_rect := Rect2()
## The centre of the area the look-at point stays in, in the parent's space: its origin
## unless the map is zoomed.
var bounds_center := Vector3.ZERO
## Whether pan, drag and zoom are off, as while the map zooms out.
var locked := false:
	set(value):
		locked = value
		_dragging = _dragging and not value

var _target_position := Vector3.ZERO
var _target_distance := 0.0
# How fast the pan moves the look-at point, in the parent's space, per second.
var _pan_velocity := Vector3.ZERO
# Edge pan waits for the pointer to move inside the window: before that its position is
# unknown, and after it leaves, the last position may sit on the edge it left through.
var _pointer_inside := false
var _pointer_position := Vector2.ZERO
# While the drag button is held, the point on the orbit plane that was under the pointer
# when it went down, which the drag keeps under the pointer.
var _dragging := false
var _grab_point := Vector3.ZERO
var _focus_target: Node3D
var _focus_radius := 0.0
var _focus_reach := 0.0
# The blend both shots use, and the seconds it takes as the scene sets it.
var _blend: PhantomCameraTween
var _focus_seconds := 0.0


func _ready() -> void:
	_target_position = _clamp_to_bounds(position)
	_target_distance = clampf(distance, min_distance, max_distance)
	distance = _target_distance
	_place_shot()
	var focus_shot := %FocusShot as PhantomCamera3D
	# The rig's own copy, since the scene's is shared by every rig made from it.
	_blend = focus_shot.tween_resource.duplicate() as PhantomCameraTween
	focus_shot.tween_resource = _blend
	(%Shot as PhantomCamera3D).tween_resource = _blend
	_focus_seconds = _blend.duration
	focus_shot.tween_completed.connect(focus_blend_finished.emit)
	get_window().mouse_exited.connect(_on_pointer_lost)
	get_window().focus_exited.connect(_on_focus_lost)


# _input, not _unhandled_input: a Control under the pointer must not hide where it is, or
# take the drag's motion and its release from it.
func _input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion:
		_pointer_inside = true
		_pointer_position = motion.position
		if _dragging:
			_drag_to(motion.position)
	var button := event as InputEventMouseButton
	if button and not button.pressed and button.is_action(&"camera_drag"):
		_dragging = false


func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if not wheel or not wheel.pressed or is_focused() or locked:
		return
	# A touchpad sends fractions of a notch in factor; a wheel sends 1 or 0.
	var notches := wheel.factor if wheel.factor > 0.0 else 1.0
	if event.is_action(&"camera_drag"):
		_start_drag(wheel.position)
	elif event.is_action(&"camera_zoom_in"):
		_zoom(1.0 - zoom_step * notches, wheel.position)
	elif event.is_action(&"camera_zoom_out"):
		_zoom(1.0 + zoom_step * notches, wheel.position)
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var keys := Input.get_vector(
		&"camera_pan_left", &"camera_pan_right", &"camera_pan_forward", &"camera_pan_back"
	)
	var input := (keys + _edge_pan_input()).limit_length(1.0)
	if locked:
		input = Vector2.ZERO
	if is_focused():
		input = Vector2.ZERO
		_place_focus_shot()
	# Screen right and screen down, laid flat on the orbit plane.
	var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	var back := Vector3(basis.z.x, 0.0, basis.z.z).normalized()
	var pan_target := (right * input.x + back * input.y) * pan_speed * distance
	var weight := 1.0 - exp(-smoothing * delta)
	_pan_velocity = _pan_velocity.lerp(pan_target, weight)
	var step := _pan_velocity * delta
	_target_position = _clamp_to_bounds(_target_position + step)
	position = _clamp_to_bounds(position + step).lerp(_target_position, weight)
	distance = lerpf(distance, _target_distance, weight)
	_place_shot()


## Hands the camera to %FocusShot, which follows [param target], a body of
## [param radius] whose widest part, such as rings, reaches [param reach] from its centre.
## Focusing on another target moves the shot on to it. The camera blends there, or cuts
## under Reduce motion.
func focus(target: Node3D, radius: float, reach: float) -> void:
	_focus_target = target
	_focus_radius = radius
	_focus_reach = maxf(reach, radius)
	var shot := %FocusShot as PhantomCamera3D
	shot.follow_target = target
	_place_focus_shot()
	_set_blend()
	shot.priority = FOCUSED_PRIORITY


## Gives the camera back to %Shot, which is where it was before [method focus].
func release_focus() -> void:
	_focus_target = null
	_set_blend()
	(%FocusShot as PhantomCamera3D).priority = 0


func is_focused() -> bool:
	return _focus_target != null


## Puts the look-at point at [param point] at once, within the bounds, and stops any pan.
func move_to(point: Vector3) -> void:
	_pan_velocity = Vector3.ZERO
	_target_position = _clamp_to_bounds(point)
	position = _target_position
	_place_shot()


## How much of [member focus_rect]'s height a body of [param radius] fills when focused,
## unless its widest part needs the camera further back.
func get_focus_fill(radius: float) -> float:
	var weight := inverse_lerp(focus_radius_min, focus_radius_max, radius)
	return lerpf(focus_fill_min, focus_fill_max, clampf(weight, 0.0, 1.0))


## Seconds the camera takes to blend in to a focused target.
func get_focus_seconds() -> float:
	return _focus_seconds


# The blend between the shots is a cut under Reduce motion.
func _set_blend() -> void:
	_blend.duration = 0.0 if Settings.reduce_motion else _focus_seconds


# Back along the rig's angle as far as the farther of two needs: the body filling its
# share of the rect's height, and its widest part fitting across the rect. Then to the side
# and up or down so it sits at the rect's centre. The camera keeps its height, so the field
# of view is vertical and the width follows the aspect. A following shot is top level, so
# it gets the rig's angle here rather than from its parent.
func _place_focus_shot() -> void:
	var shot := %FocusShot as PhantomCamera3D
	var camera := get_viewport().get_camera_3d()
	var half_height := tan(deg_to_rad(camera.fov if camera else 30.0) * 0.5)
	var screen := get_viewport().get_visible_rect().size
	var space := focus_rect if focus_rect.has_area() else Rect2(Vector2.ZERO, screen)
	# Pixels per world unit at a depth of one unit.
	var pixels_per_unit := screen.y / (2.0 * half_height)
	var fill := get_focus_fill(_focus_radius)
	var depth := maxf(
		2.0 * _focus_radius * pixels_per_unit / (fill * space.size.y),
		2.0 * _focus_reach * pixels_per_unit / (focus_width_share * space.size.x)
	)
	var center := space.get_center()
	var across := center.x / screen.x * 2.0 - 1.0
	var up := 1.0 - center.y / screen.y * 2.0
	var shift_x := -across * depth * half_height * screen.x / screen.y
	var shift_y := -up * depth * half_height
	shot.global_basis = global_basis
	shot.follow_offset = (
		global_basis.z * depth + global_basis.x * shift_x + global_basis.y * shift_y
	)


# Screen directions to pan in, -1, 0 or 1 on each axis, from the pointer at the edges.
func _edge_pan_input() -> Vector2:
	if not Settings.edge_pan or edge_pan_margin <= 0.0 or not _pointer_inside or _dragging:
		return Vector2.ZERO
	var rect := get_viewport().get_visible_rect()
	var direction := Vector2.ZERO
	if _pointer_position.x < rect.position.x + edge_pan_margin:
		direction.x = -1.0
	elif _pointer_position.x > rect.end.x - edge_pan_margin:
		direction.x = 1.0
	if _pointer_position.y < rect.position.y + edge_pan_margin:
		direction.y = -1.0
	elif _pointer_position.y > rect.end.y - edge_pan_margin:
		direction.y = 1.0
	return direction


# Grabs the plane point under screen_point. While the button is held the window keeps
# getting the pointer's motion past its edge, so a drag doesn't stop there.
func _start_drag(screen_point: Vector2) -> void:
	var offset: Variant = _plane_offset(screen_point)
	if offset == null:
		return
	var per_distance: Vector3 = offset
	_grab_point = position + per_distance * distance
	_dragging = true


# Moves the look-at point, and its target with it, so the grabbed point is under
# screen_point again. Against the bounds, the grab holds still: coming back into range
# picks the drag up where the pointer is.
func _drag_to(screen_point: Vector2) -> void:
	var offset: Variant = _plane_offset(screen_point)
	if is_focused() or offset == null:
		_dragging = false
		return
	var per_distance: Vector3 = offset
	var shift := _grab_point - per_distance * distance - position
	position = _clamp_to_bounds(position + shift)
	_target_position = _clamp_to_bounds(_target_position + shift)


# Keeps what the player sees under screen_point under it once the zoom settles. Seen from
# this rig's angle, the plane point under a screen point sits at the look-at point plus
# distance × an offset that depends only on the screen point. The point under it now comes
# from where the camera is, mid-ease or not; the new target puts it back under it.
func _zoom(factor: float, screen_point: Vector2) -> void:
	_target_distance = clampf(_target_distance * factor, min_distance, max_distance)
	var offset: Variant = _plane_offset(screen_point)
	if offset == null:
		return
	var per_distance: Vector3 = offset
	var under_pointer := position + per_distance * distance
	_target_position = _clamp_to_bounds(under_pointer - per_distance * _target_distance)


# From the look-at point to the plane point under screen_point, per unit of distance, in
# the parent's space. Null with no camera, or when the ray doesn't head down to the plane.
func _plane_offset(screen_point: Vector2) -> Variant:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return null
	# The ray as seen from the camera, turned to this rig's angle, which is the shot's.
	var camera_ray := camera.global_basis.inverse() * camera.project_ray_normal(screen_point)
	var ray := basis * camera_ray
	if ray.y > -0.001:
		return null
	# The camera sits at basis.z per unit of distance above the look-at point; walk the ray
	# down from there to the plane.
	var back := basis.z
	return back - ray * (back.y / ray.y)


func _on_pointer_lost() -> void:
	_pointer_inside = false


# The window never sees the button come up once it has lost focus.
func _on_focus_lost() -> void:
	_pointer_inside = false
	_dragging = false


func _clamp_to_bounds(point: Vector3) -> Vector3:
	var from := point - bounds_center
	var flat := Vector2(from.x, from.z).limit_length(bounds_radius)
	return Vector3(bounds_center.x + flat.x, point.y, bounds_center.z + flat.y)


func _place_shot() -> void:
	%Shot.position = Vector3(0.0, 0.0, distance)
