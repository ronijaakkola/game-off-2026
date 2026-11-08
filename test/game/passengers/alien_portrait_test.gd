extends GdUnitTestSuite
## A passenger's portrait: an alien head in its race's colour, with eyes that blink.

const SCENE := "res://game/passengers/alien_portrait.tscn"
const PREVIEW := "res://test/previews/alien_portrait_preview.tscn"
const EXPRESSIONS := "res://test/previews/portrait_expression_preview.tscn"


func test_the_preview_shows_each_head_with_its_eyes_in_each_race_colour() -> void:
	var runner := scene_runner(PREVIEW)
	await runner.simulate_frames(2)

	var portraits := runner.find_child("Portraits").get_children()
	assert_int(portraits.size()).is_equal(30)
	# A row per eye style and race, each with the Dome, Blob, Stalks, Bean and Hammer.
	var eye_counts: Array[int] = []
	for node: Node in portraits:
		var portrait := node as AlienPortrait
		eye_counts.append(portrait.eyes.size())
		var head := (
			portrait.find_children("*Head", "MeshInstance3D", true, false)[0] as MeshInstance3D
		)
		var skin := head.get_surface_override_material(0) as ShaderMaterial
		assert_that(skin.get_shader_parameter(&"color")).is_equal(portrait.skin_color)
	var row: Array[int] = [2, 1, 2, 2, 2]
	assert_array(eye_counts).is_equal(row + row + row + row + row + row)


func test_a_blink_shuts_the_eyes_and_opens_them_again() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(1)
	var portrait := runner.scene() as AlienPortrait
	var eye := portrait.eyes[0].material_override as ShaderMaterial

	portrait.blink()
	var least_open := 1.0
	for frame: int in 20:
		await runner.simulate_frames(1, 20)
		least_open = minf(least_open, eye.get_shader_parameter(&"open") as float)
	assert_float(least_open).is_less(0.5)
	assert_float(eye.get_shader_parameter(&"open") as float).is_equal_approx(1.0, 0.01)


func test_asleep_the_eyes_shut_and_waking_opens_them() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(1)
	var portrait := runner.scene() as AlienPortrait
	var eye := portrait.eyes[0].material_override as ShaderMaterial

	portrait.asleep = true
	await runner.simulate_frames(40, 50)
	assert_float(eye.get_shader_parameter(&"open") as float).is_equal_approx(0.0, 0.01)
	portrait.asleep = false
	# It may blink just after waking, so the widest they get.
	var widest := 0.0
	for frame: int in 20:
		await runner.simulate_frames(1, 50)
		widest = maxf(widest, eye.get_shader_parameter(&"open") as float)
	assert_float(widest).is_greater(0.9)


func test_a_push_leans_the_head_and_it_sways_back_when_the_push_stops() -> void:
	var reduce_motion := Settings.reduce_motion
	Settings.reduce_motion = false
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(1)
	var portrait := runner.scene() as AlienPortrait
	var model := portrait.get_child(0) as Node3D

	# Braking: pushed forward, toward the camera.
	portrait.felt_acceleration = Vector2(0.0, 2.0)
	await runner.simulate_frames(30, 20)
	var held := model.rotation.x
	assert_float(held).is_greater(0.02)
	portrait.felt_acceleration = Vector2.ZERO
	var least := held
	for frame: int in 20:
		await runner.simulate_frames(1, 20)
		least = minf(least, model.rotation.x)
	Settings.reduce_motion = reduce_motion
	# It swings back past upright before it settles.
	assert_float(least).is_less(0.0)


func test_a_model_with_no_head_or_material_still_builds_framed_whole_and_reports_it() -> void:
	# One box with no material, and no part named *Head.
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = BoxMesh.new()
	var model := Node3D.new()
	model.add_child(body)
	body.owner = model
	var scene := PackedScene.new()
	scene.pack(model)
	model.free()
	var portrait: AlienPortrait = auto_free(preload(SCENE).instantiate())
	portrait.head_model = scene

	(
		assert_error(func() -> void: add_child(portrait))
		. is_push_error(
			"%s has no part named *Head: it won't sway, and is framed whole" % scene.resource_path
		)
	)
	var bounds := portrait.get_head_bounds()
	assert_vector(bounds.size).is_equal_approx(Vector3.ONE, Vector3.ONE * 0.001)


func test_angry_the_lids_slant_toward_the_middle_and_the_skin_flushes() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(1)
	var portrait := runner.scene() as AlienPortrait
	var left := portrait.eyes[0].material_override as ShaderMaterial
	var right := portrait.eyes[1].material_override as ShaderMaterial

	portrait.anger = 1.0
	await runner.simulate_frames(30, 50)

	assert_float(left.get_shader_parameter(&"anger") as float).is_equal_approx(1.0, 0.01)
	# Each eye's lid slants down toward the face's middle, so the two slant opposite ways.
	var sides := [
		left.get_shader_parameter(&"inner_side") as float,
		right.get_shader_parameter(&"inner_side") as float,
	]
	sides.sort()
	assert_array(sides).is_equal([-1.0, 1.0])
	var lid := left.get_shader_parameter(&"lid_color") as Color
	assert_float(lid.r).is_greater(portrait.skin_color.r)


func test_the_expression_preview_shows_each_head_calm_annoyed_furious_and_joyful() -> void:
	var runner := scene_runner(EXPRESSIONS)
	await runner.simulate_frames(40, 50)

	var angers: Array[float] = []
	var joys: Array[float] = []
	for node: Node in runner.scene().get_children():
		var photo := node as PassengerPhoto
		if not photo:
			continue
		var portrait := photo.studio.get_portrait(photo.get_photo() as AtlasTexture)
		angers.append(portrait.anger)
		joys.append(portrait.joy)
	var row_anger: Array[float] = [0.0, 0.5, 1.0, 0.0]
	var row_joy: Array[float] = [0.0, 0.0, 0.0, 1.0]
	assert_array(angers).is_equal(row_anger + row_anger + row_anger + row_anger + row_anger)
	assert_array(joys).is_equal(row_joy + row_joy + row_joy + row_joy + row_joy)
