class_name WaitingPips
extends Control
## A row of small dots under a planet's name, one for each place in its line: filled for
## someone waiting, a faint ring for a free place. A dot that fills grows out of its ring
## while fading in; one that empties shrinks back into it. Under Reduce motion they only
## fade.

## The filled dot's colour, the names' off-white lilac.
const COLOR := Color(0.957, 0.945, 1.0, 1.0)
## The free place's ring.
const EMPTY_COLOR := Color(0.957, 0.945, 1.0, 0.4)
## A dot's width and the gap between dots, in pixels.
const DIAMETER := 5.0
const GAP := 3.0
## Seconds for a dot to fill or empty, and the share of its size it grows from.
const FILL_SECONDS := 0.25
const FILL_FROM := 0.4

## How many wait.
var count := 0:
	set(value):
		if count == value:
			return
		count = value
		_fill_to(value)
## How many places the line has.
var places := 3:
	set(value):
		places = value
		update_minimum_size()
		queue_redraw()

# How many dots are filled as drawn, a fraction while one fills or empties.
var _filled := 0.0
var _fill: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	return Vector2(places * DIAMETER + maxi(places - 1, 0) * GAP, DIAMETER)


func _draw() -> void:
	var radius := DIAMETER * 0.5
	for i: int in places:
		var center := Vector2(radius + i * (DIAMETER + GAP), radius)
		var fill := clampf(_filled - i, 0.0, 1.0)
		if fill < 1.0:
			draw_arc(center, radius - 0.5, 0.0, TAU, 16, EMPTY_COLOR, 1.0, true)
		if fill > 0.0:
			var grow := 1.0 if Settings.reduce_motion else lerpf(FILL_FROM, 1.0, fill)
			var color := Color(COLOR, COLOR.a * fill)
			draw_circle(center, radius * grow, color, true, -1.0, true)


# Fills or empties the dots up to [param target], from where they are. Not yet in the
# tree, as when first set, they start there.
func _fill_to(target: int) -> void:
	if _fill:
		_fill.kill()
	if not is_inside_tree():
		_set_filled(target)
		return
	_fill = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_fill.tween_method(_set_filled, _filled, float(target), FILL_SECONDS)


func _set_filled(value: float) -> void:
	_filled = value
	queue_redraw()
