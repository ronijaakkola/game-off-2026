class_name AsteroidFieldTooltip
extends Control
## Names the asteroid field under the pointer: once the pointer has rested anywhere over
## [member field]'s band for as long as any tooltip waits, a [Tooltip] saying what it is
## opens above the pointer and follows it, and closes when the pointer leaves the band or
## reaches the HUD. The whole band counts, its gaps and the room between its rocks too, and
## a little past its edges, so the pointer needn't hit a rock. No physics: it asks the belt
## about the spot on the orbit plane the pointer looks at.

const TOOLTIP := preload("res://ui/tooltip/tooltip.tscn")
const TEXT := "Asteroid field"
## How far past the band's edges the pointer still counts as over it, in units.
const SLACK := 0.4
## Pixels between the pointer and the card.
const GAP := 14.0

## The field it names.
@export var field: AsteroidField

var _tooltip: Tooltip
# Where the pointer is, from its own events, so one a test sends counts too.
var _pointer := Vector2.ZERO
# Seconds the pointer has rested over the field.
var _rested := 0.0


func _ready() -> void:
	# A point at the pointer, which the card sits above.
	top_level = true
	size = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip = TOOLTIP.instantiate() as Tooltip
	# Running text, as a research planet's tooltip is, so the two look alike.
	_tooltip.title = ""
	_tooltip.sentence = TEXT
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
	if not _is_over_field(_pointer):
		_rested = 0.0
		_tooltip.close()
		return
	global_position = _pointer
	_rested += delta
	if _rested >= _tooltip.rest_seconds:
		_tooltip.target = self
		_tooltip.open()


func _is_over_field(pointer: Vector2) -> bool:
	var camera := get_viewport().get_camera_3d()
	if not field or not field.is_visible_in_tree() or not camera:
		return false
	if get_viewport().gui_get_hovered_control():
		return false
	var point: Variant = CourseDrag.point_under(camera, pointer)
	if point == null:
		return false
	return field.belt.is_in_band(field.to_local(point as Vector3), -SLACK)
