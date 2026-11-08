class_name StarIcon
extends Control
## A flat five-pointed star in [member color], filling the control's height.

## The inner points' distance from the middle, as a share of the outer points'.
const INNER_RATIO := 0.45

var color := Color(1.0, 0.82, 0.3):
	set(value):
		color = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5
	# A star's points reach higher than its lower points reach down, so it sits a little
	# low to look centred.
	var middle := size * 0.5 + Vector2(0.0, radius * 0.1)
	var points := PackedVector2Array()
	for i: int in 10:
		var reach := radius if i % 2 == 0 else radius * INNER_RATIO
		points.append(middle + Vector2.from_angle(-PI * 0.5 + PI * i / 5.0) * reach)
	draw_colored_polygon(points, color)
