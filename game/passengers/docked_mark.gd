class_name DockedMark
extends Control
## A small dark disc with a pause icon at the end of a passenger's happiness bar, where the
## trend chevrons sit in flight: while the bus is docked their happiness holds. The card
## tells it whether to show every frame ([method follow]); it fades in and out and rides
## the end of the bar's fill, never past the bar's ends. The pointer on it opens a tooltip
## saying nobody loses happiness while docked.

const TOOLTIP := preload("res://ui/tooltip/tooltip.tscn")
const PAUSE := preload("res://shared/icons/pause.svg")
const TOOLTIP_TITLE := "Docked"
const TOOLTIP_TEXT := "Passengers lose no happiness while the bus is docked."
const FILL_COLOR := Color(0.106, 0.09, 0.251)
const RIM_COLOR := Color(0.957, 0.945, 1.0)
## The disc's size, its rim's width and the icon's size, in pixels.
const SIDE := 14.0
const RIM_WIDTH := 1.0
const ICON_SIZE := 8.0
## Seconds it takes to fade in or out.
const FADE_SECONDS := 0.2

var _alpha := 0.0


func _ready() -> void:
	# It takes the pointer for its tooltip and passes it on, so the card still sees it.
	mouse_filter = Control.MOUSE_FILTER_PASS
	size = Vector2.ONE * SIDE
	var tooltip := TOOLTIP.instantiate() as Tooltip
	tooltip.target = self
	tooltip.title = TOOLTIP_TITLE
	tooltip.sentence = TOOLTIP_TEXT
	tooltip.side = Tooltip.Side.RIGHT
	add_child(tooltip)
	visible = false


## Shows while [param docked], for [param delta] more seconds, at the end of the fill of
## [param bar], the [ProgressBar] it is a child of.
func follow(docked: bool, delta: float, bar: ProgressBar) -> void:
	_alpha = move_toward(_alpha, 1.0 if docked else 0.0, delta / FADE_SECONDS)
	visible = _alpha > 0.0
	modulate.a = _alpha
	var end := bar.size.x * bar.value / bar.max_value
	var x := clampf(end - SIDE * 0.5, 0.0, bar.size.x - SIDE)
	position = Vector2(x, (bar.size.y - SIDE) * 0.5)


func _draw() -> void:
	var middle := size * 0.5
	var radius := SIDE * 0.5
	draw_circle(middle, radius, FILL_COLOR, true, -1.0, true)
	draw_circle(middle, radius - RIM_WIDTH * 0.5, RIM_COLOR, false, RIM_WIDTH, true)
	var corner := middle - Vector2.ONE * ICON_SIZE * 0.5
	draw_texture_rect(PAUSE, Rect2(corner, Vector2.ONE * ICON_SIZE), false, RIM_COLOR)
