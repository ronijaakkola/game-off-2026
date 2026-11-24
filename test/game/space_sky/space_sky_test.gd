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


# The parallax sky reads its fog from a map of the part of the fog layer in view. Past the
# map's edge the fog would smear, so wherever the camera goes, however it turns and
# whatever its lens, the map holds the fog behind every corner of the screen.
func test_the_fog_map_holds_the_fog_behind_every_corner_of_the_screen() -> void:
	Settings.reduce_motion = false
	var sky: SpaceSky = auto_free(SpaceSky.new())
	sky.parallax = true
	add_child(sky)
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	camera.make_current()
	var material := sky.environment.sky.sky_material as ShaderMaterial
	var placements: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(10.0, 25.0, 30.0)),
		Transform3D(Basis.IDENTITY, Vector3(-640.0, 25.0, 380.0)),
		Transform3D(Basis.from_euler(Vector3(-0.6, 0.4, 0.0)), Vector3(40.0, 60.0, 90.0)),
		Transform3D(Basis.from_euler(Vector3(-0.6, 0.4, 0.0)), Vector3(9000.0, 60.0, -7000.0)),
	]
	for fov: float in [30.0, 75.0]:
		camera.fov = fov
		for placement: Transform3D in placements:
			camera.global_transform = placement
			await _frames(2)
			var origin: Vector2 = material.get_shader_parameter(&"fog_map_origin")
			var span: Vector2 = material.get_shader_parameter(&"fog_map_span")
			var held := Rect2(origin, span)
			var screen := camera.get_viewport().get_visible_rect().size
			for corner: Vector2 in [
				Vector2.ZERO, Vector2(screen.x, 0.0), Vector2(0.0, screen.y), screen
			]:
				var point := _fog_point(sky, camera, corner)
				var message := "the fog map %s misses the fog at %s, behind the screen's %s"
				(
					assert_bool(held.has_point(point))
					. override_failure_message(message % [held, point, corner])
					. is_true()
				)


# Where on the fog layer the view through [param screen_point] lands, in the layer's
# units, worked out as the sky shader does (on_layer() and fog_layer_point()).
func _fog_point(sky: SpaceSky, camera: Camera3D, screen_point: Vector2) -> Vector2:
	var direction := camera.project_ray_normal(screen_point)
	var basis := camera.global_basis.orthonormalized()
	var forward := -basis.z
	var depth := sky.parallax_depth * SpaceSky.FOG_DEPTH
	var along := depth - camera.global_position.dot(forward)
	var hit := camera.global_position + direction * (along / direction.dot(forward))
	return Vector2(hit.dot(basis.x), hit.dot(basis.y)) * SpaceSky.FOG_SCALE / depth


func _layer_camera(sky: SpaceSky) -> Vector3:
	var material := sky.environment.sky.sky_material as ShaderMaterial
	return material.get_shader_parameter(&"camera_position")


func _frames(count: int) -> void:
	for i: int in count:
		await await_idle_frame()
