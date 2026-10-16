class_name CreaseLines
extends RefCounted
## Builds ink-line geometry for the sharp-lines style: one thin ribbon along every crease
## and open edge of a mesh. The ribbons are real triangles, so MSAA smooths them, which
## it can't do for lines found in a post pass. Pair it with crease_lines.gdshader.

## Corners between two faces sharper than this (radians) get a line. Smooth meshes
## (a sphere, a rounded box) stay below it and get none.
const DEFAULT_MIN_ANGLE := 0.6


## Endpoints of every crease or open edge of [param mesh]'s first surface, two
## consecutive entries per edge.
static func find_creases(mesh: Mesh, min_angle := DEFAULT_MIN_ANGLE) -> PackedVector3Array:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices.resize(vertices.size())
		for i in vertices.size():
			indices[i] = i

	# Edge key -> {from, to, normals}. Vertices are matched by position, not index,
	# because faces with their own normals don't share vertices.
	var edges := { }
	for i in range(0, indices.size(), 3):
		var corners: Array[Vector3] = [
			vertices[indices[i]],
			vertices[indices[i + 1]],
			vertices[indices[i + 2]],
		]
		var normal := (corners[1] - corners[0]).cross(corners[2] - corners[0])
		if normal.length_squared() < 1e-12:
			continue
		normal = normal.normalized()
		for side in 3:
			var from := corners[side]
			var to := corners[(side + 1) % 3]
			var key := _edge_key(from, to)
			if not edges.has(key):
				edges[key] = { "from": from, "to": to, "normals": [] }
			edges[key]["normals"].append(normal)

	var ends := PackedVector3Array()
	for edge: Dictionary in edges.values():
		if _is_crease(edge["normals"], min_angle):
			ends.append(edge["from"])
			ends.append(edge["to"])
	return ends


## A mesh of screen-space ribbons for the edges [param ends] describes. Each edge is a quad
## of four vertices. Every vertex holds one endpoint in VERTEX, the other in CUSTOM0, and
## which side of the line it sits on in UV.x (-1 or 1); the shader turns that into a
## ribbon of constant pixel width.
static func build_ribbons(ends: PackedVector3Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var others := PackedFloat32Array()
	var sides := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in range(0, ends.size(), 2):
		var base := vertices.size()
		for corner in 4:
			var own := ends[i + corner / 2]
			var other := ends[i + 1 - corner / 2]
			vertices.append(own)
			others.append_array([other.x, other.y, other.z, 0.0])
			sides.append(Vector2(-1.0 if corner % 2 == 0 else 1.0, 0.0))
		indices.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])

	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = sides
	arrays[Mesh.ARRAY_CUSTOM0] = others
	arrays[Mesh.ARRAY_INDEX] = indices
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], { }, flags)
	return mesh


static func _edge_key(a: Vector3, b: Vector3) -> String:
	var ka := _vertex_key(a)
	var kb := _vertex_key(b)
	return ka + "|" + kb if ka < kb else kb + "|" + ka


static func _vertex_key(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x * 10000.0), roundi(v.y * 10000.0), roundi(v.z * 10000.0)]


static func _is_crease(normals: Array, min_angle: float) -> bool:
	if normals.size() < 2:
		return true
	for i in normals.size():
		for j in range(i + 1, normals.size()):
			var a: Vector3 = normals[i]
			if a.angle_to(normals[j]) > min_angle:
				return true
	return false
