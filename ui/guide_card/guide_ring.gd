class_name GuideRing
extends Node2D
## A white rounded ring round what a guide card points at, so the eye finds it, in the
## language of the trip arc's ring round a destination: a flat white line with a thin
## dark outline. [method show_ring] closes it in from farther out onto the target while
## it fades in, then it sends out a slow pulse that spreads and fades, until
## [method hide_ring]. Under Reduce motion it fades in in place and holds still.
## It draws in the viewport's pixels whatever the card's own position and scale, and
## behind the card, so a pulse passes under it. The card fades it with its own fade.

## Pixels from the target's edge to the ring's inner edge.
const GAP := 3.0
## The ring's line, and the dark outline either side of it, in pixels.
const LINE := 2.0
const OUTLINE := 1.0
## The corners the ring assumes its target has, in pixels: its own run round them from the
## same centres. A target too small for them gets a round ring.
const CORNER := 10.0
const COLOR := Color(1, 1, 1, 1)
const OUTLINE_COLOR := Color(0.078, 0.071, 0.188, 0.7)
## How far out the ring starts as it closes in, and how long that takes, in seconds.
const CLOSE_PIXELS := 14.0
const CLOSE_SECONDS := 0.35
## How far past the ring a pulse spreads before it is gone, in pixels, and how often one
## goes out, in seconds.
const PULSE_PIXELS := 18.0
const PULSE_SECONDS := 1.6

## What the ring goes round, in the viewport's pixels. Its owner updates it as the target
## moves.
var target_rect := Rect2()

var _showing := false
# 0 hidden, 1 in: the fade, which the close in follows.
var _alpha := 0.0
# Seconds since it started closing in.
var _time := 0.0
var _line := StyleBoxFlat.new()
var _edge := StyleBoxFlat.new()


func _ready() -> void:
	show_behind_parent = true
	for box: StyleBoxFlat in [_line, _edge]:
		box.draw_center = false
		box.anti_aliasing = true
	_line.set_border_width_all(int(LINE))
	_edge.set_border_width_all(int(LINE + OUTLINE * 2.0))
	set_process(false)


## Closes the ring in on [member target_rect] and starts its pulse. The ring showing
## already carries on.
func show_ring() -> void:
	if not _showing:
		_showing = true
		_time = 0.0
	show()
	set_process(true)


## Fades the ring out.
func hide_ring() -> void:
	_showing = false


func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, 1.0 if _showing else 0.0, delta / CLOSE_SECONDS)
	_time += delta
	if _alpha <= 0.0:
		hide()
		set_process(false)
	queue_redraw()


func _draw() -> void:
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	if Settings.reduce_motion:
		_draw_ring(0.0, _alpha)
		return
	var closed := _ease_out(_time / CLOSE_SECONDS)
	_draw_ring((1.0 - closed) * CLOSE_PIXELS, _alpha * closed)
	if closed >= 1.0:
		var pulse := fmod((_time - CLOSE_SECONDS) / PULSE_SECONDS, 1.0)
		var fade := 1.0 - pulse
		_draw_ring(pulse * PULSE_PIXELS, _alpha * fade * fade * 0.8)


# The ring with its outline, [param out] pixels farther from the target than it rests.
func _draw_ring(out: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var reach := GAP + LINE + OUTLINE * 2.0 + out
	var outer := target_rect.grow(reach)
	var radius := minf(CORNER + reach, minf(outer.size.x, outer.size.y) * 0.5)
	_set_radius(_edge, radius)
	_set_radius(_line, radius - OUTLINE)
	# A StyleBox's colours go into the drawing as it is drawn, so each ring can have its own.
	_edge.border_color = Color(OUTLINE_COLOR, OUTLINE_COLOR.a * alpha)
	draw_style_box(_edge, outer)
	_line.border_color = Color(COLOR, COLOR.a * alpha)
	draw_style_box(_line, outer.grow(-OUTLINE))


static func _set_radius(box: StyleBoxFlat, radius: float) -> void:
	box.set_corner_radius_all(int(roundf(radius)))
	box.corner_detail = 12


static func _ease_out(t: float) -> float:
	var left := 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - left * left * left
