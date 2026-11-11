extends CenterContainer
## A badge on a [PassengerPhoto]: a dark disc with a faint light rim, as big as the badge,
## with an icon in its middle. The disc is drawn as one circle, since a rounded panel shows
## marks where its corners meet.

const FILL_COLOR := Color(0.106, 0.09, 0.251)
const RIM_COLOR := Color(0.957, 0.945, 1.0, 0.4)
## The rim's width, in pixels, inside the disc's edge.
const RIM_WIDTH := 1.0


func _draw() -> void:
	var radius := size.x * 0.5
	draw_circle(size * 0.5, radius, FILL_COLOR, true, -1.0, true)
	draw_circle(size * 0.5, radius - RIM_WIDTH * 0.5, RIM_COLOR, false, RIM_WIDTH, true)
