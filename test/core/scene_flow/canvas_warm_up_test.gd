extends GdUnitTestSuite

const GLASS := preload("res://ui/glass.gdshader")

var _specks: CanvasWarmUp
var _scene: Control


func before_test() -> void:
	_specks = auto_free(CanvasWarmUp.new())
	add_child(_specks)
	_scene = auto_free(Control.new())
	add_child(_scene)


func test_a_hidden_control_s_material_gets_a_speck() -> void:
	var hidden := _add(ColorRect.new(), _material())
	hidden.hide()
	_specks.fill(_scene)
	assert_int(_specks.count()).is_equal(1)
	assert_object((_specks.get_child(0) as CanvasItem).material).is_same(hidden.material)


func test_materials_on_one_shader_share_a_speck() -> void:
	_add(ColorRect.new(), _material())
	_add(ColorRect.new(), _material())
	_specks.fill(_scene)
	assert_int(_specks.count()).is_equal(1)


func test_a_panel_and_a_rectangle_on_one_shader_each_get_a_speck() -> void:
	_add(ColorRect.new(), _material())
	_add(PanelContainer.new(), _material())
	_specks.fill(_scene)
	assert_int(_specks.count()).is_equal(2)
	assert_object(_specks.get_child(0)).is_instanceof(ColorRect)
	assert_object(_specks.get_child(1)).is_instanceof(Panel)


func test_a_control_that_clips_its_children_gets_a_speck_that_clips_one() -> void:
	var mask := _add(Panel.new(), null)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_specks.fill(_scene)
	assert_int(_specks.count()).is_equal(1)
	var speck := _specks.get_child(0) as CanvasItem
	assert_int(speck.clip_children).is_equal(CanvasItem.CLIP_CHILDREN_ONLY)
	assert_int(speck.get_child_count()).is_equal(1)


func test_clear_takes_the_specks_away() -> void:
	_add(ColorRect.new(), _material())
	_specks.fill(_scene)
	_specks.clear()
	await get_tree().process_frame
	assert_int(_specks.count()).is_equal(0)


func _material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GLASS
	return material


func _add(control: Control, material: Material) -> Control:
	control.material = material
	_scene.add_child(control)
	return control
