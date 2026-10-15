extends GdUnitTestSuite

const SCENE := "res://styles/style_base.tscn"


func test_camera_circles_the_subjects_at_a_constant_distance() -> void:
	var runner := scene_runner(SCENE)
	var camera := runner.find_child("Camera") as Camera3D
	var start := camera.global_position
	runner.set_property("orbit_speed", 90.0)
	await runner.simulate_frames(10, 100)
	var moved := camera.global_position
	assert_float(moved.distance_to(start)).is_greater(1.0)
	assert_float(Vector2(moved.x, moved.z).length()).is_equal_approx(
		Vector2(start.x, start.z).length(), 0.001
	)
	assert_float(moved.y).is_equal_approx(start.y, 0.001)


func test_zero_speed_holds_the_camera_still() -> void:
	var runner := scene_runner(SCENE)
	var camera := runner.find_child("Camera") as Camera3D
	var start := camera.global_position
	runner.set_property("orbit_speed", 0.0)
	await runner.simulate_frames(10, 100)
	assert_vector(camera.global_position).is_equal_approx(start, Vector3.ONE * 0.001)


func test_subjects_are_mesh_nodes_a_style_can_give_a_material() -> void:
	var runner := scene_runner(SCENE)
	for subject_name: String in ["Cube", "Sphere"]:
		var subject := runner.find_child(subject_name) as MeshInstance3D
		assert_object(subject).is_not_null()
		assert_int(subject.mesh.get_surface_count()).is_equal(1)


func test_the_building_sits_on_the_ground() -> void:
	var runner := scene_runner(SCENE)
	var building := runner.find_child("Cube") as MeshInstance3D
	var bounds := building.global_transform * building.mesh.get_aabb()
	assert_float(bounds.position.y).is_equal_approx(0.0, 0.001)
