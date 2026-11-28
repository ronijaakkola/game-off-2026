class_name BusIndicator
extends Control
## A teardrop badge that points at the bus while the player can see no part of it, past
## the screen's edge or wholly under a HUD panel: a disc in the bus's yellow with the bus
## on it, drawn out to a point toward the bus, in the quick text's make ([BusQuickText]).
## It sits on the line from the middle of the screen to the bus, its point
## [constant EDGE_GAP] inside the edge, or [constant PANEL_GAP] off a HUD panel in the way,
## and keeps its size at any zoom. Out of fuel or cooling down after overheating, it turns
## the loss's red and shows why. It hides while a side panel is open, on the zoomed map
## and through a jump.
## While it shows, a right click on its disc glides the camera over the bus and sets no
## course; every other click, the wheel and a drag go through it to the map.

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
## Pixels past the disc's edge a click still counts as on it.
const CLICK_SLACK := 2.0
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
## What a right click on it glides over the bus. Locked, it stays put.
@export var rig: CameraRig

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
	process_priority = FrameOrder.SCREEN_MARKERS
	modulate.a = 0.0


func _process(_delta: float) -> void:
	if not camera or not bus:
		return
	var wanted := _is_wanted()
	if wanted != _shown:
		_shown = wanted
		# PASS, not STOP: what it doesn't take goes on to the map.
		mouse_filter = Control.MOUSE_FILTER_PASS if _shown else Control.MOUSE_FILTER_IGNORE
		_play()
	# While it fades out it stays where it was.
	if _shown:
		_place()


## Whether the badge is up: the player can see no part of the bus and nothing hides it.
func is_showing() -> bool:
	return _shown


# The root has no size: the disc round its origin is what takes clicks.
func _has_point(point: Vector2) -> bool:
	return point.length() <= (RADIUS + CLICK_SLACK) * badge_scale


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if not click or click.button_index != MOUSE_BUTTON_RIGHT:
		return
	accept_event()
	if click.pressed and rig and not rig.locked:
		rig.glide_to(bus)


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


# Whether the player can see no part of the bus, and nothing hides the indicator.
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
	return is_out_of_sight(get_viewport_rect(), middle, middle.distance_to(top), _get_covered())


## Whether the player can see no part of a bus drawn at [param at] on a screen of
## [param view], as a circle of [param radius]: it is past the screen's edge, or wholly
## under one of the panels at [param covered]. A panel over the middle of the screen
## doesn't count, since the badge would have no way to point.
static func is_out_of_sight(view: Rect2, at: Vector2, radius: float, covered: Array[Rect2]) -> bool:
	if not view.grow(radius).has_point(at):
		return true
	# Only the part of it on screen has to be covered: a bus half past the edge under the
	# bus bars, which reach the edge, is as hidden as one wholly under them.
	var bounds := Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0).intersection(view)
	var centre := view.get_center()
	for panel: Rect2 in covered:
		if panel.encloses(bounds) and not panel.grow(PANEL_GAP + TIP).has_point(centre):
			return true
	return false


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
	position = place_on_line(view, _direction, _get_covered())
	queue_redraw()


# What each HUD panel that shows covers on screen.
func _get_covered() -> Array[Rect2]:
	var covered: Array[Rect2] = []
	for control: Control in avoid:
		if control.is_visible_in_tree():
			covered.append(_covered(control))
	return covered


## Where the badge's centre goes on a screen of [param view]: on the line from its middle
## along [param direction], a unit vector, as far out as the edge and the panels at
## [param covered] let it go. Its point stays [constant EDGE_GAP] inside the edge and
## [constant PANEL_GAP] off a panel in the way. A panel is in the way only while the disc
## would touch it on its way out: one the disc clears is passed, so the badge is back at
## the edge as soon as it fits.
static func place_on_line(view: Rect2, direction: Vector2, covered: Array[Rect2]) -> Vector2:
	var centre := view.get_center()
	var reach := _cross(centre, direction, view.grow(-(EDGE_GAP + TIP))).y
	for panel: Rect2 in covered:
		var passing := _cross(centre, direction, panel.grow(RADIUS + PASS_GAP))
		if passing.x > passing.y or passing.y <= 0.0:
			continue
		var span := _cross(centre, direction, panel.grow(PANEL_GAP + TIP))
		if span.x > 0.0:
			reach = minf(reach, span.x)
	return centre + direction * reach


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
