class_name WorldTooltip
extends Control
## Names a thing in the world under the pointer: once the pointer has rested on it for as
## long as any tooltip waits, a [Tooltip] in running text saying what it is opens above the
## pointer and follows it, and closes when the pointer leaves it or reaches the HUD. A
## script that extends it says what it names ([method _get_text]) and where that is on
## screen ([method _is_over]).

const TOOLTIP := preload("res://ui/tooltip/tooltip.tscn")
## Pixels between the pointer and the card.
const GAP := 14.0

var _tooltip: Tooltip
# Where the pointer is, from its own events, so one a test sends counts too.
var _pointer := Vector2.ZERO
# Seconds the pointer has rested on what it names.
var _rested := 0.0


func _ready() -> void:
	# A point at the pointer, which the card sits above.
	top_level = true
	size = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip = TOOLTIP.instantiate() as Tooltip
	# Running text with no name over it, as a research planet's tooltip is.
	_tooltip.title = ""
	_tooltip.sentence = _get_text()
	_tooltip.side = Tooltip.Side.ABOVE
	_tooltip.gap = GAP
	# It follows the pointer, and whole pixels would step behind it.
	_tooltip.snap_to_pixels = false
	add_child(_tooltip)
	_pointer = get_viewport().get_mouse_position()


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer = (event as InputEventMouse).position


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera or get_viewport().gui_get_hovered_control() or not _is_over(camera, _pointer):
		_rested = 0.0
		_tooltip.close()
		return
	global_position = _pointer
	_rested += delta
	if _rested >= _tooltip.rest_seconds:
		_tooltip.target = self
		_tooltip.open()


## What the card says.
func _get_text() -> String:
	return ""


## Whether what it names is under the pointer at [param _pointer_at], seen through
## [param _camera].
func _is_over(_camera: Camera3D, _pointer_at: Vector2) -> bool:
	return false
