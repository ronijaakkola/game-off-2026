class_name BusIndicator
extends Control
## A teardrop badge at the screen's edge that points at the bus while no part of it is on
## screen: a disc in the bus's yellow with the bus on it, drawn out to a point toward the
## bus, in the quick text's make ([BusQuickText]). It sits on the line from the middle of
## the screen to the bus, its point [constant EDGE_GAP] inside the edge, or
## [constant PANEL_GAP] off a HUD panel in the way, and keeps its size at any zoom. Out of
## fuel or cooling down after overheating, it turns the loss's red and shows why. It hides
## while a side panel is open, on the zoomed map and through a jump.

## The disc's radius and how far its point reaches from its centre, in pixels.
const RADIUS := 14.0
const TIP := 25.0
const ICON_SIZE := 16.0
## Pixels between the point and the screen's edge, and between it and a panel in the way.
const EDGE_GAP := 12.0
const PANEL_GAP := 8.0
## Pixels the disc keeps from a panel it passes beside on its way to the edge.
const PASS_GAP := 4.0
const OUTLINE_PIXELS := 2.0
## How many straight pieces the disc's arc is drawn in.
const ARC_STEPS := 24
const INK := Color(0.106, 0.09, 0.251)
const FADE_IN_SECONDS := 0.15
const FADE_OUT_SECONDS := 0.1
## The size it grows from as it fades in.
const GROW_FROM := 0.8
## After the camera and the bus have moved each frame, as the map's other labels.
const PROCESS_PRIORITY := 302
const BUS_ICON := preload("res://shared/icons/bus.svg")
const FUEL_ICON := preload("res://shared/icons/fuel.svg")
const HEAT_ICON := preload("res://game/bus/icons/thermometer.svg")

## The camera the bus is seen through.
@export var camera: Camera3D
@export var bus: FrameshiftBus
## The side panels: while one shows, the camera follows what is open, so it hides.
@export var panels: Array[SidePanel] = []
## The HUD's panels along the screen's edges, which it stops short of.
@export var avoid: Array[Control] = []
## On the zoomed map the camera stays by the bus, so it hides.
@export var map_zoom: MapZoom
## Through a jump the bus leaves the screen on purpose, so it hides.
@export var system_jump: SystemJump

## How big the badge draws, about its centre. The fade in animates it.
var badge_scale := 1.0:
	set(value):
		badge_scale = value
		queue_redraw()

var _shown := false
# From the middle of the screen toward the bus, on screen.
var _direction := Vector2.RIGHT
var _fade: Tween


func _ready() -> void:
	process_priority = PROCESS_PRIORITY
	modulate.a = 0.0


func _process(_delta: float) -> void:
	if not camera or not bus:
		return
	var wanted := _is_wanted()
	if wanted != _shown:
		_shown = wanted
		_play()
	# While it fades out it stays where it was.
	if _shown:
		_place()


func _draw() -> void:
	if not bus:
		return
	var out_of_fuel := bus.get_fuel_tank().is_empty()
	var trouble := out_of_fuel or bus.temperature.is_cooling()
	var fill := BusQuickText.COLORS[BusQuickText.Kind.LOSS if trouble else BusQuickText.Kind.REMARK]
	var icon: Texture2D = BUS_ICON
	if out_of_fuel:
		icon = FUEL_ICON
	elif trouble:
		icon = HEAT_ICON
	# The disc's arc, from one side of the point round to the other, then the point.
	var half := acos(RADIUS / TIP)
	var toward := _direction.angle()
	var outline := PackedVector2Array()
	for i: int in ARC_STEPS + 1:
		var angle := toward + lerpf(half, TAU - half, float(i) / ARC_STEPS)
		outline.append(Vector2.from_angle(angle) * RADIUS)
	outline.append(_direction * TIP)
	var closed := outline.duplicate()
	closed.append(outline[0])
	var scale_by := Vector2.ONE * badge_scale
	draw_set_transform(BusQuickText.SHADOW_OFFSET, 0.0, scale_by)
	draw_colored_polygon(outline, BusQuickText.SHADOW_COLOR)
	draw_polyline(closed, BusQuickText.SHADOW_COLOR, OUTLINE_PIXELS, true)
	draw_set_transform(Vector2.ZERO, 0.0, scale_by)
	draw_colored_polygon(outline, fill)
	draw_polyline(closed, BusQuickText.OUTLINE_COLOR, OUTLINE_PIXELS, true)
	draw_texture_rect(
		icon, Rect2(Vector2.ONE * -ICON_SIZE * 0.5, Vector2.ONE * ICON_SIZE), false, INK
	)


# Whether no part of the bus is on screen, and nothing hides the indicator.
func _is_wanted() -> bool:
	if panels.any(func(panel: SidePanel) -> bool: return panel.visible):
		return false
	if (map_zoom and map_zoom.is_zoomed()) or (system_jump and system_jump.is_jumping()):
		return false
	var at := bus.get_model().global_position
	if camera.is_position_behind(at):
		return true
	var middle := camera.unproject_position(at)
	var top := camera.unproject_position(at + camera.global_basis.y * FrameshiftBus.RADIUS)
	return not get_viewport_rect().grow(middle.distance_to(top)).has_point(middle)


# Puts the badge on the line from the middle of the screen to the bus, as far out as the
# screen's edge and the panels let it go.
func _place() -> void:
	var view := get_viewport_rect()
	var centre := view.get_center()
	var at := bus.get_model().global_position
	var toward := camera.unproject_position(at) - centre
	if camera.is_position_behind(at):
		toward = -toward
	if toward.is_zero_approx():
		return
	_direction = toward.normalized()
	var reach := _cross(centre, _direction, view.grow(-(EDGE_GAP + TIP))).y
	for control: Control in avoid:
		if not control.is_visible_in_tree():
			continue
		# A panel is in the way only while the disc would touch it on its way out. One
		# the disc clears is passed, so the badge is back at the edge as soon as it fits.
		var covered := _covered(control)
		var passing := _cross(centre, _direction, covered.grow(RADIUS + PASS_GAP))
		if passing.x > passing.y or passing.y <= 0.0:
			continue
		var span := _cross(centre, _direction, covered.grow(PANEL_GAP + TIP))
		if span.x > 0.0:
			reach = minf(reach, span.x)
	position = centre + _direction * reach
	queue_redraw()


# What a panel covers on screen: its own rect and its children's, since the dock panel's
# card hangs from a root of no height.
static func _covered(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	for child: Node in control.get_children():
		var part := child as Control
		if part and part.visible:
			rect = rect.merge(part.get_global_rect())
	return rect


# How far along direction from a point the line enters (x) and leaves (y) a rect. It
# misses the rect when x is more than y.
static func _cross(from: Vector2, direction: Vector2, rect: Rect2) -> Vector2:
	var enter := -INF
	var leave := INF
	for axis: int in 2:
		var low := rect.position[axis] - from[axis]
		var high := rect.end[axis] - from[axis]
		if is_zero_approx(direction[axis]):
			if low > 0.0 or high < 0.0:
				return Vector2(INF, -INF)
			continue
		var a := low / direction[axis]
		var b := high / direction[axis]
		enter = maxf(enter, minf(a, b))
		leave = minf(leave, maxf(a, b))
	return Vector2(enter, leave)


func _play() -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	if not _shown:
		_fade.tween_property(self, ^"modulate:a", 0.0, FADE_OUT_SECONDS)
		return
	_fade.tween_property(self, ^"modulate:a", 1.0, FADE_IN_SECONDS)
	if Settings.reduce_motion:
		badge_scale = 1.0
		return
	badge_scale = GROW_FROM
	(
		_fade
		. parallel()
		. tween_property(self, ^"badge_scale", 1.0, FADE_IN_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
