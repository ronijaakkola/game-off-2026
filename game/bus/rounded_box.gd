class_name RoundedBox
## Builds box meshes with rounded edges and corners, for placeholder models made in code.


## A box of [param size], centred on the origin, with edges rounded to [param radius].
## [param steps] is how many faces each rounded edge has across its first half.
static func make(size: Vector3, radius: float, steps := 3) -> ArrayMesh:
	var half := size * 0.5
	radius = minf(radius, minf(half.x, minf(half.y, half.z)))
	var inner := half - Vector3.ONE * radius
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for axis: int in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var us := _coordinates(half[u], radius, steps)
		var vs := _coordinates(half[v], radius, steps)
		for side: float in [-1.0, 1.0]:
			var outward := Vector3.ZERO
			outward[axis] = side
			for i: int in us.size() - 1:
				for j: int in vs.size() - 1:
					var quad: Array[Vector3] = []
					for corner: Vector2i in [
						Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)
					]:
						var point := Vector3.ZERO
						point[axis] = side * half[axis]
						point[u] = us[i + corner.x]
						point[v] = vs[j + corner.y]
						quad.append(point)
					_add_triangle(
						vertices, normals, inner, radius, outward, quad[0], quad[1], quad[2]
					)
					_add_triangle(
						vertices, normals, inner, radius, outward, quad[0], quad[2], quad[3]
					)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# Grid lines along one axis of a face: denser where the face bends round an edge, spaced so
# each step turns the surface by the same angle.
static func _coordinates(half: float, radius: float, steps: int) -> PackedFloat32Array:
	var flat := half - radius
	var bends := PackedFloat32Array()
	for i: int in range(1, steps + 1):
		bends.append(flat + radius * tan(PI * 0.25 * i / steps))
	var result := PackedFloat32Array()
	for i: int in range(bends.size() - 1, -1, -1):
		result.append(-bends[i])
	result.append_array([-flat, flat])
	result.append_array(bends)
	return result


# Pulls each point of the box onto the rounded surface: the nearest point of the inner box,
# pushed out by the radius.
static func _add_triangle(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	inner: Vector3,
	radius: float,
	outward: Vector3,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> void:
	var points: Array[Vector3] = [a, b, c]
	var rounded: Array[Vector3] = []
	var rounded_normals: Array[Vector3] = []
	for point: Vector3 in points:
		var core := point.clamp(-inner, inner)
		var normal := (point - core).normalized()
		rounded.append(core + normal * radius)
		rounded_normals.append(normal)
	# Godot draws clockwise triangles as front faces.
	if (rounded[1] - rounded[0]).cross(rounded[2] - rounded[0]).dot(outward) > 0.0:
		rounded.reverse()
		rounded_normals.reverse()
	vertices.append_array(rounded)
	normals.append_array(rounded_normals)
