class_name WarpGateTooltip
extends Control
## Names the warp gate under the pointer: once the pointer has rested on a [WarpGate]'s ring
## for as long as any tooltip waits, a [Tooltip] saying what it is opens above the pointer
## and follows it, and closes when the pointer leaves the ring or reaches the HUD. No
## physics: the ring counts as round on screen, as a planet does ([ScreenPick]).

const TOOLTIP := preload("res://ui/tooltip/tooltip.tscn")
const TEXT := "Warp drive"
## How far past the ring's frame the pointer still counts as on it, in units.
const SLACK := 0.1
## Pixels between the pointer and the card.
const GAP := 14.0

var _tooltip: Tooltip
# Where the pointer is, from its own events, so one a test sends counts too.
var _pointer := Vector2.ZERO
# Seconds the pointer has rested on a gate.
var _rested := 0.0


func _ready() -> void:
	# A point at the pointer, which the card sits above.
	top_level = true
	size = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip = TOOLTIP.instantiate() as Tooltip
	# Running text, as the asteroid field's tooltip is, so the two look alike.
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
	if not _is_over_gate(_pointer):
		_rested = 0.0
		_tooltip.close()
		return
	global_position = _pointer
	_rested += delta
	if _rested >= _tooltip.rest_seconds:
		_tooltip.target = self
		_tooltip.open()


func _is_over_gate(pointer: Vector2) -> bool:
	var camera := get_viewport().get_camera_3d()
	if not camera or get_viewport().gui_get_hovered_control():
		return false
	var radius := WarpGate.RING_RADIUS + WarpGate.FRAME + SLACK
	for gate: WarpGate in get_tree().get_nodes_in_group(WarpGate.GROUP):
		if (
			gate.is_visible_in_tree()
			and ScreenPick.covers(camera, gate.global_position, radius, pointer)
		):
			return true
	return false
