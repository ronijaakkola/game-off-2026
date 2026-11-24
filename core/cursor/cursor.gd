extends Node
## The pointer's image: a faceted two-tone dart, drawn by the system so it never lags.
## It shows [constant Shape.DEFAULT] unless a scene asks for another shape with
## [method show_shape], which it does every frame it wants one: a shape nobody asked for
## again, as when the game pauses or the scene goes, falls back by itself. While the left
## button is down the default dart shrinks toward its tip, for as long as it is held, and
## so does [constant Shape.ADD_STOP]'s while the right button is.
## Controls that ask for a pointing hand get the same image, so no control shows the
## system's.

enum Shape { DEFAULT, PRESSED, ADD_STOP, STEER, DRAG, EDGE_SCROLL, LOCKED, ADD_STOP_PRESSED }

## The images are 32 pixels wide and high: the web shows no larger one at a window edge.
const IMAGES: Dictionary[Shape, Texture2D] = {
	Shape.DEFAULT: preload("res://core/cursor/default.svg"),
	Shape.PRESSED: preload("res://core/cursor/pressed.svg"),
	Shape.ADD_STOP: preload("res://core/cursor/add_stop.svg"),
	Shape.STEER: preload("res://core/cursor/steer.svg"),
	Shape.DRAG: preload("res://core/cursor/drag.svg"),
	Shape.LOCKED: preload("res://core/cursor/locked.svg"),
	Shape.ADD_STOP_PRESSED: preload("res://core/cursor/add_stop_pressed.svg"),
}
## The edge scrolling image for each screen direction, drawn one by one so that the night side
## is the lower half of every one, as on the dart.
const EDGE_SCROLL_IMAGES: Dictionary[Vector2i, Texture2D] = {
	Vector2i(1, 0): preload("res://core/cursor/edge_scroll_right.svg"),
	Vector2i(1, 1): preload("res://core/cursor/edge_scroll_down_right.svg"),
	Vector2i(0, 1): preload("res://core/cursor/edge_scroll_down.svg"),
	Vector2i(-1, 1): preload("res://core/cursor/edge_scroll_down_left.svg"),
	Vector2i(-1, 0): preload("res://core/cursor/edge_scroll_left.svg"),
	Vector2i(-1, -1): preload("res://core/cursor/edge_scroll_up_left.svg"),
	Vector2i(0, -1): preload("res://core/cursor/edge_scroll_up.svg"),
	Vector2i(1, -1): preload("res://core/cursor/edge_scroll_up_right.svg"),
}
## The point of each image that sits on the pointer's position.
const HOTSPOTS: Dictionary[Shape, Vector2] = {
	Shape.DEFAULT: Vector2(9.0, 8.0),
	Shape.PRESSED: Vector2(9.0, 8.0),
	Shape.ADD_STOP: Vector2(9.0, 8.0),
	Shape.STEER: Vector2(16.0, 16.0),
	Shape.DRAG: Vector2(16.0, 16.0),
	Shape.LOCKED: Vector2(9.0, 8.0),
	Shape.ADD_STOP_PRESSED: Vector2(9.0, 8.0),
}
## An edge scrolling image's centre, and how far from it the tip sits, which is its hotspot.
const EDGE_SCROLL_CENTER := Vector2(16.0, 16.0)
const EDGE_SCROLL_REACH := 10.0
## The system cursors the image stands in for.
const SLOTS: Array[Input.CursorShape] = [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]

var _requested := Shape.DEFAULT
var _requested_direction := Vector2i.ZERO
var _requested_frame := -1
# The shape and direction on screen now: x the shape, y and z the direction.
var _shown := Vector3i(-1, 0, 0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var shape := Shape.DEFAULT
	# This runs before the scene asks in a frame, so last frame's request still holds.
	if _requested_frame >= Engine.get_process_frames() - 1:
		shape = _requested
	if shape == Shape.DEFAULT and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		shape = Shape.PRESSED
	if shape == Shape.ADD_STOP and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		shape = Shape.ADD_STOP_PRESSED
	var direction := _requested_direction if shape == Shape.EDGE_SCROLL else Vector2i.ZERO
	if shape == Shape.EDGE_SCROLL and not EDGE_SCROLL_IMAGES.has(direction):
		shape = Shape.DEFAULT
	var shown := Vector3i(shape, direction.x, direction.y)
	if shown == _shown:
		return
	_shown = shown
	_apply(shape, direction)


## Shows [param shape] for this frame; call it every frame the shape should stay.
## [constant Shape.EDGE_SCROLL] points along [param direction] on screen, -1, 0 or 1 on each
## axis.
func show_shape(shape: Shape, direction := Vector2i.ZERO) -> void:
	_requested = shape
	_requested_direction = direction
	_requested_frame = Engine.get_process_frames()


func _apply(shape: Shape, direction: Vector2i) -> void:
	var texture: Texture2D
	var hotspot: Vector2
	if shape == Shape.EDGE_SCROLL:
		texture = EDGE_SCROLL_IMAGES[direction]
		hotspot = EDGE_SCROLL_CENTER + Vector2(direction).normalized() * EDGE_SCROLL_REACH
	else:
		texture = IMAGES[shape]
		hotspot = HOTSPOTS[shape]
	for slot: Input.CursorShape in SLOTS:
		Input.set_custom_mouse_cursor(texture, slot, hotspot)
