@tool
extends EditorScenePostImport
## Import script for a .glb that holds one mesh: makes the MeshInstance3D the scene root.
##
## Godot wraps a lone mesh in a Node3D root. That makes the model an extra level deep, so a
## scene that instances it can't override the mesh's surface material by the instance's own
## name. Set `import_script/path` to this file in the .glb.import to drop the wrapper.
## Editor-only (`tools/` is left out of the exports).


func _post_import(scene: Node) -> Object:
	var mesh_instance := scene.get_child(0) as MeshInstance3D
	if scene.get_child_count() != 1 or mesh_instance == null:
		push_error("single_mesh_import: %s must hold exactly one MeshInstance3D" % scene.name)
		return scene
	scene.remove_child(mesh_instance)
	mesh_instance.owner = null
	scene.free()
	return mesh_instance
