class_name PhotoShine
extends Control
## The shine on a VIP's photo ([Vip]): a pale band that leans right and sweeps across it
## every [constant PERIOD] seconds, cut off at the photo's edges. Under Reduce motion it
## holds still, a third of the way across.

## Seconds from one sweep starting to the next, and how long a sweep takes.
const PERIOD := 2.8
const SWEEP_SECONDS := 0.7
## The band's width and how far its top leans right of its bottom, as shares of the
## photo's width.
const WIDTH := 0.22
const LEAN := 0.5
const COLOR := Color(1.0, 0.97, 0.82, 0.4)
## Where the band rests under Reduce motion, from 0 at the left to 1 at the right.
const STILL_AT := 0.33

var _seconds := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if Settings.reduce_motion:
		return
	_seconds = fmod(_seconds + delta, PERIOD)
	queue_redraw()


func _draw() -> void:
	var along := STILL_AT if Settings.reduce_motion else _seconds / SWEEP_SECONDS
	if along > 1.0:
		return
	var lean := size.x * LEAN
	var band := size.x * WIDTH
	# From wholly off the left edge to wholly off the right one.
	var left := lerpf(-band - lean, size.x, along)
	var points := PackedVector2Array(
		[
			Vector2(left + lean, 0.0),
			Vector2(left + lean + band, 0.0),
			Vector2(left + band, size.y),
			Vector2(left, size.y),
		]
	)
	draw_colored_polygon(points, COLOR)
