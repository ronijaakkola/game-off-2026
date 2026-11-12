class_name PhotoBadge
extends CenterContainer
## A badge on a [PassengerPhoto]: a dark disc with a faint light rim, as big as the badge,
## with an icon in its middle. The disc is drawn as one circle, since a rounded panel shows
## marks where its corners meet. The photo sets it up with [method show_icon].

const FILL_COLOR := Color(0.106, 0.09, 0.251)
const RIM_COLOR := Color(0.957, 0.945, 1.0, 0.4)
## The rim's width, in pixels, inside the disc's edge.
const RIM_WIDTH := 1.0


## Shows [param texture] in a badge [param side] pixels across, with [param pad] pixels
## between its rim and the icon on each side.
func show_icon(texture: Texture2D, side: float, pad: float) -> void:
	custom_minimum_size = Vector2.ONE * side
	var icon := %Icon as TextureRect
	icon.custom_minimum_size = Vector2.ONE * (side - 2.0 * pad)
	icon.texture = texture


## The icon it shows.
func get_icon() -> Texture2D:
	return (%Icon as TextureRect).texture


func _draw() -> void:
	var radius := size.x * 0.5
	draw_circle(size * 0.5, radius, FILL_COLOR, true, -1.0, true)
	draw_circle(size * 0.5, radius - RIM_WIDTH * 0.5, RIM_COLOR, false, RIM_WIDTH, true)
