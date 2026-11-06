extends GdUnitTestSuite

const SCENE := "res://game/solar_system/camera_rig.tscn"
# A fixed frame time, so how far a held key pans doesn't depend on the machine's speed.
const FRAME_MS := 50

var _held: Array[Key] = []


func after_test() -> void:
	for key: Key in _held:
		_send_key(key, false)
	_held.clear()


func test_forward_key_pans_away_from_the_camera_and_stops_at_the_edge() -> void:
	var runner := scene_runner(SCENE)
	var rig := runner.scene() as Node3D
	rig.set(&"bounds_radius", 3.0)
	rig.set(&"smoothing", 1000.0)

	_hold(KEY_W)
	await runner.simulate_frames(10, FRAME_MS)

	var flat := Vector2(rig.position.x, rig.position.z)
	assert_float(flat.length()).is_equal_approx(3.0, 0.01)
	# Away from the camera: against the flattened direction from the look-at point to it.
	var toward_camera := Vector2(rig.basis.z.x, rig.basis.z.z).normalized()
	assert_float(flat.normalized().dot(toward_camera)).is_less(-0.99)


func test_wheel_zooms_between_the_limits() -> void:
	var runner := scene_runner(SCENE)
	var rig := runner.scene() as Node3D
	rig.set(&"min_distance", 10.0)
	rig.set(&"max_distance", 50.0)
	rig.set(&"smoothing", 1000.0)
	var shot := runner.find_child("Shot") as Node3D

	for i: int in 40:
		_send_wheel(MOUSE_BUTTON_WHEEL_UP)
	await runner.simulate_frames(2, FRAME_MS)
	assert_float(rig.global_position.distance_to(shot.global_position)).is_equal_approx(10.0, 0.01)

	for i: int in 40:
		_send_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await runner.simulate_frames(2, FRAME_MS)
	assert_float(rig.global_position.distance_to(shot.global_position)).is_equal_approx(50.0, 0.01)


func _hold(key: Key) -> void:
	_held.append(key)
	_send_key(key, true)


# Through Input alone: the runner's own calls deliver each event twice to the root.
func _send_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _send_wheel(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.factor = 1.0
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
