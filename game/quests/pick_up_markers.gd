class_name PickUpMarkers
extends Control
## Over each planet where the player has to pick up one particular person, their
## [PickUpMarker]: the notch's tip [constant GAP_PIXELS] above the top of the planet's
## whole shape on screen, rings included, at the same size at any zoom. Nothing in the game
## shows one yet; the debug panel's Pick-up marker card does ([DebugButtons]).
## The pointer on the planet, or on the closed card, opens it; once open, the whole open
## card keeps it open. It fades with the planet's name, and closes at once when that starts
## to fade, as when a planet's or the bus's panel opens. It places itself after the planets
## and the camera have moved each frame, a leaving one too until it has gone, so it stays
## on its planet as the camera moves, off screen with it, and hides with the planets the
## zoomed map hides.

## Pixels between the top of the planet's shape and the notch's tip.
const GAP_PIXELS := 8.0
## How many points round a planet's rings are measured to find their top on screen.
const RING_SAMPLES := 32
const MARKER := preload("res://game/quests/pick_up_marker.tscn")

## The camera the planets are seen through.
@export var camera: Camera3D
## Where the portraits are rendered.
@export var portrait_studio: PortraitStudio

var _markers: Dictionary[Planet, PickUpMarker] = {}
# The planet under each marker, the leaving ones included until they have gone.
var _planets: Dictionary[PickUpMarker, Planet] = {}


func _ready() -> void:
	process_priority = FrameOrder.SCREEN_MARKERS


func _process(_delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	var over_hud := get_viewport().gui_get_hovered_control() != null
	for marker: PickUpMarker in _planets:
		var planet := _planets[marker]
		var center := planet.get_body_global_position()
		marker.visible = (
			camera != null and planet.is_visible_in_tree() and not camera.is_position_behind(center)
		)
		if not marker.visible:
			continue
		var tip := Vector2(camera.unproject_position(center).x, _get_top(planet) - GAP_PIXELS)
		# A leaving card goes as it is, open or not.
		if not marker.is_leaving():
			_follow_pointer(marker, planet, tip, mouse, over_hud)
		marker.place(tip, planet.label_opacity)


## Shows [param passenger]'s marker over [param planet], with [param line] under their
## name, replacing any there.
func show_marker(planet: Planet, passenger: Passenger, line: String) -> void:
	remove_marker(planet)
	var marker := MARKER.instantiate() as PickUpMarker
	marker.portrait_studio = portrait_studio
	add_child(marker)
	marker.show_passenger(passenger, line)
	_markers[planet] = marker
	_planets[marker] = planet
	marker.tree_exited.connect(func() -> void: _planets.erase(marker))
	marker.appear()


## Takes the marker over [param planet] away, as they board or the pick-up is off.
func remove_marker(planet: Planet) -> void:
	var marker: PickUpMarker = _markers.get(planet)
	if not marker:
		return
	_markers.erase(planet)
	marker.leave()


## The marker over [param planet], or null, for a tooltip to open above.
func get_marker(planet: Planet) -> Control:
	return _markers.get(planet)


## Whether a marker shows over [param planet].
func has_marker(planet: Planet) -> bool:
	return _markers.has(planet)


# The top of [param planet]'s whole shape on screen, in pixels: its body's, or its rings'
# where they stand higher.
func _get_top(planet: Planet) -> float:
	var center := planet.get_body_global_position()
	var top := (
		camera.unproject_position(center + camera.global_basis.y * planet.get_body_radius()).y
	)
	if not planet.has_rings():
		return top
	var reach := planet.radius * planet.ring_outer * planet.get_world_scale() * planet.body_scale
	var plane := (
		planet.global_basis.orthonormalized() * Basis(Vector3.BACK, deg_to_rad(planet.tilt))
	)
	for i: int in RING_SAMPLES:
		var angle := TAU * i / RING_SAMPLES
		var point := center + plane * Vector3(cos(angle), 0.0, sin(angle)) * reach
		top = minf(top, camera.unproject_position(point).y)
	return top


# Opens [param marker] while the pointer is on its planet or its closed card, or still on
# it once open, and closes it at once while the planet's name fades.
func _follow_pointer(
	marker: PickUpMarker, planet: Planet, tip: Vector2, mouse: Vector2, over_hud: bool
) -> void:
	if planet.label_opacity < 1.0:
		marker.set_open(false, true)
		return
	var center := planet.get_body_global_position()
	var on_planet := ScreenPick.covers(camera, center, planet.get_body_radius(), mouse)
	var on_card := PickUpMarker.get_closed_rect(tip).has_point(mouse)
	var kept := marker.is_open() and marker.get_global_rect().has_point(mouse)
	marker.set_open(not over_hud and (on_planet or on_card or kept))
