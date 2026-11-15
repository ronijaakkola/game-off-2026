class_name HappinessCap
extends Control
## The end of a passenger's happiness bar that frustration has taken off the most they can
## reach ([member Passenger.frustration]), hatched over the track: the part they can no
## longer fill. Put it over the bar, filling it. Draws nothing while nothing is lost.

## Seconds it takes to grow or shrink to a new [member lost], so a stop's cost slides in.
const GROW_SECONDS := 0.4
## The hatching's colour and the stripes' spacing and width, in pixels.
const COLOR := Color(0.06, 0.04, 0.12, 0.75)
const STRIPE_COLOR := Color(0.949, 0.302, 0.4, 0.55)
const STRIPE_GAP := 4.0
const STRIPE_WIDTH := 1.5

## How much of the bar is lost, from 0 to 1, from its right end.
var lost := 0.0

# The share drawn now, following [member lost].
var _shown := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var step := delta / GROW_SECONDS
	var next := move_toward(_shown, clampf(lost, 0.0, 1.0), step)
	if not is_equal_approx(next, _shown):
		_shown = next
		queue_redraw()


func _draw() -> void:
	if _shown <= 0.0:
		return
	var width := size.x * _shown
	var rect := Rect2(size.x - width, 0.0, width, size.y)
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR
	box.set_corner_radius_all(roundi(size.y * 0.5))
	draw_style_box(box, rect)
	# Stripes leaning right, each cut to the hatched part.
	var lean := size.y
	var x := rect.position.x - lean
	while x < size.x:
		var from := Vector2(x, size.y)
		var to := Vector2(x + lean, 0.0)
		var start := clampf(inverse_lerp(from.x, to.x, rect.position.x), 0.0, 1.0)
		var end := clampf(inverse_lerp(from.x, to.x, size.x), 0.0, 1.0)
		if end > start:
			draw_line(from.lerp(to, start), from.lerp(to, end), STRIPE_COLOR, STRIPE_WIDTH, true)
		x += STRIPE_GAP
