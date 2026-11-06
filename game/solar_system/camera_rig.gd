extends Node3D
## An RTS camera. WASD, the arrow keys or the pointer at a window edge pan it across the
## orbit plane, and the mouse wheel zooms it toward the point under the pointer. This node
## sits at the point the camera looks at, and its rotation is the viewing angle; its shot,
## %Shot, sits [member distance] back along that angle, and the scene's PhantomCameraHost
## moves the camera to it.
## The look-at point stays within [member bounds_radius] of the parent's origin, and the
## zoom between [member min_distance] and [member max_distance]. Both ease to their target.

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
	if input != Vector2.ZERO:
		# Screen right and screen down, laid flat on the orbit plane.
		var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
		var back := Vector3(basis.z.x, 0.0, basis.z.z).normalized()
		var step := (right * input.x + back * input.y) * pan_speed * _target_distance * delta
		_target_position = _clamp_to_bounds(_target_position + step)
	var weight := 1.0 - exp(-smoothing * delta)
	position = position.lerp(_target_position, weight)
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


# Scales the target view about the point under screen_point, so that point stays under it:
# the camera's position and look-at point move toward it, or away, by the same factor.
func _zoom(factor: float, screen_point: Vector2) -> void:
	var old_distance := _target_distance
	_target_distance = clampf(old_distance * factor, min_distance, max_distance)
	var anchor: Variant = _point_on_plane(screen_point)
	if anchor == null:
		return
	var scale_by := _target_distance / old_distance
	var anchor_point: Vector3 = anchor
	_target_position = _clamp_to_bounds(anchor_point + (_target_position - anchor_point) * scale_by)


# Where the ray through screen_point meets the orbit plane, in the parent's space, or null
# when there's no camera or the ray misses.
func _point_on_plane(screen_point: Vector2) -> Variant:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return null
	# Global to the parent's space, without naming the parent.
	var to_parent := transform * global_transform.affine_inverse()
	var origin := to_parent * camera.project_ray_origin(screen_point)
	var normal := to_parent.basis * camera.project_ray_normal(screen_point)
	return Plane(Vector3.UP, _target_position.y).intersects_ray(origin, normal)


func _on_pointer_lost() -> void:
	_pointer_inside = false


func _clamp_to_bounds(point: Vector3) -> Vector3:
	var flat := Vector2(point.x, point.z).limit_length(bounds_radius)
	return Vector3(flat.x, point.y, flat.y)


func _place_shot() -> void:
	%Shot.position = Vector3(0.0, 0.0, distance)
