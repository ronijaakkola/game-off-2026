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
## keeps in one of its script's variables, and that nothing has drawn so far. A material
## compiles again for each kind of surroundings it draws in (a sky to reflect or none, fog
## or none), so a quad goes in the viewport of the node it stands in for: the main one, or
## a [SubViewport] with a world of its own, such as the one the passengers' portraits are
## taken in. It also compiles once more for an object drawn as many copies, so a material
## that particles or a [MultiMeshInstance3D] hold shows on a stand-in drawn that way: smoke
## that isn't rising yet draws nothing either.

## A stand-in's side, in metres. It is under the black card either way.
const SIZE := 0.01

# The variables of each script that can hold a material: its objects and its arrays.
var _variables: Dictionary[Script, Array] = {}
var _stand_ins: Array[GeometryInstance3D] = []


## Adds a stand-in for each of [param scene]'s materials that [param drawn] doesn't hold yet,
## and returns them. [param drawn] holds a [method key] for each material drawn so far; it
## holds the stand-ins' too from now on. Call [method clear] once they have drawn.
func fill(scene: Node, drawn: Dictionary) -> Array[GeometryInstance3D]:
	var added: Array[GeometryInstance3D] = []
	# Not find_children(): a node made in code is often an internal child, which it skips.
	var nodes: Array[Node] = [scene]
	var next := 0
	while next < nodes.size():
		nodes.append_array(nodes[next].get_children(true))
		next += 1
	for node: Node in nodes:
		var viewport := node.get_viewport()
		var many := draws_many(node)
		for material: Material in _materials_of(node):
			if _is_new(material, viewport, many, drawn):
				added.append(_add_stand_in(material, viewport, many))
	_stand_ins.append_array(added)
	return added


## Takes the stand-ins away, and with them their hold on the scene's materials.
func clear() -> void:
	for stand_in: GeometryInstance3D in _stand_ins:
		if is_instance_valid(stand_in):
			stand_in.queue_free()
	_stand_ins.clear()


## What tells one compiled material from another: what compiles for [param material], its
## shader or, for a built-in material, itself, the [param viewport] it draws in, and whether
## it draws [param many] copies at once ([method draws_many]). Materials on one shader share
## its programs, in one viewport.
static func key(material: Material, viewport: Viewport, many := false) -> Array:
	var shader_material := material as ShaderMaterial
	return [viewport, shader_material.shader if shader_material else material, many]


## Whether [param node] draws its mesh as many copies at once, as particles do.
static func draws_many(node: Node) -> bool:
	return node is CPUParticles3D or node is GPUParticles3D or node is MultiMeshInstance3D


# Whether [param material], or a pass drawn after it, is one [param drawn] doesn't hold
# yet for [param viewport], drawn as [param many] copies or as one. It holds them all from
# now on.
func _is_new(material: Material, viewport: Viewport, many: bool, drawn: Dictionary) -> bool:
	var new := false
	while material:
		var material_key := key(material, viewport, many)
		if not drawn.has(material_key):
			drawn[material_key] = true
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
	for mesh: Mesh in _copied_meshes(node):
		for surface: int in mesh.get_surface_count():
			found.append(mesh.surface_get_material(surface))
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


# The meshes [param node] draws as many copies, when it is one that does.
func _copied_meshes(node: Node) -> Array[Mesh]:
	var meshes: Array[Mesh] = []
	var cpu_particles := node as CPUParticles3D
	if cpu_particles:
		meshes.append(cpu_particles.mesh)
	var gpu_particles := node as GPUParticles3D
	if gpu_particles:
		for draw_pass: int in gpu_particles.draw_passes:
			meshes.append(gpu_particles.get_draw_pass_mesh(draw_pass))
	var multimesh_instance := node as MultiMeshInstance3D
	if multimesh_instance and multimesh_instance.multimesh:
		meshes.append(multimesh_instance.multimesh.mesh)
	return meshes.filter(func(mesh: Mesh) -> bool: return mesh != null)


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


func _add_stand_in(material: Material, viewport: Viewport, many: bool) -> GeometryInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(SIZE, SIZE)
	var stand_in: GeometryInstance3D
	if many:
		var copies := MultiMesh.new()
		copies.transform_format = MultiMesh.TRANSFORM_3D
		copies.mesh = quad
		copies.instance_count = 1
		copies.set_instance_transform(0, Transform3D.IDENTITY)
		var holder := MultiMeshInstance3D.new()
		holder.multimesh = copies
		stand_in = holder
	else:
		var holder := MeshInstance3D.new()
		holder.mesh = quad
		stand_in = holder
	stand_in.material_override = material
	stand_in.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if viewport == get_viewport():
		add_child(stand_in)
	else:
		viewport.add_child(stand_in)
	return stand_in
