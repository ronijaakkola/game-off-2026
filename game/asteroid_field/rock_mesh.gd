class_name RockMesh
## A lumpy, low-poly rock about 1 unit across, made at load so there is nothing to model:
## an icosphere pushed in and out by noise, with a flat normal on every face, so under the
## two-tone light its day side and night side meet along facet edges, like a cut stone.


## A rock shaped by [param shape_seed]. [param detail] is how many times the icosahedron is
## split, 0 for 20 faces and 1 for 80, and [param roughness] how far the noise pushes the
## surface in and out, as a share of its radius.
static func build(shape_seed: int, detail: int, roughness: float) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = shape_seed
	noise.frequency = 0.9
	var points := _icosahedron_points()
	var faces := _icosahedron_faces()
	for i: int in detail:
		faces = _split(points, faces)
	var shaped: Array[Vector3] = []
	for point: Vector3 in points:
		var bump := noise.get_noise_3dv(point * 1.7)
		shaped.append(point * 0.5 * (1.0 + roughness * bump))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: Vector3i in faces:
		var a := shaped[face.x]
		var b := shaped[face.y]
		var c := shaped[face.z]
		# The faces go counter-clockwise seen from outside, and Godot draws a triangle's
		# front where its corners go clockwise, so they go in reversed.
		tool.set_normal((b - a).cross(c - a).normalized())
		tool.add_vertex(a)
		tool.add_vertex(c)
		tool.add_vertex(b)
	return tool.commit()


# The 12 corners of an icosahedron, on the unit sphere.
static func _icosahedron_points() -> Array[Vector3]:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var raw: Array[Vector3] = [
		Vector3(-1, t, 0),
		Vector3(1, t, 0),
		Vector3(-1, -t, 0),
		Vector3(1, -t, 0),
		Vector3(0, -1, t),
		Vector3(0, 1, t),
		Vector3(0, -1, -t),
		Vector3(0, 1, -t),
		Vector3(t, 0, -1),
		Vector3(t, 0, 1),
		Vector3(-t, 0, -1),
		Vector3(-t, 0, 1),
	]
	var points: Array[Vector3] = []
	for point: Vector3 in raw:
		points.append(point.normalized())
	return points


# Its 20 faces, as indices into the corners, counter-clockwise seen from outside.
static func _icosahedron_faces() -> Array[Vector3i]:
	return [
		Vector3i(0, 11, 5),
		Vector3i(0, 5, 1),
		Vector3i(0, 1, 7),
		Vector3i(0, 7, 10),
		Vector3i(0, 10, 11),
		Vector3i(1, 5, 9),
		Vector3i(5, 11, 4),
		Vector3i(11, 10, 2),
		Vector3i(10, 7, 6),
		Vector3i(7, 1, 8),
		Vector3i(3, 9, 4),
		Vector3i(3, 4, 2),
		Vector3i(3, 2, 6),
		Vector3i(3, 6, 8),
		Vector3i(3, 8, 9),
		Vector3i(4, 9, 5),
		Vector3i(2, 4, 11),
		Vector3i(6, 2, 10),
		Vector3i(8, 6, 7),
		Vector3i(9, 8, 1),
	]


# Splits every face into four, adding the midpoint of each edge to [param points] once,
# pushed out onto the unit sphere. An Array, not a packed one, so the points it adds reach
# the caller.
static func _split(points: Array[Vector3], faces: Array[Vector3i]) -> Array[Vector3i]:
	var midpoints: Dictionary[Vector2i, int] = {}
	var split: Array[Vector3i] = []
	for face: Vector3i in faces:
		var ab := _midpoint(points, midpoints, face.x, face.y)
		var bc := _midpoint(points, midpoints, face.y, face.z)
		var ca := _midpoint(points, midpoints, face.z, face.x)
		split.append(Vector3i(face.x, ab, ca))
		split.append(Vector3i(face.y, bc, ab))
		split.append(Vector3i(face.z, ca, bc))
		split.append(Vector3i(ab, bc, ca))
	return split


static func _midpoint(
	points: Array[Vector3], midpoints: Dictionary[Vector2i, int], a: int, b: int
) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if not midpoints.has(key):
		midpoints[key] = points.size()
		points.append(((points[a] + points[b]) * 0.5).normalized())
	return midpoints[key]
