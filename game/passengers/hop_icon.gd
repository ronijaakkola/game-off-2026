class_name HopIcon
extends Control
## The hop location as a small flat icon, where a planet's icon would be: a circle of
## short dashes with round ends and no fill, in the aqua of the zone that marks the hop
## location on the map ([FlybyZone]). Keep it square.

const COLOR := Color(0.62, 1.0, 0.93)
## How many dashes go round, and the share of each dash's place that its line takes,
## before its round ends, which add half the line's width at each end.
const DASHES := 5
const DASH_SHARE := 0.3
## The line's width, in pixels.
const WIDTH := 1.5


func _draw() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - WIDTH * 0.5
	var step := TAU / DASHES
	for dash: int in DASHES:
		var from := step * dash
		var to := from + step * DASH_SHARE
		draw_arc(centre, radius, from, to, 6, COLOR, WIDTH, true)
		for end: float in [from, to]:
			draw_circle(
				centre + Vector2.from_angle(end) * radius, WIDTH * 0.5, COLOR, true, -1.0, true
			)
