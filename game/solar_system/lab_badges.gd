class_name LabBadges
extends Control
## On the upper right of the rim of each planet with a lab ([member Planet.has_lab]), a
## small dark disc with a flask ([PhotoBadge]), so the player sees where to research while
## planning a route. It grows with the zoomed map, slower than the planets do. The pointer
## resting on such a planet opens a tooltip above its badge. It places itself after the
## planets and the camera have moved each frame, and hides with the planets the zoomed map
## hides.

## The disc's size, and the gap between its rim and the flask, in pixels.
const SIZE := 14.0
const PAD := 3.0
## Where on the rim the disc's centre sits: the angle up from the right, and how far
## inside the rim on screen, in pixels, so it straddles the rim at any zoom.
const ANGLE_DEGREES := 40.0
const RIM_INSET_PIXELS := 1.5
## How fast the disc grows as the map zooms in, as a share of how fast the planets do.
const ZOOM_GROWTH := 0.25
const TOOLTIP_TEXT := "Research planet"
## After the solar system, which moves the planets after Phantom Camera's host (300) has
## moved the camera; placed any earlier, the badges trail the planets by a frame.
const PROCESS_PRIORITY := 302
const BADGE := preload("res://game/passengers/photo_badge.tscn")
const TOOLTIP := preload("res://ui/tooltip/tooltip.tscn")
const FLASK := preload("res://shared/icons/flask_conical.svg")

## The camera the planets are seen through.
@export var camera: Camera3D

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


func _ready() -> void:
	process_priority = PROCESS_PRIORITY
	_tooltip = TOOLTIP.instantiate() as Tooltip
	# Running text, not a name: the planet's name is already under it.
	_tooltip.title = ""
	_tooltip.sentence = TOOLTIP_TEXT
	_tooltip.side = Tooltip.Side.ABOVE
	# It follows the badge as the planet moves: placed after the badge each frame, and not
	# on whole pixels, which would step behind it.
	_tooltip.snap_to_pixels = false
	_tooltip.process_priority = PROCESS_PRIORITY + 1
	add_child(_tooltip)


func _process(delta: float) -> void:
	var direction := Vector2.from_angle(-deg_to_rad(ANGLE_DEGREES))
	for planet: Planet in _badges:
		var badge := _badges[planet]
		var center := planet.get_body_global_position()
		badge.visible = (
			camera != null
			and modulate.a > 0.0
			and planet.is_visible_in_tree()
			and not camera.is_position_behind(center)
		)
		if not badge.visible:
			continue
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


## Whether [param planet] shows a badge.
func is_shown(planet: Planet) -> bool:
	var badge: PhotoBadge = _badges.get(planet)
	return badge != null and badge.visible


## Whether the tooltip shows at [param planet]'s badge.
func is_tooltip_shown(planet: Planet) -> bool:
	return planet != null and planet == hovered and _tooltip.visible


# Opens the tooltip at the hovered planet's badge once the pointer has rested on it as
# long as any tooltip waits, and closes it while the badges fade out.
func _show_tooltip(delta: float) -> void:
	var badge: PhotoBadge = _badges.get(hovered) if hovered else null
	if not badge or not badge.visible or modulate.a < 1.0:
		_rested = 0.0
		_tooltip.close()
		return
	_rested += delta
	if _rested >= _tooltip.rest_seconds:
		_tooltip.target = badge
		_tooltip.open()
