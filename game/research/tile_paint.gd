class_name TilePaint
extends RefCounted
## Draws a research tile's parts on a canvas item: its rounded square with a gradient, its
## border, its top highlight and its soft shadows. [UpgradeButton] picks which and in what
## colours for its state.

## The tile's corner radius, in pixels.
const RADIUS := 12.0


## A soft shadow or glow as a design tool's blur draws it ([SoftGlow]).
static func shadow(
	canvas: CanvasItem, rect: Rect2, color: Color, blur: float, offset: Vector2
) -> void:
	var reach := Vector2.ONE * SoftGlow.get_reach(blur)
	var area := Rect2(rect.position - reach + offset, rect.size + reach * 2.0)
	canvas.draw_texture_rect(SoftGlow.box(rect.size, RADIUS, blur), area, false, color)


## A rounded square shaded from [param top] to [param bottom], with smoothed edges.
static func body(canvas: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	var points := rounded(rect, RADIUS)
	var colors := PackedColorArray()
	for point: Vector2 in points:
		colors.append(top.lerp(bottom, (point.y - rect.position.y) / rect.size.y))
	canvas.draw_polygon(points, colors)
	var edge := points.duplicate()
	edge.append(points[0])
	var edge_colors := colors.duplicate()
	edge_colors.append(colors[0])
	canvas.draw_polyline_colors(edge, edge_colors, 1.0, true)


static func border(canvas: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var inset := width * 0.5
	var points := rounded(rect.grow(-inset), RADIUS - inset)
	points.append(points[0])
	canvas.draw_polyline(points, color, width, true)


## A 1 px line along the top edge and into its corners, as light falling on the tile.
static func top_highlight(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var points := rounded(rect.grow(-0.5), RADIUS - 0.5)
	var top := PackedVector2Array()
	var colors := PackedColorArray()
	var reach := RADIUS * 0.75
	for point: Vector2 in points:
		if point.y <= rect.position.y + reach:
			top.append(point)
			var fade := 1.0 - (point.y - rect.position.y) / reach
			colors.append(Color(color, fade))
	canvas.draw_polyline_colors(top, colors, 1.0, true)


## The corners of [param rect] rounded by [param radius], clockwise from the top left.
static func rounded(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 6
	var corners := [
		[rect.position + Vector2(radius, radius), PI],
		[Vector2(rect.end.x - radius, rect.position.y + radius), PI * 1.5],
		[rect.end - Vector2(radius, radius), 0.0],
		[Vector2(rect.position.x + radius, rect.end.y - radius), PI * 0.5],
	]
	for corner: Array in corners:
		var center: Vector2 = corner[0]
		var start: float = corner[1]
		for i: int in steps + 1:
			var angle := start + PI * 0.5 * i / steps
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
