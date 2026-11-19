class_name HappinessCap
extends Control
## The track of a passenger's happiness bar, and on its end what frustration has taken off
## the most they can reach ([member Passenger.frustration]): that end is fainter and
## striped grey, the part they can no longer fill. The stripes run right up to the fill,
## round its rounded end too. Happiness still above what they can reach shows there faded,
## under the stripes, until it has drained. Put it behind the bar's fill, filling the bar,
## and keep the fill within [method get_reach]. The pointer on the striped end opens a
## tooltip to its right that says why it is there.

## Seconds it takes to grow or shrink to a new [member lost], so a stop's cost slides in.
const GROW_SECONDS := 0.4
## The track's colour up to what they can reach, and past it.
const TRACK_COLOR := Color(1.0, 1.0, 1.0, 0.1412)
const LOST_COLOR := Color(1.0, 1.0, 1.0, 0.08)
## The stripes' colour, and how far apart they start and how wide each is along the bar,
## in pixels.
const STRIPE_COLOR := Color(1.0, 1.0, 1.0, 0.28)
const STRIPE_GAP := 5.0
const STRIPE_WIDTH := 2.0
## How strong the fill's colour is past what they can reach.
const OVER_ALPHA := 0.35
const TOOLTIP := preload("res://ui/tooltip/tooltip.tscn")
const TOOLTIP_TEXT := "This passenger is getting frustrated which limits their happiness."
## How far past the bar's top and bottom the striped end takes the pointer, in pixels: the
## bar alone is too thin to rest on.
const HOVER_MARGIN := 3.0
## How many lines round the lost end's corners off, for cutting the stripes to it.
const CORNER_STEPS := 6

## How much of the bar is lost, from 0 to 1, from its right end.
var lost := 0.0
## Their happiness, from 0 to 1, and the fill's colour, for the part past their reach.
## Both change the picture only once the fill is at the lost end.
var happiness := 0.0:
	set(value):
		var near := _shown > 0.0 and maxf(value, happiness) > _get_edge()
		if near and not is_equal_approx(value, happiness):
			queue_redraw()
		happiness = value
var color := Color.WHITE:
	set(value):
		if value != color and happiness > get_reach():
			queue_redraw()
		color = value

# The share drawn now, following [member lost].
var _shown := 0.0
# The striped end as the pointer finds it, which the tooltip belongs to.
var _hover := Control.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	# It passes the pointer on, so the card under it still knows it is there.
	_hover.mouse_filter = Control.MOUSE_FILTER_PASS
	_hover.hide()
	add_child(_hover)
	var tooltip := TOOLTIP.instantiate() as Tooltip
	tooltip.target = _hover
	tooltip.sentence = TOOLTIP_TEXT
	tooltip.side = Tooltip.Side.RIGHT
	add_child(tooltip)


func _process(delta: float) -> void:
	var step := delta / GROW_SECONDS
	var next := move_toward(_shown, clampf(lost, 0.0, 1.0), step)
	if not is_equal_approx(next, _shown):
		_shown = next
		queue_redraw()


## The most of the bar the fill may cover now, from 0 to 1.
func get_reach() -> float:
	return 1.0 - _shown


# The happiness, from 0 to 1, at which the fill's rounded end first touches the lost end.
func _get_edge() -> float:
	return get_reach() - size.y * 0.5 / maxf(size.x, 1.0)


func _draw() -> void:
	var radius := size.y * 0.5
	_hover.visible = _shown > 0.0
	_hover.position = Vector2(size.x * get_reach(), -HOVER_MARGIN)
	_hover.size = Vector2(size.x * _shown, size.y + HOVER_MARGIN * 2.0)
	if _shown <= 0.0:
		_draw_box(Rect2(Vector2.ZERO, size), TRACK_COLOR, radius, radius)
		return
	var cap := size.x * get_reach()
	var fill_end := minf(size.x * happiness, cap)
	# The lost end starts under the fill's rounded end once the fill is that near.
	var start := cap - clampf(fill_end - (cap - radius), 0.0, radius)
	_draw_box(Rect2(0.0, 0.0, start, size.y), TRACK_COLOR, radius, 0.0)
	var end := Rect2(start, 0.0, size.x - start, size.y)
	_draw_box(end, LOST_COLOR, 0.0, radius)
	var over := size.x * minf(happiness, 1.0) - start
	if over > 0.0 and happiness > get_reach():
		_draw_box(Rect2(start, 0.0, over, size.y), Color(color, OVER_ALPHA), 0.0, radius)
	# Stripes leaning right, counted from the bar's start so they hold still as the end
	# grows. Each is a slanted box cut to the end's shape and filled without smoothing, so
	# none sticks out of the bar and the edges stay sharp at any window size.
	var shape := _end_shape(end, minf(radius, end.size.x))
	var x := -size.y
	while x < size.x:
		var stripe := PackedVector2Array(
			[
				Vector2(x, size.y),
				Vector2(x + size.y, 0.0),
				Vector2(x + size.y + STRIPE_WIDTH, 0.0),
				Vector2(x + STRIPE_WIDTH, size.y),
			]
		)
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(stripe, shape):
			if not Geometry2D.triangulate_polygon(piece).is_empty():
				draw_colored_polygon(piece, STRIPE_COLOR)
		x += STRIPE_GAP


func _draw_box(rect: Rect2, box_color: Color, left: float, right: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = box_color
	box.corner_radius_top_left = roundi(left)
	box.corner_radius_bottom_left = roundi(left)
	box.corner_radius_top_right = roundi(right)
	box.corner_radius_bottom_right = roundi(right)
	draw_style_box(box, rect)


# The lost end's outline: straight on the left, rounded by [param radius] on the right.
func _end_shape(rect: Rect2, radius: float) -> PackedVector2Array:
	var shape := PackedVector2Array([rect.position])
	var centers: Array[Vector2] = [
		Vector2(rect.end.x - radius, rect.position.y + radius),
		Vector2(rect.end.x - radius, rect.end.y - radius),
	]
	for corner: int in centers.size():
		for i: int in CORNER_STEPS + 1:
			var angle := -PI * 0.5 + PI * 0.5 * (corner + float(i) / CORNER_STEPS)
			shape.append(centers[corner] + Vector2.from_angle(angle) * radius)
	shape.append(Vector2(rect.position.x, rect.end.y))
	return shape
