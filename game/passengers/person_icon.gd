class_name PersonIcon
extends Control
## A passenger as a small flat figure: a head over rounded shoulders, in [member color].
## [method draw_person] draws one on any canvas item, for rows of them such as seats.

## A person, in pixels: head radius, and body width and height.
const HEAD_RADIUS := 2.7
const BODY_SIZE := Vector2(9.0, 7.0)
## The whole figure, in pixels.
const SIZE := Vector2(BODY_SIZE.x, HEAD_RADIUS * 2.0 + BODY_SIZE.y)

var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_person(self, Vector2((size.x - SIZE.x) * 0.5, (size.y - SIZE.y) * 0.5), color)


## Draws a person on [param canvas] with its top left corner at [param at].
static func draw_person(canvas: CanvasItem, at: Vector2, person_color: Color) -> void:
	var middle := at.x + BODY_SIZE.x * 0.5
	canvas.draw_circle(Vector2(middle, at.y + HEAD_RADIUS), HEAD_RADIUS, person_color)
	var shoulders_y := at.y + HEAD_RADIUS * 2.0 + BODY_SIZE.x * 0.5 + 0.5
	var bottom := at.y + SIZE.y
	var body := PackedVector2Array()
	for step: int in 9:
		var angle := PI + PI * step / 8.0
		body.append(Vector2(middle, shoulders_y) + Vector2.from_angle(angle) * BODY_SIZE.x * 0.5)
	body.append(Vector2(at.x + BODY_SIZE.x, bottom))
	body.append(Vector2(at.x, bottom))
	canvas.draw_colored_polygon(body, person_color)
