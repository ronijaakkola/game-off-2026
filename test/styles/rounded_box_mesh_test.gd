extends GdUnitTestSuite


func _mesh(size: Vector3, radius: float) -> RoundedBoxMesh:
	var mesh := RoundedBoxMesh.new()
	mesh.size = size
	mesh.radius = radius
	return mesh


func test_bounds_match_size() -> void:
	var bounds := _mesh(Vector3(1.0, 2.0, 3.0), 0.2).get_aabb()
	assert_vector(bounds.position).is_equal_approx(Vector3(-0.5, -1.0, -1.5), Vector3.ONE * 0.001)
	assert_vector(bounds.size).is_equal_approx(Vector3(1.0, 2.0, 3.0), Vector3.ONE * 0.001)


func test_faces_point_outward() -> void:
	var arrays := _mesh(Vector3.ONE, 0.15).get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var inward := 0
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i + 1]]
		var c := vertices[indices[i + 2]]
		var facing := (b - a).cross(c - a)
		var centre := (a + b + c) / 3.0
		# Godot winds front faces clockwise, so an outward face has a normal opposite its cross product.
		if facing.dot(centre) > 0.0:
			inward += 1
	assert_int(inward).is_equal(0)


func test_radius_over_half_the_side_is_a_sphere() -> void:
	var arrays := _mesh(Vector3.ONE, 5.0).get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		assert_float(vertex.length()).is_equal_approx(0.5, 0.001)
