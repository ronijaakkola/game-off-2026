class_name MapZoom
extends Node
## The map zoomed in on one planet and its moons for the tutorial, then zoomed out to the
## whole solar system. Zoomed in, [member world], which holds the star and the planets, is
## [member zoom] times its size around [member pivot]'s body, so the moons sit as far out
## as planets on the whole map. The bus isn't in the world: it keeps its size and speed, so
## a trip to a moon takes as long as one across the whole map, and costs as much fuel.
## Zoomed in, the bus starts docked at the pivot on the side facing its first moon, so its
## way there is clear of the pivot. Every planet holds still on its orbit, spinning on, so
## the bus always finds the pivot and its moons where they were. Everything else in the
## world is hidden: the other planets, the
## star's body (not its light) and every orbit line but the moons'. The camera looks at the
## pivot and stays near it.
## [method zoom_out] shrinks the world back to its true size while the camera draws back
## until the whole map fits the screen's height, centred in it, and the hidden things show again,
## the orbit lines fading in. Those coming in keep the size they have on the whole map as
## the world shrinks around them, so they glide in from past the screen's edges. The
## planets start orbiting as it goes, slowly at first. Once it is there, it holds for
## [member settle_seconds] before [signal zoomed_out]. Pan and zoom wait meanwhile. Under
## Reduce motion it cuts, and still holds.

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
@export_range(0.1, 20.0, 0.1) var zoom_out_seconds := 7.0
## How much of the screen's height the whole map takes at the end of the zoom out, from its
## outermost orbit's far edge to its near one.
@export_range(0.5, 1.0, 0.01) var fit_height := 0.94
## Seconds it holds at the whole map before the camera is the player's again.
@export_range(0.0, 20.0, 0.1) var settle_seconds := 4.0

# The world's scale now: zoom while zoomed in, 1 once zoomed out.
var _scale := 1.0
var _zooming_out := false
# How far the zoom out has got, from 0 to 1.
var _progress := 0.0
# The camera's zoom as the zoom out starts, and where it ends.
var _from_distance := 0.0
var _end_distance := 0.0
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
	_from_distance = rig.distance
	_frame_whole_map()
	rig.max_distance = maxf(rig.max_distance, _end_distance)
	if Settings.reduce_motion:
		_step(1.0, from)
		_finish()
		return
	if _motion:
		_motion.kill()
	_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_method(_step.bind(from), 0.0, 1.0, zoom_out_seconds)
	_motion.finished.connect(_finish)


## How much of its orbit speed a planet runs at: all of it on the whole map, none while
## zoomed in, and more and more of it as the map zooms out, slowly at first.
func get_orbit_share(_planet: Planet) -> float:
	if not is_zoomed():
		return 1.0
	return _progress * _progress if _zooming_out else 0.0


# Partway through the zoom out, from 0 to 1. The scale shrinks by the same factor in every
# equal step, so the zoom reads as a steady pull back rather than one that rushes at the
# end; the camera eases from where it was to where it starts on the whole map.
func _step(progress: float, from: Vector3) -> void:
	_progress = progress
	_scale = pow(zoom, 1.0 - progress)
	_apply_scale()
	for planet: Planet in _get_faded_orbits():
		planet.orbit_opacity = progress
	rig.bounds_center = _zoomed_center.lerp(_home_center, progress)
	rig.bounds_radius = lerpf(zoomed_bounds_radius, _home_radius, progress)
	rig.move_to(from.lerp(_home, progress))
	rig.set_distance(lerpf(_from_distance, _end_distance, progress))


func _finish() -> void:
	_progress = 1.0
	_scale = 1.0
	_apply_scale()
	rig.bounds_center = _home_center
	rig.bounds_radius = _home_radius
	await get_tree().create_timer(settle_seconds).timeout
	_zooming_out = false
	rig.locked = false
	zoomed_out.emit()


# Where the camera ends, _home and _end_distance: the whole map, out to its outermost
# orbit, takes fit_height of the screen's height, centred in it. The star sits at the
# world's origin, the parent's too once the world is at its true size; the near side of the
# map looks bigger from the camera's angle, so the look-at point sits a little toward it.
func _frame_whole_map() -> void:
	var reach := 0.0
	for child: Node in world.get_children():
		var planet := child as Planet
		if planet:
			reach = maxf(reach, planet.orbit_radius + planet.radius)
	var view := rig.global_basis
	var ahead := Vector3(-view.z.x, 0.0, -view.z.z).normalized()
	var star := Vector3(0.0, rig.position.y, 0.0)
	var room := tan(deg_to_rad(get_viewport().get_camera_3d().fov) * 0.5) * fit_height
	# Farther back, the map takes less of the screen: halve the gap until it just fits.
	var near := rig.min_distance
	var far := rig.min_distance * 100.0
	for i: int in 32:
		var middle := (near + far) * 0.5
		var span := _span(star + ahead * _centring(star, ahead, reach, middle), middle, reach)
		if span.y - span.x <= room * 2.0:
			far = middle
		else:
			near = middle
	_end_distance = far
	_home = star + ahead * _centring(star, ahead, reach, far)


# How far along [param ahead] from [param star] to look, from [param distance] back, so a
# circle of [param reach] round the star is centred on screen from top to bottom.
func _centring(star: Vector3, ahead: Vector3, reach: float, distance: float) -> float:
	var low := -reach
	var high := reach
	for i: int in 32:
		var middle := (low + high) * 0.5
		var span := _span(star + ahead * middle, distance, reach)
		# Looking farther ahead moves the map down the screen.
		if span.x + span.y > 0.0:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5


# How high the bottom and the top of a circle of [param reach] round the star sit on screen,
# from the camera looking at [param look_at] from [param distance] back, as tangents of the
# angle from the view's middle: up is positive.
func _span(look_at: Vector3, distance: float, reach: float) -> Vector2:
	var view := rig.global_basis
	var eye := look_at + view.z * distance
	var span := Vector2(INF, -INF)
	for k: int in 64:
		var angle := TAU * k / 64.0
		var point := Vector3(cos(angle) * reach, look_at.y, sin(angle) * reach)
		var seen := view.inverse() * (point - eye)
		var height := seen.y / -seen.z
		span = Vector2(minf(span.x, height), maxf(span.y, height))
	return span


# Scales the world around the pivot's body, which stays where it is. What is hidden while
# zoomed in keeps its whole-map size: the other planets' bodies and the star's.
func _apply_scale() -> void:
	world.transform = Transform3D(
		Basis.from_scale(Vector3.ONE * _scale), _pivot_point - _pivot_point * _scale
	)
	var keep := 1.0 / _scale
	for node: Node3D in _get_hidden():
		if not node is Planet:
			node.scale = Vector3.ONE * keep
	for planet: Planet in _get_faded_orbits():
		if planet != pivot:
			planet.body_scale = keep


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
