extends GdUnitTestSuite

const FeedbackScript := preload("res://core/feedback/feedback.gd")

var _feedback: FeedbackScript
var _reduce_motion: bool


func before_test() -> void:
	_reduce_motion = Settings.reduce_motion
	_feedback = auto_free(FeedbackScript.new())
	add_child(_feedback)


func after_test() -> void:
	# Assigning re-saves the developer's own settings file with their value.
	Settings.reduce_motion = _reduce_motion


func test_shake_moves_the_camera_then_settles() -> void:
	var camera := _add_camera()
	_feedback.shake(1.0)
	await await_idle_frame()
	await await_idle_frame()
	assert_vector(_offset(camera)).is_not_equal(Vector2.ZERO)
	await assert_func(self, "_offset", [camera]).wait_until(1000).is_equal(Vector2.ZERO)


func test_a_huge_shake_settles_as_fast_as_a_full_one() -> void:
	var camera := _add_camera()
	_feedback.shake(100.0)
	await await_idle_frame()
	await await_idle_frame()
	assert_vector(_offset(camera)).is_not_equal(Vector2.ZERO)
	await assert_func(self, "_offset", [camera]).wait_until(1000).is_equal(Vector2.ZERO)


func test_reduce_motion_keeps_the_camera_still() -> void:
	var camera := _add_camera()
	Settings.reduce_motion = true
	_feedback.shake(1.0)
	for i: int in 5:
		await await_idle_frame()
	assert_vector(_offset(camera)).is_equal(Vector2.ZERO)


func test_a_scene_change_stops_the_shake() -> void:
	var camera := _add_camera()
	_feedback.shake(1.0)
	await await_idle_frame()
	get_tree().scene_changed.emit()
	for i: int in 5:
		await await_idle_frame()
	assert_vector(_offset(camera)).is_equal(Vector2.ZERO)


func test_direction_pushes_the_camera_that_way() -> void:
	var camera := _add_camera()
	_feedback.shake(1.0, Vector2.DOWN)
	await await_idle_frame()
	assert_float(camera.v_offset).is_less(0.0)
	_feedback.shake(1.0, Vector2.RIGHT)
	await await_idle_frame()
	assert_float(camera.h_offset).is_greater(0.0)


func test_no_camera_is_fine() -> void:
	assert_object(get_viewport().get_camera_3d()).is_null()
	_feedback.shake(1.0)
	for i: int in 5:
		await await_idle_frame()


func _add_camera() -> Camera3D:
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	camera.make_current()
	return camera


func _offset(camera: Camera3D) -> Vector2:
	return Vector2(camera.h_offset, camera.v_offset)
