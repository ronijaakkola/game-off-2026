extends GdUnitTestSuite

const SCENE := "res://game/solar_system/camera_rig.tscn"
# The rig with the camera and host it drives, for what needs the camera.
const SOLAR_SYSTEM := "res://game/solar_system/solar_system.tscn"
# A fixed frame time, so how far a held key pans doesn't depend on the machine's speed.
const FRAME_MS := 50

var _held: Array[Key] = []
var _window_size: Vector2i


func before() -> void:
	# Headless, the window is 64×64, and the canvas_items stretch would scale every pointer
	# position by 18. At the base size it scales by 1.
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(1152, 648)


func after() -> void:
	get_tree().root.size = _window_size


func after_test() -> void:
	for key: Key in _held:
		_send_key(key, false)
	_held.clear()


func test_forward_key_pans_away_from_the_camera_and_stops_at_the_edge() -> void:
	var runner := scene_runner(SCENE)
	var rig := runner.scene() as CameraRig
	rig.bounds_radius = 3.0
	rig.smoothing = 1000.0

	_hold(KEY_W)
	await runner.simulate_frames(10, FRAME_MS)

	var flat := Vector2(rig.position.x, rig.position.z)
	assert_float(flat.length()).is_equal_approx(3.0, 0.01)
	# Away from the camera: against the flattened direction from the look-at point to it.
	var toward_camera := Vector2(rig.basis.z.x, rig.basis.z.z).normalized()
	assert_float(flat.normalized().dot(toward_camera)).is_less(-0.99)


func test_wheel_zooms_between_the_limits() -> void:
	var runner := scene_runner(SCENE)
	var rig := runner.scene() as CameraRig
	rig.min_distance = 10.0
	rig.max_distance = 50.0
	rig.smoothing = 1000.0
	var shot := runner.find_child("Shot") as Node3D

	for i: int in 40:
		_send_wheel(MOUSE_BUTTON_WHEEL_UP)
	await runner.simulate_frames(2, FRAME_MS)
	assert_float(rig.global_position.distance_to(shot.global_position)).is_equal_approx(10.0, 0.01)

	for i: int in 40:
		_send_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await runner.simulate_frames(2, FRAME_MS)
	assert_float(rig.global_position.distance_to(shot.global_position)).is_equal_approx(50.0, 0.01)


func test_wheel_zooms_toward_what_is_under_the_pointer_even_mid_zoom() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	var rig := runner.find_child("CameraRig") as CameraRig
	# Eased, so the second burst lands while the camera is still on its way.
	rig.smoothing = 20.0
	var camera := runner.find_child("Camera") as Camera3D
	await runner.simulate_frames(2, FRAME_MS)
	var start_distance := camera.global_position.distance_to(rig.global_position)

	for i: int in 3:
		_send_wheel(MOUSE_BUTTON_WHEEL_UP, Vector2(900, 180))
	await runner.simulate_frames(1, FRAME_MS)
	# The pointer has moved; what the player sees under it now is what must stay there.
	var pointer := Vector2(300, 450)
	var under_pointer := _plane_point(camera, pointer)
	for i: int in 3:
		_send_wheel(MOUSE_BUTTON_WHEEL_UP, pointer)
	await runner.simulate_frames(20, FRAME_MS)

	assert_float(camera.global_position.distance_to(rig.global_position)).is_less(
		start_distance - 10.0
	)
	assert_float(camera.unproject_position(under_pointer).distance_to(pointer)).is_less(1.0)


func test_zooming_mid_pan_keeps_the_pan_going() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	var rig := runner.find_child("CameraRig") as CameraRig
	rig.edge_pan_margin = 0.0
	# Room to pan for the whole test: the frames wait in real time, which runs longer.
	rig.bounds_radius = 1000.0
	var screen_right := Vector3(rig.basis.x.x, 0.0, rig.basis.x.z).normalized()
	_hold(KEY_D)
	await runner.simulate_frames(20, FRAME_MS)
	var before := rig.position
	await runner.simulate_frames(5, FRAME_MS)
	var pan_before := (rig.position - before).dot(screen_right)

	# At the screen's centre, so the zoom itself doesn't move the look-at point.
	_send_wheel(MOUSE_BUTTON_WHEEL_UP)
	before = rig.position
	await runner.simulate_frames(5, FRAME_MS)
	var pan_after := (rig.position - before).dot(screen_right)

	assert_float(pan_before).is_greater(1.0)
	# A notch zooms in by a share, and the pan slows with the zoom; no more than that.
	assert_float(pan_after).is_greater(pan_before * (1.0 - rig.zoom_step))


func test_pointer_at_an_edge_pans_until_it_leaves_the_window() -> void:
	var runner := scene_runner(SCENE)
	var rig := runner.scene() as CameraRig
	rig.smoothing = 1000.0
	var rect := rig.get_viewport().get_visible_rect()

	_send_motion(Vector2(rect.end.x - 2.0, rect.get_center().y))
	await runner.simulate_frames(5, FRAME_MS)
	var screen_right := Vector2(rig.basis.x.x, rig.basis.x.z).normalized()
	var moved := Vector2(rig.position.x, rig.position.z)
	assert_float(moved.dot(screen_right)).is_greater(1.0)

	# On the web the pointer can leave through that edge, and its last position stays there.
	rig.get_window().mouse_exited.emit()
	var left_at := rig.position
	await runner.simulate_frames(5, FRAME_MS)
	assert_vector(rig.position).is_equal_approx(left_at, Vector3.ONE * 0.001)


func test_focus_frames_the_target_beside_the_panel_and_release_goes_back() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	var rig := runner.find_child("CameraRig") as CameraRig
	var camera := runner.find_child("Camera") as Camera3D
	await runner.simulate_frames(2, FRAME_MS)
	var start := camera.global_position
	var target := Node3D.new()
	target.position = Vector3(4.0, 0.0, 3.0)
	runner.scene().add_child(target)

	rig.focus(target, 0.5, 0.5)
	# Past the blend.
	await runner.simulate_frames(30, FRAME_MS)

	# The solar system sets focus_rect every frame: the space left of its planet panel.
	var space := rig.focus_rect
	assert_float(space.size.x).is_between(600.0, 1000.0)
	var center := camera.unproject_position(target.global_position)
	assert_vector(center).is_equal_approx(space.get_center(), Vector2.ONE)
	# The body fills its share of the rect's height.
	var edge := camera.unproject_position(target.global_position + camera.global_basis.y * 0.5)
	var fill := center.distance_to(edge) * 2.0 / space.size.y
	assert_float(fill).is_equal_approx(rig.get_focus_fill(0.5), 0.01)

	rig.release_focus()
	await runner.simulate_frames(30, FRAME_MS)
	assert_vector(camera.global_position).is_equal_approx(start, Vector3.ONE * 0.01)


func test_focus_keeps_wide_rings_inside_the_rect() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	var rig := runner.find_child("CameraRig") as CameraRig
	var camera := runner.find_child("Camera") as Camera3D
	await runner.simulate_frames(2, FRAME_MS)
	var target := Node3D.new()
	runner.scene().add_child(target)

	rig.focus(target, 0.5, 3.0)
	await runner.simulate_frames(30, FRAME_MS)

	# The rings decide: they take focus_width_share of the rect's width, and the body less
	# than its share of the height.
	var space := rig.focus_rect
	var center := camera.unproject_position(target.global_position)
	var ring_edge := camera.unproject_position(target.global_position + camera.global_basis.x * 3.0)
	var across := center.distance_to(ring_edge) * 2.0 / space.size.x
	assert_float(across).is_equal_approx(rig.focus_width_share, 0.01)
	var edge := camera.unproject_position(target.global_position + camera.global_basis.y * 0.5)
	var fill := center.distance_to(edge) * 2.0 / space.size.y
	assert_float(fill).is_less(rig.get_focus_fill(0.5))


func test_a_bigger_body_fills_more_of_the_height() -> void:
	var rig := auto_free(CameraRig.new()) as CameraRig
	assert_float(rig.get_focus_fill(0.0)).is_equal(rig.focus_fill_min)
	assert_float(rig.get_focus_fill(0.5)).is_greater(rig.get_focus_fill(0.3))
	assert_float(rig.get_focus_fill(5.0)).is_equal(rig.focus_fill_max)


func test_pan_and_zoom_do_nothing_while_focused() -> void:
	var runner := scene_runner(SOLAR_SYSTEM)
	var rig := runner.find_child("CameraRig") as CameraRig
	rig.smoothing = 1000.0
	var shot := runner.find_child("Shot") as Node3D
	await runner.simulate_frames(2, FRAME_MS)
	var target := Node3D.new()
	runner.scene().add_child(target)
	rig.focus(target, 0.5, 0.5)
	var position_before := rig.position
	var distance_before := rig.global_position.distance_to(shot.global_position)

	_hold(KEY_D)
	_send_wheel(MOUSE_BUTTON_WHEEL_UP)
	await runner.simulate_frames(10, FRAME_MS)

	assert_vector(rig.position).is_equal_approx(position_before, Vector3.ONE * 0.001)
	var distance := rig.global_position.distance_to(shot.global_position)
	assert_float(distance).is_equal_approx(distance_before, 0.001)


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


func _send_wheel(button: MouseButton, at := Vector2(576, 324)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.global_position = at
	event.factor = 1.0
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _send_motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _plane_point(camera: Camera3D, screen_point: Vector2) -> Vector3:
	return Plane(Vector3.UP, 0.0).intersects_ray(
		camera.project_ray_origin(screen_point), camera.project_ray_normal(screen_point)
	)
