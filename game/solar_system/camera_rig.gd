extends Node3D
## An RTS camera. WASD or the arrow keys pan it across the orbit plane, and the mouse wheel
## zooms it. This node sits at the point the camera looks at, and its rotation is the
## viewing angle; its shot, %Shot, sits [member distance] back along that angle, and the
## scene's PhantomCameraHost moves the camera to it.
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
## How much one wheel notch changes the zoom distance, as a share of it.
@export_range(0.0, 0.5, 0.01) var zoom_step := 0.12
## How fast pan and zoom catch up with their target. Higher is snappier.
@export_range(0.1, 100.0, 0.1, "or_greater") var smoothing := 5.0

var _target_position := Vector3.ZERO
var _target_distance := 0.0


func _ready() -> void:
	_target_position = _clamp_to_bounds(position)
	_target_distance = clampf(distance, min_distance, max_distance)
	distance = _target_distance
	_place_shot()


func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if not wheel or not wheel.pressed:
		return
	# A touchpad sends fractions of a notch in factor; a wheel sends 1 or 0.
	var notches := wheel.factor if wheel.factor > 0.0 else 1.0
	if event.is_action(&"camera_zoom_in"):
		_zoom(1.0 - zoom_step * notches)
	elif event.is_action(&"camera_zoom_out"):
		_zoom(1.0 + zoom_step * notches)
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var input := Input.get_vector(
		&"camera_pan_left", &"camera_pan_right", &"camera_pan_forward", &"camera_pan_back"
	)
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


func _zoom(factor: float) -> void:
	_target_distance = clampf(_target_distance * factor, min_distance, max_distance)


func _clamp_to_bounds(point: Vector3) -> Vector3:
	var flat := Vector2(point.x, point.z).limit_length(bounds_radius)
	return Vector3(flat.x, point.y, flat.y)


func _place_shot() -> void:
	%Shot.position = Vector3(0.0, 0.0, distance)
