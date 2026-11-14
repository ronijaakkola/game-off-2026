class_name RoundedFill
## The fill of a button held down or charged to fill: the button's own rounded shape, cut
## off by a straight edge at how full it is, so it fills the button and never pokes out past
## its corners. A rounded box only as wide as the fill would, since a box narrower than its
## corners squares them off to its full height. Its edges are feathered, as a
## [StyleBoxFlat]'s are.

## How many straight pieces make up each corner's curve.
const CORNER_STEPS := 8
## The width of the soft edge, in pixels.
const FEATHER := 1.0


## Draws [param fraction] of [param rect] on [param item], from the left, as a box with
## corners of [param radius] cut off by a straight edge, in [param color].
static func draw(
	item: CanvasItem, rect: Rect2, radius: float, fraction: float, color: Color
) -> void:
	var points := outline(rect, radius, fraction)
	if points.size() < 3:
		return
	if _turn(points) < 0.0:
		points.reverse()
	var count := points.size()
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	for i: int in count:
		var to_prev := (points[i] - points[(i + count - 1) % count]).normalized()
		var to_next := (points[(i + 1) % count] - points[i]).normalized()
		# Outward normals of the two edges, for a polygon running clockwise on screen.
		var normal_a := Vector2(to_prev.y, -to_prev.x)
		var normal_b := Vector2(to_next.y, -to_next.x)
		var miter := (normal_a + normal_b) / maxf(1.0 + normal_a.dot(normal_b), 0.1)
		inner.append(points[i] - miter * FEATHER * 0.5)
		outer.append(points[i] + miter * FEATHER * 0.5)
	# One mesh: a fan from the middle fills the shape, which stays convex, and a ring
	# round it fades out to the soft edge.
	var clear := Color(color, 0.0)
	var middle := Vector2.ZERO
	for point: Vector2 in points:
		middle += point / count
	var vertices := PackedVector2Array([middle])
	var colors := PackedColorArray([color])
	var indices := PackedInt32Array()
	for i: int in count:
		vertices.append_array([inner[i], outer[i]])
		colors.append_array([color, clear])
		var here := 1 + i * 2
		var next := 1 + (i + 1) % count * 2
		indices.append_array([0, here, next, here, here + 1, next, next, here + 1, next + 1])
	RenderingServer.canvas_item_add_triangle_array(
		item.get_canvas_item(), indices, vertices, colors
	)


## The outline of [param fraction] of [param rect], from the left: a box with corners of
## [param radius], cut off by a straight edge. Empty when less than a pixel of it shows.
static func outline(rect: Rect2, radius: float, fraction: float) -> PackedVector2Array:
	var width := rect.size.x * clampf(fraction, 0.0, 1.0)
	if width < FEATHER:
		return PackedVector2Array()
	radius = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var shape := PackedVector2Array()
	# Corner centres and the angle each corner's curve starts at, clockwise on screen.
	var corners: Array[Vector2] = [
		rect.position + Vector2(radius, radius),
		Vector2(rect.end.x - radius, rect.position.y + radius),
		rect.end - Vector2(radius, radius),
		Vector2(rect.position.x + radius, rect.end.y - radius),
	]
	for corner: int in 4:
		var start := PI + corner * PI * 0.5
		for step: int in CORNER_STEPS + 1:
			var angle := start + step * PI * 0.5 / CORNER_STEPS
			shape.append(corners[corner] + Vector2(cos(angle), sin(angle)) * radius)
	var cut := Rect2(rect.position - Vector2(1.0, 1.0), Vector2(width + 1.0, rect.size.y + 2.0))
	var clip := PackedVector2Array(
		[
			cut.position,
			Vector2(cut.end.x, cut.position.y),
			cut.end,
			Vector2(cut.position.x, cut.end.y)
		]
	)
	var pieces := Geometry2D.intersect_polygons(shape, clip)
	if pieces.is_empty():
		return PackedVector2Array()
	# Merges points closer than the soft edge is wide: the clip leaves a sliver of an edge
	# by each end of the cut, and the soft edge's inner side would fold over itself there.
	# Of two such points, the one on the cut stays, so the cut stays straight.
	var cut_x := rect.position.x + width
	var points := PackedVector2Array()
	for point: Vector2 in pieces[0]:
		var last := points.size() - 1
		if last < 0 or points[last].distance_to(point) >= FEATHER:
			points.append(point)
		elif is_equal_approx(point.x, cut_x):
			points[last] = point
	var last := points.size() - 1
	if last > 0 and points[0].distance_to(points[last]) < FEATHER:
		if is_equal_approx(points[last].x, cut_x):
			points[0] = points[last]
		points.remove_at(last)
	return points


# Twice the signed area of [param points], positive when they run clockwise on screen.
static func _turn(points: PackedVector2Array) -> float:
	var total := 0.0
	for i: int in points.size():
		total += points[i].cross(points[(i + 1) % points.size()])
	return total
