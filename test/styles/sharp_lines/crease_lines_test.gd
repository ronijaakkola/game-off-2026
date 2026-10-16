extends GdUnitTestSuite


func test_box_has_its_twelve_edges() -> void:
	var ends := CreaseLines.find_creases(BoxMesh.new())
	assert_int(ends.size()).is_equal(12 * 2)


func test_roof_prism_has_its_nine_edges() -> void:
	var ends := CreaseLines.find_creases(PrismMesh.new())
	assert_int(ends.size()).is_equal(9 * 2)


func test_smooth_meshes_get_no_lines() -> void:
	var sphere := CreaseLines.find_creases(SphereMesh.new())
	assert_int(sphere.size()).is_equal(0)
	var rounded := CreaseLines.find_creases(RoundedBoxMesh.new())
	assert_int(rounded.size()).is_equal(0)


func test_ribbons_are_four_vertices_per_edge() -> void:
	var ribbons := CreaseLines.build_ribbons(CreaseLines.find_creases(BoxMesh.new()))
	assert_int(ribbons.surface_get_array_len(0)).is_equal(12 * 4)
