class_name ResearchIcon
extends Control
## A research point as a small flat hexagon token in [member color], filling the control's
## height.

var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var radius := size.y * 0.5
	var points := PackedVector2Array()
	for i: int in 6:
		points.append(size * 0.5 + Vector2.from_angle(PI / 6.0 + TAU * i / 6.0) * radius)
	draw_colored_polygon(points, color)
