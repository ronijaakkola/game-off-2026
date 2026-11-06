extends GdUnitTestSuite

## The one export that sets the Environment rather than a shader uniform.
const ENVIRONMENT_EXPORTS: Array[String] = ["ambient_color"]

var _reduce_motion: bool


func before_test() -> void:
	_reduce_motion = Settings.reduce_motion


func after_test() -> void:
	# Assigning re-saves the developer's own settings file with their value.
	Settings.reduce_motion = _reduce_motion


# set_shader_parameter() on a name the shader lacks does nothing, without an error, so an
# export whose uniform is misspelt or renamed would change nothing on screen.
func test_every_export_reaches_its_shader_uniform() -> void:
	var sky: SpaceSky = auto_free(SpaceSky.new())
	var material := sky.environment.sky.sky_material as ShaderMaterial
	var uniforms: Array[String] = []
	for uniform: Dictionary in material.shader.get_shader_uniform_list():
		uniforms.append(uniform.name)
	for setting: String in sky.get_export_names():
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


# The parallax layers sit where the shader thinks the camera is. Under Reduce motion that
# stays put however the camera moves, and turning the setting off neither jumps the
# layers nor holds them still any longer.
func test_reduce_motion_holds_the_parallax_layers_still() -> void:
	Settings.reduce_motion = false
	var sky: SpaceSky = auto_free(SpaceSky.new())
	sky.parallax = true
	add_child(sky)
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	camera.make_current()
	await _frames(2)
	var start: Vector3 = _layer_camera(sky)

	camera.position += Vector3(10.0, 0.0, 5.0)
	await _frames(2)
	assert_vector(_layer_camera(sky)).is_equal(start + Vector3(10.0, 0.0, 5.0))

	Settings.reduce_motion = true
	var held: Vector3 = _layer_camera(sky)
	camera.position += Vector3(-30.0, 0.0, 20.0)
	await _frames(2)
	assert_vector(_layer_camera(sky)).is_equal(held)

	Settings.reduce_motion = false
	await _frames(2)
	assert_vector(_layer_camera(sky)).is_equal(held)
	camera.position += Vector3(4.0, 0.0, 0.0)
	await _frames(2)
	assert_vector(_layer_camera(sky)).is_equal(held + Vector3(4.0, 0.0, 0.0))


func _layer_camera(sky: SpaceSky) -> Vector3:
	var material := sky.environment.sky.sky_material as ShaderMaterial
	return material.get_shader_parameter(&"camera_position")


func _frames(count: int) -> void:
	for i: int in count:
		await await_idle_frame()
