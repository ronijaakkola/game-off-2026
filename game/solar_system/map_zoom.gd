class_name MapZoom
extends Node
## The map zoomed in on one planet and its moons for the tutorial, then zoomed out to the
## whole solar system. Zoomed in, [member world], which holds the star and the planets, is
## [member zoom] times its size around [member pivot]'s body, so the moons sit as far out
## as planets on the whole map. The bus isn't in the world: it keeps its size and speed, so
## a trip to a moon takes as long as one across the whole map, and costs as much fuel.
## Zoomed in, the bus starts docked at the pivot on the side facing its first moon, so its
## way there is clear of the pivot. The pivot holds still, and its moons hold still too
## while the bus waits at the pivot, so the way stays clear until it leaves; otherwise they
## orbit at the speed in global space they have on the whole map. Everything else in the
## world is hidden: the other planets, the
## star's body (not its light) and every orbit line but the moons'. The camera looks at the
## pivot and stays near it.
## [method zoom_out] shrinks the world back to its true size while the camera moves back to
## where it starts on the whole map, and the hidden things show again, the orbit lines
## fading in. Pan and zoom wait meanwhile, and the planets hold still. Under Reduce motion
## it cuts.

## The map is at its true size again, and the camera is the player's.
signal zoomed_out

@export var world: Node3D
## Starts docked at the pivot.
@export var bus: FrameshiftBus
## The planet zoomed in on. Its moons are the planets on the zoomed map.
@export var pivot: Planet
## The camera, which looks at the pivot while zoomed in.
@export var rig: CameraRig
## How many times bigger the world is while zoomed in.
@export_range(1.0, 20.0, 0.1, "or_greater") var zoom := 6.5
## How far the camera's look-at point may go from the pivot while zoomed in, on the orbit
## plane.
@export_range(0.0, 200.0, 0.1, "or_greater") var zoomed_bounds_radius := 12.0
## Seconds the zoom out takes.
@export_range(0.1, 20.0, 0.1) var zoom_out_seconds := 4.0

# The world's scale now: zoom while zoomed in, 1 once zoomed out.
var _scale := 1.0
var _zooming_out := false
# Where the pivot's body is in the world's space, which stays put on screen as the world
# scales.
var _pivot_point := Vector3.ZERO
# Where the camera looks, and how far it may go, on the whole map.
var _home := Vector3.ZERO
var _home_center := Vector3.ZERO
var _home_radius := 0.0
# Where the camera's bounds are centred while zoomed in: on the pivot's body.
var _zoomed_center := Vector3.ZERO
var _motion: Tween


## Zooms the map in on the pivot at once, with the bus docked there. Call it before the
## scene is ready, so the planets, the bus and the camera start there.
func zoom_in() -> void:
	_pivot_point = pivot.position + pivot.get_orbit_point()
	_scale = zoom
	_apply_scale()
	bus.start_planet = pivot
	for moon: Node in pivot.get_children():
		if moon is Planet:
			var toward := (moon as Planet).get_orbit_point()
			bus.start_direction = Vector3(toward.x, 0.0, toward.z).normalized()
			break
	for node: Node3D in _get_hidden():
		node.visible = false
	for planet: Planet in _get_faded_orbits():
		planet.orbit_opacity = 0.0
	_home = rig.position
	_home_center = rig.bounds_center
	_home_radius = rig.bounds_radius
	# The world and the camera share a parent, so this is where the pivot's body is to both.
	_zoomed_center = world.transform * _pivot_point
	rig.bounds_center = _zoomed_center
	rig.bounds_radius = zoomed_bounds_radius
	rig.position = rig.bounds_center


## Whether the map is zoomed in, or zooming out.
func is_zoomed() -> bool:
	return _scale != 1.0 or _zooming_out


func is_zooming_out() -> bool:
	return _zooming_out


## Shrinks the map back to its true size ([signal zoomed_out] once there). Does nothing
## unless it is zoomed in.
func zoom_out() -> void:
	if _scale == 1.0 or _zooming_out:
		return
	_zooming_out = true
	rig.locked = true
	for node: Node3D in _get_hidden():
		node.visible = true
	var from := rig.position
	if Settings.reduce_motion:
		_step(1.0, from)
		_finish()
		return
	if _motion:
		_motion.kill()
	_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_method(_step.bind(from), 0.0, 1.0, zoom_out_seconds)
	_motion.finished.connect(_finish)


## How much of the orbit speed [param planet] runs at: all of it on the whole map, the
## share that keeps a moon of the pivot at its whole-map speed in global space while zoomed
## in, and none for the rest, nor for the moons while the bus waits at the pivot.
## Everything holds still while the map zooms out.
func get_orbit_share(planet: Planet) -> float:
	if not is_zoomed():
		return 1.0
	if _zooming_out or planet.get_parent() != pivot:
		return 0.0
	if bus.is_at_planet() and bus.get_docked_planet() == pivot:
		return 0.0
	return 1.0 / _scale


# Partway through the zoom out, from 0 to 1. The scale shrinks by the same factor in every
# equal step, so the zoom reads as a steady pull back rather than one that rushes at the
# end; the camera eases from where it was to where it starts on the whole map.
func _step(progress: float, from: Vector3) -> void:
	_scale = pow(zoom, 1.0 - progress)
	_apply_scale()
	for planet: Planet in _get_faded_orbits():
		planet.orbit_opacity = progress
	rig.bounds_center = _zoomed_center.lerp(_home_center, progress)
	rig.bounds_radius = lerpf(zoomed_bounds_radius, _home_radius, progress)
	rig.move_to(from.lerp(_home, progress))


func _finish() -> void:
	_scale = 1.0
	_apply_scale()
	_zooming_out = false
	rig.bounds_center = _home_center
	rig.bounds_radius = _home_radius
	rig.locked = false
	zoomed_out.emit()


# Scales the world around the pivot's body, which stays where it is.
func _apply_scale() -> void:
	world.transform = Transform3D(
		Basis.from_scale(Vector3.ONE * _scale), _pivot_point - _pivot_point * _scale
	)


# What doesn't show while zoomed in: every planet in the world but the pivot, with its
# moons, and the bodies of anything else, such as the star, whose light still shines.
func _get_hidden() -> Array[Node3D]:
	var hidden: Array[Node3D] = []
	for child: Node in world.get_children():
		if child == pivot:
			continue
		if child is Planet:
			hidden.append(child as Node3D)
			continue
		for part: Node in child.get_children():
			if part is GeometryInstance3D:
				hidden.append(part as Node3D)
	return hidden


# The orbit lines that fade in as the map zooms out: every planet's but the pivot's moons'.
func _get_faded_orbits() -> Array[Planet]:
	var faded: Array[Planet] = []
	var nodes: Array[Node] = world.get_children()
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		nodes.append_array(node.get_children())
		if node is Planet and node.get_parent() != pivot:
			faded.append(node as Planet)
	return faded
