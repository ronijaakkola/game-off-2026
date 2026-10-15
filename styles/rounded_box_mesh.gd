class_name RoundedBoxMesh
extends PrimitiveMesh
## A box with rounded edges and corners. Godot has no built-in one.
##
## The surface is a box whose corners and edges are pulled onto a sphere of
## [member radius] around the inner box, so normals are smooth across the whole
## surface and the faces stay flat in the middle.

## The outer size of the box.
@export var size := Vector3.ONE:
	set(value):
		size = value.max(Vector3.ONE * 0.001)
		request_update()

## How round the edges are. Clamped to half the smallest side.
@export_range(0.001, 10.0, 0.001, "or_greater") var radius := 0.1:
	set(value):
		radius = maxf(value, 0.001)
		request_update()

## Rows of vertices along each rounded edge. More is smoother.
@export_range(1, 32) var segments := 8:
	set(value):
		segments = maxi(value, 1)
		request_update()


func _create_mesh_array() -> Array:
	var half := size * 0.5
	var round_radius := minf(radius, minf(half.x, minf(half.y, half.z)))
	var inner := half - Vector3.ONE * round_radius
	var coords: Array[PackedFloat32Array] = [
		_axis_coords(inner.x, round_radius),
		_axis_coords(inner.y, round_radius),
		_axis_coords(inner.z, round_radius),
	]

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for axis in 3:
		var u_axis := (axis + 1) % 3
		var v_axis := (axis + 2) % 3
		for sign_value: float in [-1.0, 1.0]:
			var base := vertices.size()
			var us := coords[u_axis]
			var vs := coords[v_axis]
			for v_index in vs.size():
				for u_index in us.size():
					var on_box := Vector3.ZERO
					on_box[axis] = sign_value * half[axis]
					on_box[u_axis] = us[u_index]
					on_box[v_axis] = vs[v_index]
					var anchor := on_box.clamp(-inner, inner)
					var normal := (on_box - anchor).normalized()
					vertices.append(anchor + normal * round_radius)
					normals.append(normal)
					uvs.append(Vector2(u_index / float(us.size() - 1), v_index / float(vs.size() - 1)))
			var columns := us.size()
			for v_index in vs.size() - 1:
				for u_index in columns - 1:
					var a := base + v_index * columns + u_index
					var b := a + 1
					var c := a + columns
					var d := c + 1
					_append_triangle(indices, vertices, normals, a, b, d)
					_append_triangle(indices, vertices, normals, a, d, c)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


## Vertex positions along one side of a face, in order from -half to +half. The flat
## middle is a single span; each rounded end is spaced by angle, so the curve is even.
func _axis_coords(inner_extent: float, round_radius: float) -> PackedFloat32Array:
	var coords := PackedFloat32Array()
	for step in range(segments, -1, -1):
		coords.append(-inner_extent - round_radius * tan(step * PI / 4.0 / segments))
	for step in segments + 1:
		coords.append(inner_extent + round_radius * tan(step * PI / 4.0 / segments))
	return coords


## Adds a triangle wound the way Godot expects (clockwise seen from the front), judged
## against the vertex normals so no face-by-face winding table is needed.
func _append_triangle(
	indices: PackedInt32Array,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	a: int,
	b: int,
	c: int,
) -> void:
	var facing := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
	var average := normals[a] + normals[b] + normals[c]
	if facing.dot(average) > 0.0:
		indices.append_array([a, c, b])
	else:
		indices.append_array([a, b, c])
