class_name LabBadges
extends Control
## On the upper right of the rim of each planet with a lab ([member Planet.has_lab]), a
## small dark disc with a flask ([PhotoBadge]), so the player sees where to research while
## planning a route. It grows with the zoomed map, slower than the planets do. The pointer
## resting on such a planet opens a tooltip above its badge, or above the planet's
## [PickUpMarker] where one shows, centred on the planet. It places itself after the
## planets and the camera have moved each frame, and hides with the planets the zoomed map
## hides. While [member only] lists planets, as in the tutorial, only theirs show, and
## [method pop_in] brings one in. Once the bus has the Remote terminal, which researches at
## any planet, every badge fades out and stays out, the tooltip with it.

## The disc's size, and the gap between its rim and the flask, in pixels.
const SIZE := 14.0
const PAD := 3.0
## Where on the rim the disc's centre sits: the angle up from the right, and how far
## inside the rim on screen, in pixels, so it straddles the rim at any zoom.
const ANGLE_DEGREES := 40.0
const RIM_INSET_PIXELS := 1.5
## How fast the disc grows as the map zooms in, as a share of how fast the planets do.
const ZOOM_GROWTH := 0.25
## How small a badge starts as it pops in, and the seconds it takes.
const POP_FROM := 0.4
const POP_SECONDS := 0.35
const TOOLTIP_TEXT := "Research planet"
const BADGE := preload("res://game/passengers/photo_badge.tscn")
const TOOLTIP := preload("res://ui/tooltip/tooltip.tscn")
const FLASK := preload("res://shared/icons/flask_conical.svg")

## The camera the planets are seen through.
@export var camera: Camera3D
## The pick-up markers, which the tooltip opens above instead of the badge.
@export var pick_up_markers: PickUpMarkers
## The bus, whose Remote terminal takes the badges away.
@export var bus: FrameshiftBus

## The planets whose badges show, or empty for every planet with a lab.
var only: Array[Planet] = []

## The planet under the pointer. The parent sets it every frame.
var hovered: Planet:
	set(value):
		if hovered == value:
			return
		hovered = value
		_rested = 0.0
		if _tooltip:
			_tooltip.close()

var _badges: Dictionary[Planet, PhotoBadge] = {}
# Made in _ready(), so a scene freed before it enters the tree leaks none.
var _tooltip: Tooltip
# Seconds the pointer has rested on the hovered planet.
var _rested := 0.0
# How much of each badge shows as the Remote terminal takes them away: 1 without it, 0 once
# gone, and its fade out between.
var _retire_shown := 1.0
var _retire: Tween


func _ready() -> void:
	process_priority = FrameOrder.SCREEN_MARKERS
	_tooltip = TOOLTIP.instantiate() as Tooltip
	# Running text, not a name: the planet's name is already under it.
	_tooltip.title = ""
	_tooltip.sentence = TOOLTIP_TEXT
	_tooltip.side = Tooltip.Side.ABOVE
	# It follows the badge as the planet moves: placed after the badge each frame, and not
	# on whole pixels, which would step behind it.
	_tooltip.snap_to_pixels = false
	_tooltip.process_priority = FrameOrder.MARKER_TOOLTIPS
	add_child(_tooltip)
	if bus:
		bus.get_stats().get_traits().changed.connect(_on_trait_changed)
		_on_trait_changed(BusTraits.Type.REMOTE_TERMINAL)


func _process(delta: float) -> void:
	var direction := Vector2.from_angle(-deg_to_rad(ANGLE_DEGREES))
	for planet: Planet in _badges:
		var badge := _badges[planet]
		var center := planet.get_body_global_position()
		badge.visible = (
			camera != null
			and _retire_shown > 0.0
			and modulate.a > 0.0
			and planet.is_visible_in_tree()
			and (only.is_empty() or planet in only)
			and not camera.is_position_behind(center)
		)
		if not badge.visible:
			continue
		if _retire_shown < 1.0:
			badge.modulate.a = minf(badge.modulate.a, _retire_shown)
		var side := roundf(SIZE * (1.0 + (planet.get_world_scale() - 1.0) * ZOOM_GROWTH))
		if badge.size.x != side:
			badge.show_icon(FLASK, side, roundf(PAD * side / SIZE))
			badge.size = Vector2.ONE * side
		var middle := camera.unproject_position(center)
		var top := camera.unproject_position(
			center + camera.global_basis.y * planet.get_body_radius()
		)
		var at := middle + direction * (middle.distance_to(top) - RIM_INSET_PIXELS)
		badge.position = at - badge.size * 0.5
		badge.pivot_offset = badge.size * 0.5
	_show_tooltip(delta)


## The planets to show a badge on, where they have a lab. Replaces any from before.
func set_planets(planets: Array[Planet]) -> void:
	for badge: PhotoBadge in _badges.values():
		badge.queue_free()
	_badges.clear()
	for planet: Planet in planets:
		if planet.has_lab:
			var badge := BADGE.instantiate() as PhotoBadge
			add_child(badge)
			badge.show_icon(FLASK, SIZE, PAD)
			_badges[planet] = badge


## Brings [param planet]'s badge in: it fades in while growing to its size, overshooting a
## little; under Reduce motion it only fades. It returns once it is in.
func pop_in(planet: Planet) -> void:
	var badge: PhotoBadge = _badges.get(planet)
	if not badge:
		return
	badge.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(badge, ^"modulate:a", 1.0, POP_SECONDS)
	if not Settings.reduce_motion:
		badge.scale = Vector2.ONE * POP_FROM
		(
			tween
			. tween_property(badge, ^"scale", Vector2.ONE, POP_SECONDS)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
	await tween.finished


# The Remote terminal came or went: with it, the badges fade out as fast as one pops in,
# then hide; under Reduce motion, or while none shows, they hide at once. Without it they
# show again. The fade is the node's own, not a badge's, so a badge made or popped in later
# stays out too.
func _on_trait_changed(type: BusTraits.Type) -> void:
	if type != BusTraits.Type.REMOTE_TERMINAL:
		return
	var retired := bus.get_stats().get_traits().has(type)
	if _retire:
		_retire.kill()
	_tooltip.close()
	var showing := _badges.values().any(func(badge: PhotoBadge) -> bool: return badge.visible)
	if not retired:
		_retire_shown = 1.0
		for badge: PhotoBadge in _badges.values():
			badge.modulate.a = 1.0
		return
	if Settings.reduce_motion or not showing:
		_retire_shown = 0.0
		return
	_retire = create_tween()
	_retire.tween_property(self, ^"_retire_shown", 0.0, POP_SECONDS)


## [param planet]'s badge, or null, for a guide card to point at.
func get_badge(planet: Planet) -> Control:
	return _badges.get(planet)


## Whether [param planet] shows a badge.
func is_shown(planet: Planet) -> bool:
	var badge: PhotoBadge = _badges.get(planet)
	return badge != null and badge.visible


## Whether the tooltip shows at [param planet]'s badge.
func is_tooltip_shown(planet: Planet) -> bool:
	return planet != null and planet == hovered and _tooltip.visible


# Opens the tooltip at the hovered planet's badge, or its pick-up marker, once the pointer
# has rested on the planet as long as any tooltip waits, and closes it while the badges
# fade out.
func _show_tooltip(delta: float) -> void:
	var badge: PhotoBadge = _badges.get(hovered) if hovered else null
	if _retire_shown < 1.0 or not badge or not badge.visible or modulate.a < 1.0:
		_rested = 0.0
		_tooltip.close()
		return
	_rested += delta
	if _rested >= _tooltip.rest_seconds:
		var marker := pick_up_markers.get_marker(hovered) if pick_up_markers else null
		_tooltip.target = marker if marker else badge
		_tooltip.open()
