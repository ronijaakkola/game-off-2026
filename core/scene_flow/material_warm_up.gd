class_name MaterialWarmUp
extends Node3D
## Stand-ins for the 3D materials a scene holds but draws nothing with yet, so [SceneFlow]
## can draw them for the first time under its black card as it does the scene's objects.
## A material compiles its shaders when it first draws, which on the web stalls the game for
## a frame or more, and an object with an empty mesh draws nothing: a line built in code once
## there is a route to show, a trail before the first flight, a ring that fills as a drive
## charges. Without a stand-in, each compiles in the middle of play, as it first shows.
## A mesh a script builds ([ImmediateMesh]) counts as empty even while it holds a surface,
## since it can be cleared before the frame that would draw it.
##
## [method fill] adds a small quad for each material that a node of the scene draws with or
## keeps in one of its script's variables, and that nothing has drawn so far. The quads are
## in the main 3D world, so they draw as the scene's objects do, lit and fogged the same.

## A stand-in's side, in metres. It is under the black card either way.
const SIZE := 0.01

# The variables of each script that can hold a material: its objects and its arrays.
var _variables: Dictionary[Script, Array] = {}


## Adds a stand-in for each of [param scene]'s materials that [param drawn] doesn't hold yet,
## and returns them. [param drawn] holds what compiles for each material drawn so far, its
## shader or, for a built-in material, itself; it holds the stand-ins' too from now on.
## Call [method clear] once they have drawn.
func fill(scene: Node, drawn: Dictionary) -> Array[MeshInstance3D]:
	var stand_ins: Array[MeshInstance3D] = []
	var nodes := scene.find_children("*", "", true, false)
	nodes.append(scene)
	for node: Node in nodes:
		for material: Material in _materials_of(node):
			if _is_new(material, drawn):
				stand_ins.append(_add_stand_in(material))
	return stand_ins


## Takes the stand-ins away, and with them their hold on the scene's materials.
func clear() -> void:
	for stand_in: Node in get_children():
		stand_in.queue_free()


## What compiles for [param material]: materials on one shader share its programs.
static func shader_of(material: Material) -> Resource:
	var shader_material := material as ShaderMaterial
	return shader_material.shader if shader_material else material


# Whether [param material], or a pass drawn after it, is one [param drawn] doesn't hold
# yet. It holds them all from now on.
func _is_new(material: Material, drawn: Dictionary) -> bool:
	var new := false
	while material:
		var key := shader_of(material)
		if not drawn.has(key):
			drawn[key] = true
			new = true
		material = material.next_pass
	return new


# The 3D materials [param node] draws with, and those its script keeps in a variable.
func _materials_of(node: Node) -> Array[Material]:
	var found: Array[Variant] = []
	var geometry := node as GeometryInstance3D
	if geometry:
		found.append(geometry.material_override)
		found.append(geometry.material_overlay)
	var mesh_instance := node as MeshInstance3D
	if mesh_instance:
		for surface: int in mesh_instance.get_surface_override_material_count():
			found.append(mesh_instance.get_active_material(surface))
	var script := node.get_script() as Script
	if script:
		for variable: StringName in _variables_of(script):
			var value: Variant = node.get(variable)
			if value is Array:
				found.append_array(value as Array)
			else:
				found.append(value)
	var materials: Array[Material] = []
	for value: Variant in found:
		# A variable can hold an object that has been freed since.
		if is_instance_valid(value) and _is_spatial(value as Material):
			materials.append(value as Material)
	return materials


# Whether [param material] is one a 3D object draws with: not a 2D one, a sky's or a
# particle system's, which compile for what draws those. Null isn't.
func _is_spatial(material: Material) -> bool:
	var shader_material := material as ShaderMaterial
	if shader_material:
		var shader := shader_material.shader
		return shader != null and shader.get_mode() == Shader.MODE_SPATIAL
	return material is BaseMaterial3D


func _variables_of(script: Script) -> Array:
	if not _variables.has(script):
		var names: Array[StringName] = []
		for property: Dictionary in script.get_script_property_list():
			var type: int = property["type"]
			if type == TYPE_OBJECT or type == TYPE_ARRAY:
				names.append(StringName(str(property["name"])))
		_variables[script] = names
	return _variables[script]


func _add_stand_in(material: Material) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(SIZE, SIZE)
	var stand_in := MeshInstance3D.new()
	stand_in.mesh = quad
	stand_in.material_override = material
	stand_in.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stand_in)
	return stand_in
