class_name Hairline
extends Control
## A thin divider, [member width] UI pixels thick, drawn on whole screen pixels: a vertical
## one across the middle of its rect, or with [member horizontal], a horizontal one. The
## window scales the UI by any factor, so a 1 px ColorRect covers 1.5 screen pixels at
## 1.5× and draws as one sharp pixel or two faint ones depending on where it falls. This
## rounds its thickness to whole screen pixels and its edge onto one, so every divider
## looks the same.

@export var color := Color(1.0, 1.0, 1.0, 0.1216):
	set(value):
		color = value
		queue_redraw()
## How thick it is in UI pixels, before rounding to screen pixels.
@export_range(0.5, 8.0, 0.5) var width := 1.0:
	set(value):
		width = value
		queue_redraw()
## Whether it runs across its rect rather than down it.
@export var horizontal := false:
	set(value):
		horizontal = value
		queue_redraw()


func _ready() -> void:
	set_notify_transform(true)
	get_viewport().size_changed.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


func _draw() -> void:
	var to_screen := get_viewport().get_final_transform() * get_global_transform_with_canvas()
	# Which axis the thickness is on: x for a vertical line, y for a horizontal one.
	var axis := 1 if horizontal else 0
	var scale := to_screen.get_scale()[axis]
	if scale <= 0.0:
		return
	var thickness := maxf(roundf(width * scale), 1.0)
	var middle := to_screen * (size * 0.5)
	var edge := middle
	edge[axis] = floorf(middle[axis] - thickness * 0.5 + 0.5)
	var start := (to_screen.affine_inverse() * edge)[axis]
	var rect := Rect2(start, 0.0, thickness / scale, size.y)
	if horizontal:
		rect = Rect2(0.0, start, size.x, thickness / scale)
	draw_rect(rect, color)
