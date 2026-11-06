extends GdUnitTestSuite

## The one export that sets the Environment rather than a shader uniform.
const ENVIRONMENT_EXPORTS: Array[String] = ["ambient_color"]


# set_shader_parameter() on a name the shader lacks does nothing, without an error, so an
# export whose uniform is misspelt or renamed would change nothing on screen.
func test_every_export_reaches_its_shader_uniform() -> void:
	var sky: SpaceSky = auto_free(SpaceSky.new())
	var material := sky.environment.sky.sky_material as ShaderMaterial
	var uniforms: Array[String] = []
	for uniform: Dictionary in material.shader.get_shader_uniform_list():
		uniforms.append(uniform.name)
	for setting: String in _exports(sky):
		if setting in ENVIRONMENT_EXPORTS:
			continue
		var message := "SpaceSky.%s names no uniform in space_sky.gdshader" % setting
		assert_array(uniforms).override_failure_message(message).contains([setting])
		assert_that(material.get_shader_parameter(setting)).is_equal(sky.get(setting))


func test_fade_to_outside_the_tree_sets_the_fog_at_once() -> void:
	var sky: SpaceSky = auto_free(SpaceSky.new())
	sky.fade_to(Color.RED, Color.BLUE, 2.0)
	var material := sky.environment.sky.sky_material as ShaderMaterial
	assert_that(material.get_shader_parameter(&"fog_color")).is_equal(Color.RED)
	assert_that(material.get_shader_parameter(&"fog_accent_color")).is_equal(Color.BLUE)


func _exports(sky: SpaceSky) -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in (sky.get_script() as Script).get_script_property_list():
		var usage: int = property.usage
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
			names.append(property.name)
	return names
