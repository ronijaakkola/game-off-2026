class_name RemoveBadge
extends Control
## A small round X on the corner of a stop's icon in the route strip, which takes the stop
## off the route when clicked. Dark with a white X, red while the pointer is over it.

## A left click on it.
signal pressed

const SIZE := 12.0
const FILL_COLOR := Color(0.08, 0.07, 0.18, 0.92)
const HOVER_COLOR := Color(0.949, 0.302, 0.4, 1.0)
const RIM_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const MARK_COLOR := Color(1.0, 1.0, 1.0, 1.0)
## Half the length of each stroke of the X, in pixels.
const MARK := 2.5

var _over := false


func _ready() -> void:
	size = Vector2.ONE * SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_over.bind(true))
	mouse_exited.connect(_set_over.bind(false))


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func _draw() -> void:
	var middle := size * 0.5
	var radius := SIZE * 0.5
	draw_circle(middle, radius, HOVER_COLOR if _over else FILL_COLOR, true, -1.0, true)
	draw_circle(middle, radius - 0.5, RIM_COLOR, false, 1.0, true)
	var reach := Vector2.ONE * MARK
	draw_line(middle - reach, middle + reach, MARK_COLOR, 1.5, true)
	draw_line(middle + Vector2(MARK, -MARK), middle + Vector2(-MARK, MARK), MARK_COLOR, 1.5, true)


func _set_over(over: bool) -> void:
	_over = over
	queue_redraw()
