extends GdUnitTestSuite
## The bus's route line.


# A route whose every leg is clipped away, with no diamond, leaves nothing to draw, and
# drawing it must log no error (ImmediateMesh does on an empty surface).
func test_a_route_with_nothing_left_to_draw_logs_no_error() -> void:
	var camera := auto_free(Camera3D.new()) as Camera3D
	add_child(camera)
	camera.position = Vector3(0.0, 10.0, 10.0)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	var line := auto_free(RouteLine.new()) as RouteLine
	add_child(line)
	var at := Vector3(1.0, 0.0, 1.0)
	line.draw_route(PackedVector3Array([at, at]), PackedVector3Array())
	for i: int in 3:
		await get_tree().process_frame
	assert_object(line.mesh).is_not_null()
	assert_int((line.mesh as ImmediateMesh).get_surface_count()).is_equal(0)
