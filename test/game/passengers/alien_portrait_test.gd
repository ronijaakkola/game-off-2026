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


func test_the_bust_is_lit_from_the_photo_lamp_not_the_star() -> void:
	# The two-tone shader lights from the star at the origin unless told otherwise, and the
	# portrait studio has no light of its own any more.
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(1)
	var portrait := runner.scene() as AlienPortrait
	var head := portrait.find_children("*Head", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := head.get_surface_override_material(0) as ShaderMaterial
	assert_bool(skin.get_shader_parameter(&"light_is_directional") as bool).is_true()
	assert_vector(skin.get_shader_parameter(&"light_source") as Vector3).is_equal(
		AlienPortrait.LIGHT_DIRECTION
	)


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


func test_a_head_that_is_not_a_mesh_still_gets_food_sized_to_the_mesh_under_it() -> void:
	# A plain node named *Head with a 0.4-wide box under it, as some models may be built.
	var shape := MeshInstance3D.new()
	shape.name = "Shape"
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	shape.mesh = box
	var head := Node3D.new()
	head.name = "TestHead"
	head.add_child(shape)
	var model := Node3D.new()
	model.add_child(head)
	head.owner = model
	shape.owner = model
	var scene := PackedScene.new()
	scene.pack(model)
	model.free()
	var portrait: AlienPortrait = auto_free(preload(SCENE).instantiate())
	portrait.head_model = scene
	add_child(portrait)

	var meal := portrait.find_child("Meal", true, false) as PortraitMeal
	assert_object(meal).is_not_null()
	var snack := meal.find_child("Snack", true, false) as Node3D
	var bar := snack.get_child(0) as MeshInstance3D
	assert_float((bar.mesh as BoxMesh).size.x).is_greater(0.1)


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


func test_the_expression_preview_shows_each_head_in_each_expression_eating_and_drinking() -> void:
	var runner := scene_runner(EXPRESSIONS)
	await runner.simulate_frames(40, 50)

	var angers: Array[float] = []
	var joys: Array[float] = []
	var contents: Array[bool] = []
	var actions: Array[Need.Action] = []
	for node: Node in runner.scene().get_children():
		var photo := node as PassengerPhoto
		if not photo:
			continue
		var portrait := photo.studio.get_portrait(photo.get_photo() as AtlasTexture)
		angers.append(portrait.anger)
		joys.append(portrait.joy)
		contents.append(portrait.content)
		actions.append(portrait.action)
	# Okay, happy, annoyed, furious, joyful, eating and drinking, for each of five heads.
	var row_anger: Array[float] = [0.0, 0.0, 0.5, 1.0, 0.0, 0.0, 0.0]
	var row_joy: Array[float] = [0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0]
	var row_content: Array[bool] = [false, true, false, false, false, false, false]
	var none := Need.Action.NONE
	var row_action: Array[Need.Action] = [
		none, none, none, none, none, Need.Action.EAT, Need.Action.DRINK
	]
	assert_array(angers).is_equal(_rows(row_anger))
	assert_array(joys).is_equal(_rows(row_joy))
	assert_array(contents).is_equal(_rows(row_content))
	assert_array(actions).is_equal(_rows(row_action))


func test_content_they_beam_now_and_then_and_stop_when_not() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(1)
	var portrait := runner.scene() as AlienPortrait
	var eye := portrait.eyes[0].material_override as ShaderMaterial

	portrait.content = true
	var widest := 0.0
	for frame: int in 100:
		await runner.simulate_frames(1, 100)
		widest = maxf(widest, eye.get_shader_parameter(&"joy") as float)
	assert_float(widest).is_equal_approx(1.0, 0.01)

	portrait.content = false
	await runner.simulate_frames(10, 100)
	assert_float(eye.get_shader_parameter(&"joy") as float).is_equal_approx(0.0, 0.01)


func test_a_skin_and_eye_style_set_before_it_is_ready_reach_every_eye() -> void:
	var portrait := (load(SCENE) as PackedScene).instantiate() as AlienPortrait
	var style := load("res://game/passengers/eye_styles/bead.tres") as AlienEyeStyle
	portrait.skin_color = Color(0.95, 0.76, 0.3)
	portrait.eye_style = style
	add_child(auto_free(portrait))

	for eye: MeshInstance3D in portrait.eyes:
		var material := eye.material_override as ShaderMaterial
		assert_that(material.get_shader_parameter(&"lid_color")).is_equal(portrait.skin_color)
		assert_float(material.get_shader_parameter(&"pupil_size") as float).is_equal(
			style.pupil_size
		)


# [param row] once for each head shape, as the expression preview lays them out.
func _rows(row: Array) -> Array:
	var rows := []
	for head: int in AlienLook.HEADS.size():
		rows.append_array(row)
	return rows
