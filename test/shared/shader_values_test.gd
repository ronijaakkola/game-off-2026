extends GdUnitTestSuite

const SHADER := preload("res://shared/two_tone.gdshader")


func test_show_sets_a_value_the_material_doesn_t_hold() -> void:
	var material := ShaderMaterial.new()
	material.shader = SHADER

	ShaderValues.show(material, &"tint_amount", 0.5)
	assert_float(material.get_shader_parameter(&"tint_amount") as float).is_equal(0.5)

	ShaderValues.show(material, &"tint_amount", 0.25)
	assert_float(material.get_shader_parameter(&"tint_amount") as float).is_equal(0.25)


# A colour and a vector with the same numbers aren't the same value to a shader's uniform.
func test_show_replaces_a_value_of_another_type() -> void:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"color", Vector3(1.0, 0.5, 0.25))

	ShaderValues.show(material, &"color", Color(1.0, 0.5, 0.25))

	assert_that(material.get_shader_parameter(&"color")).is_equal(Color(1.0, 0.5, 0.25))
