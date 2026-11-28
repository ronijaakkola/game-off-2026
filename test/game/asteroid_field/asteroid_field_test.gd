extends GdUnitTestSuite
## That the rocks hold still while the game is paused: the belt's turn and their tumble.

const FIELD := "res://game/asteroid_field/asteroid_field.tscn"


# The tumble ran on the shader's TIME, which keeps counting while the game is paused, so the
# rocks went on turning under the pause menu.
func test_the_rocks_stop_turning_and_tumbling_while_the_game_is_paused() -> void:
	var field := (load(FIELD) as PackedScene).instantiate() as AsteroidField
	add_child(auto_free(field))
	var material := (field.get_node(^"%Rocks") as MultiMeshInstance3D).material_override
	var shader := material as ShaderMaterial
	await get_tree().process_frame
	await get_tree().process_frame
	var tumbled := shader.get_shader_parameter(&"tumble_time") as float
	assert_float(tumbled).is_greater(0.0)

	get_tree().paused = true
	var turned := field.rotation.y
	for i: int in 5:
		await get_tree().process_frame
	get_tree().paused = false

	assert_float(field.rotation.y).is_equal(turned)
	assert_float(shader.get_shader_parameter(&"tumble_time") as float).is_equal(tumbled)

	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(shader.get_shader_parameter(&"tumble_time") as float).is_greater(tumbled)
