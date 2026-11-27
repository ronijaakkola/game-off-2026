extends GdUnitTestSuite

const GLASS := preload("res://ui/glass.gdshader")
## A node that keeps its materials in variables until it has something to draw with them,
## as the bus's route line does.
const KEEPER := """extends Node3D
var kept := StandardMaterial3D.new()
var several: Array[Material] = [StandardMaterial3D.new(), null]
var freed := Node.new()


func _init() -> void:
	freed.free()
"""

var _stand_ins: MaterialWarmUp
var _scene: Node3D


func before_test() -> void:
	_stand_ins = auto_free(MaterialWarmUp.new())
	add_child(_stand_ins)
	_scene = auto_free(Node3D.new())
	add_child(_scene)


func test_an_empty_mesh_s_material_gets_a_stand_in() -> void:
	var line := MeshInstance3D.new()
	line.mesh = ImmediateMesh.new()
	line.material_override = StandardMaterial3D.new()
	_scene.add_child(line)

	var stand_ins := _stand_ins.fill(_scene, {})

	assert_int(stand_ins.size()).is_equal(1)
	assert_object(stand_ins[0].material_override).is_same(line.material_override)
	assert_int(stand_ins[0].mesh.get_surface_count()).is_greater(0)


func test_materials_a_script_keeps_in_its_variables_get_stand_ins() -> void:
	# One of its variables holds an object freed since, which is no material to show.
	var keeper := _keeper()

	var stand_ins := _stand_ins.fill(_scene, {})

	var shown: Array[Material] = []
	for stand_in: MeshInstance3D in stand_ins:
		shown.append(stand_in.material_override)
	var several: Array = keeper.get("several")
	assert_array(shown).contains_exactly_in_any_order([keeper.get("kept"), several[0]])


func test_a_material_already_drawn_gets_no_stand_in() -> void:
	var keeper := _keeper()
	var several: Array = keeper.get("several")
	var drawn := {keeper.get("kept"): true, several[0]: true}

	assert_array(_stand_ins.fill(_scene, drawn)).is_empty()


func test_materials_on_one_shader_share_a_stand_in() -> void:
	var shader := Shader.new()
	shader.code = "shader_type spatial;"
	for i: int in 2:
		var mesh := MeshInstance3D.new()
		mesh.material_override = _shader_material(shader)
		_scene.add_child(mesh)

	assert_int(_stand_ins.fill(_scene, {}).size()).is_equal(1)


func test_a_material_drawn_after_another_gets_its_stand_in() -> void:
	# The second pass compiles with the first, so a new one needs the draw too.
	var shader := Shader.new()
	shader.code = "shader_type spatial;"
	var body := StandardMaterial3D.new()
	body.next_pass = _shader_material(shader)
	var mesh := MeshInstance3D.new()
	mesh.material_override = body
	_scene.add_child(mesh)

	var stand_ins := _stand_ins.fill(_scene, {body: true})

	assert_int(stand_ins.size()).is_equal(1)
	assert_object(stand_ins[0].material_override).is_same(body)


func test_a_2d_material_gets_no_stand_in() -> void:
	var mesh := MeshInstance3D.new()
	mesh.material_override = _shader_material(GLASS)
	_scene.add_child(mesh)

	assert_array(_stand_ins.fill(_scene, {})).is_empty()


func test_clear_takes_the_stand_ins_away() -> void:
	_keeper()
	_stand_ins.fill(_scene, {})
	_stand_ins.clear()
	await get_tree().process_frame
	assert_int(_stand_ins.get_child_count()).is_equal(0)


func _keeper() -> Node3D:
	var script := GDScript.new()
	script.source_code = KEEPER
	script.reload()
	var keeper := Node3D.new()
	keeper.set_script(script)
	_scene.add_child(keeper)
	return keeper


func _shader_material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
