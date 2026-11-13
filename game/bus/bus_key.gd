class_name BusKey
extends Button
## A physical key in the bus bar: a cap that sits proud in a dark well and sinks while it is
## pressed. Disabled, the cap is dim. It draws itself; the button's own text and styles stay
## empty. The small keys are blank caps for now; [FrameshiftKey] adds a label and an outline.
## Pressing it down clicks.

# The well around the cap, and how far the cap sits above its sunk place.
const WELL_PAD := 3.0
const RAISE := 3.0
const CAP_HEIGHT := 35.0
const WELL_COLOR := Color(0.043, 0.035, 0.125)
const SIDE_COLOR := Color(0.133, 0.118, 0.239)
const FACE_COLOR := Color(0.227, 0.208, 0.361)
const FACE_RAISED_COLOR := Color(0.271, 0.247, 0.431)
const EDGE_COLOR := Color(1.0, 1.0, 1.0, 0.3)
const CLICK := preload("res://ui/audio/key_click.ogg")

var _face := StyleBoxFlat.new()
# The cap's lit top edge: the face drawn a pixel higher in a lighter colour, under it.
var _edge := StyleBoxFlat.new()
var _side := StyleBoxFlat.new()
var _well := StyleBoxFlat.new()


func _ready() -> void:
	# Never takes keyboard focus, so a click doesn't leave Space or Enter pressing it.
	focus_mode = FOCUS_NONE
	# The cap sinks, so the button itself doesn't dip.
	add_to_group(ButtonFeel.OWN_PRESS)
	_well.bg_color = WELL_COLOR
	_well.set_corner_radius_all(12)
	_side.set_corner_radius_all(8)
	_face.set_corner_radius_all(8)
	_edge.set_corner_radius_all(8)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_down.connect(Audio.play_sfx.bind(CLICK))
	button_up.connect(queue_redraw)


func _draw() -> void:
	_draw_cap()


# Draws the well and the cap, and returns the cap's face.
func _draw_cap() -> Rect2:
	var down := _is_down()
	var width := size.x - WELL_PAD * 2.0
	_well.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	_side.bg_color = _side_color()
	_side.draw(get_canvas_item(), Rect2(WELL_PAD, WELL_PAD + RAISE, width, CAP_HEIGHT))
	var face := Rect2(WELL_PAD, WELL_PAD + (RAISE if down else 0.0), width, CAP_HEIGHT)
	_face.bg_color = _face_color(down)
	_edge.bg_color = _face.bg_color.blend(EDGE_COLOR)
	_edge.draw(get_canvas_item(), face)
	_face.draw(
		get_canvas_item(), Rect2(face.position + Vector2(0.0, 1.0), face.size - Vector2(0.0, 1.0))
	)
	return face


func _is_down() -> bool:
	return is_pressed()


func _side_color() -> Color:
	return SIDE_COLOR


func _face_color(down: bool) -> Color:
	return FACE_COLOR if disabled or down else FACE_RAISED_COLOR
