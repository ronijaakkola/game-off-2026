class_name TilePaint
extends RefCounted
## Draws a research tile's parts on a canvas item: its flat rounded square, its border and
## its step chip.
## [UpgradeButton] picks which and in what colours for its state.

## The tile's corner radius, in pixels.
const RADIUS := 12.0
## A step chip's height, and its width round each numeral letter.
const CHIP_HEIGHT := 14.0
const CHIP_PADDING := 13.0
const CHIP_LETTER := 5.0
## The chip's numeral size, and its capitals' height as a share of it.
const CHIP_FONT_SIZE := 11
const CAP_HEIGHT := 0.7


## A rounded square in [param color], with smoothed edges.
static func body(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var points := rounded(rect, RADIUS)
	canvas.draw_colored_polygon(points, color)
	points.append(points[0])
	canvas.draw_polyline(points, color, 1.0, true)


static func border(canvas: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var inset := width * 0.5
	var points := rounded(rect.grow(-inset), RADIUS - inset)
	points.append(points[0])
	canvas.draw_polyline(points, color, width, true)


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


## The chip holding an upgrade's step, [param text], a Roman numeral, in [param font]: a
## pill centred on [param center] in [param colors]' &"fill", with a border in &"border"
## and the numeral in &"ink". Godot has no cap height, and a label centres its line box,
## room for descenders and all, which sets capitals low; this centres the capitals by
## CAP_HEIGHT.
static func chip(
	canvas: CanvasItem,
	center: Vector2,
	text: String,
	font: Font,
	colors: Dictionary[StringName, Color],
) -> void:
	var width := CHIP_PADDING + CHIP_LETTER * text.length()
	var rect := Rect2(center - Vector2(width, CHIP_HEIGHT) * 0.5, Vector2(width, CHIP_HEIGHT))
	var points := rounded(rect, CHIP_HEIGHT * 0.5)
	canvas.draw_colored_polygon(points, colors[&"fill"])
	points.append(points[0])
	canvas.draw_polyline(points, colors[&"border"], 1.5, true)
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT_SIZE).x
	var baseline := center + Vector2(-text_width * 0.5, CHIP_FONT_SIZE * CAP_HEIGHT * 0.5)
	canvas.draw_string(
		font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT_SIZE, colors[&"ink"]
	)
