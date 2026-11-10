class_name TrendChevrons
extends Control
## A row of [member count] chevrons, each as tall as the control, pointing right while
## [member rising] and left otherwise, in [member color]: how fast something is heading
## which way, as on a passenger's happiness bar. Draws nothing at a count of 0. Its
## [method get_width] is how wide the row is, for whoever places it.

const CHEVRON := preload("res://game/passengers/icons/chevron_right.svg")
## How far each chevron starts from the one before, as a share of its own width: 1 leaves
## the gap the stroke's round caps leave, so each one reads at a few pixels tall.
const STEP_RATIO := 1.0

## How many chevrons it draws.
var count := 0:
	set(value):
		count = value
		queue_redraw()
## Whether they point right. Off, they point left.
var rising := true:
	set(value):
		rising = value
		queue_redraw()
var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## How wide the row of [param chevrons] chevrons is at the control's height: [member count]
## by default.
func get_width(chevrons := -1) -> float:
	var n := count if chevrons < 0 else chevrons
	if n <= 0:
		return 0.0
	var one := _chevron_width()
	return one + one * STEP_RATIO * (n - 1)


func _draw() -> void:
	if count <= 0:
		return
	var one := Vector2(_chevron_width(), size.y)
	var step := one.x * STEP_RATIO
	if not rising:
		# Mirrored about the row's middle, so a falling row fills the same box.
		draw_set_transform(Vector2(get_width(), 0.0), 0.0, Vector2(-1.0, 1.0))
	for i: int in count:
		draw_texture_rect(CHEVRON, Rect2(Vector2(step * i, 0.0), one), false, color)


func _chevron_width() -> float:
	var texture := CHEVRON.get_size()
	return size.y * texture.x / texture.y
