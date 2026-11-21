class_name MeshBounds
## The box round a set of meshes, measured in another node's space, as a portrait measures
## its head to frame it and to place what goes on it.


## The box round every one of [param meshes], in the space [param to_space] takes global
## positions into, or an empty box with none.
static func around(meshes: Array[MeshInstance3D], to_space: Transform3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in meshes:
		var local := to_space * mesh.global_transform * mesh.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	return bounds
