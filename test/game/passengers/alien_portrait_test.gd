extends GdUnitTestSuite
## A passenger's portrait: an alien head in its race's colour, with eyes that blink.

const SCENE := "res://game/passengers/alien_portrait.tscn"
const PREVIEW := "res://test/previews/alien_portrait_preview.tscn"


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
