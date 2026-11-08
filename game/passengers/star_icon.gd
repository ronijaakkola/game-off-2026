class_name StarIcon
extends Control
## A row of [member count] flat five-pointed stars, each as tall as the control, of which
## the first [member filled] are in [member color] and the rest in
## [member empty_color]. One filled star by default.

## The inner points' distance from the middle, as a share of the outer points'.
const INNER_RATIO := 0.45
## The gap between stars, as a share of a star's height.
const GAP_RATIO := 0.15

## How many stars it draws, and how many of them are filled.
var count := 1:
	set(value):
		count = value
		queue_redraw()
var filled := 1:
	set(value):
		filled = value
		queue_redraw()
var color := Color(1.0, 0.82, 0.3):
	set(value):
		color = value
		queue_redraw()
var empty_color := Color(1.0, 1.0, 1.0, 0.2):
	set(value):
		empty_color = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var step := size.y * (1.0 + GAP_RATIO)
	for i: int in count:
		var middle := Vector2(size.y * 0.5 + step * i, size.y * 0.5)
		draw_star(self, middle, size.y * 0.5, color if i < filled else empty_color)


## The width of [param stars] stars [param height] tall, gaps included.
static func width_for(stars: int, height: float) -> float:
	return height * stars + height * GAP_RATIO * maxi(stars - 1, 0)


## Draws a star on [param canvas] centred on [param middle], its points [param radius] out.
static func draw_star(
	canvas: CanvasItem, middle: Vector2, radius: float, star_color: Color
) -> void:
	# A star's points reach higher than its lower points reach down, so it sits a little
	# low to look centred.
	var centre := middle + Vector2(0.0, radius * 0.1)
	var points := PackedVector2Array()
	for i: int in 10:
		var reach := radius if i % 2 == 0 else radius * INNER_RATIO
		points.append(centre + Vector2.from_angle(-PI * 0.5 + PI * i / 5.0) * reach)
	canvas.draw_colored_polygon(points, star_color)
