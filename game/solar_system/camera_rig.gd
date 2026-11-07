class_name CameraRig
extends Node3D
## An RTS camera. WASD, the arrow keys or the pointer at a window edge pan it across the
## orbit plane, and the mouse wheel zooms it toward the point under the pointer. This node
## sits at the point the camera looks at, and its rotation is the viewing angle; its shot,
## %Shot, sits [member distance] back along that angle, and the scene's PhantomCameraHost
## moves the camera to it.
## The look-at point stays within [member bounds_radius] of the parent's origin, and the
## zoom between [member min_distance] and [member max_distance]. A zoom eases the look-at
## point and the distance to their target; a pan eases its speed and moves the look-at point
## and its target together, so zooming mid-pan doesn't hold the pan back.

## How far from the parent's origin the look-at point may go, on the orbit plane.
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

var _target_position := Vector3.ZERO
var _target_distance := 0.0
# How fast the pan moves the look-at point, in the parent's space, per second.
var _pan_velocity := Vector3.ZERO
# Edge pan waits for the pointer to move inside the window: before that its position is
# unknown, and after it leaves, the last position may sit on the edge it left through.
var _pointer_inside := false
var _pointer_position := Vector2.ZERO


func _ready() -> void:
	_target_position = _clamp_to_bounds(position)
	_target_distance = clampf(distance, min_distance, max_distance)
	distance = _target_distance
	_place_shot()
	get_window().mouse_exited.connect(_on_pointer_lost)
	get_window().focus_exited.connect(_on_pointer_lost)


# _input, not _unhandled_input: a Control under the pointer must not hide where it is.
func _input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion:
		_pointer_inside = true
		_pointer_position = motion.position


func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if not wheel or not wheel.pressed:
		return
	# A touchpad sends fractions of a notch in factor; a wheel sends 1 or 0.
	var notches := wheel.factor if wheel.factor > 0.0 else 1.0
	if event.is_action(&"camera_zoom_in"):
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


# Screen directions to pan in, -1, 0 or 1 on each axis, from the pointer at the edges.
func _edge_pan_input() -> Vector2:
	if edge_pan_margin <= 0.0 or not _pointer_inside:
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


func _clamp_to_bounds(point: Vector3) -> Vector3:
	var flat := Vector2(point.x, point.z).limit_length(bounds_radius)
	return Vector3(flat.x, point.y, flat.y)


func _place_shot() -> void:
	%Shot.position = Vector3(0.0, 0.0, distance)
