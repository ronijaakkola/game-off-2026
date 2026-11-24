class_name RouteLine
extends MeshInstance3D
## The bus's route: a thin line on the orbit plane with a dark outline, as wide on screen at
## any zoom, with a diamond at each marked point. Each leg into or out of a planet stops at
## the outer edge of the planet's border on screen, so it never runs over the planet, and the
## line leaves the bus a few pixels past it and fades in. It is built facing the camera after
## the camera has moved each frame. It draws in global space.

const SHADER := preload("res://game/bus/route_line.gdshader")
## The process priority Phantom Camera's host sets on itself to move the camera.
const CAMERA_HOST_PRIORITY := 300
## Straight pieces in each leg, so its width on screen holds along it.
const SEGMENTS := 12
## Half the bus's width on the orbit plane; its half length is [constant FrameshiftBus.RADIUS].
const BUS_HALF_WIDTH := 0.2

## The line's width and its outline's, on screen, in pixels at the base window height.
@export var line_pixels := 2.5
@export var outline_pixels := 1.25
## How far a diamond reaches from its point, in pixels.
@export var marker_pixels := 6.0
## The gap between the bus and where the line starts, and how far it then fades in over, in
## pixels.
@export var bus_gap_pixels := 4.0
@export var fade_pixels := 10.0
## Matches the border of the planets on the route.
@export var color := Color(1.0, 0.6, 0.22, 0.9)

# Pairs of points, start and end, one for each leg, and the planet at each, or null.
var _legs := PackedVector3Array()
var _leg_planets: Array[Planet] = []
var _markers := PackedVector3Array()
# Where the bus is and which way it faces on the orbit plane, or no bus to leave.
var _bus_at := Vector3.ZERO
var _bus_forward := Vector3.ZERO
var _mesh := ImmediateMesh.new()
# This frame's vertices, gathered before the surface opens: ImmediateMesh errors on a surface
# with none, as when every leg is clipped away.
var _points := PackedVector3Array()
var _uvs := PackedVector2Array()
var _uv2s := PackedVector2Array()
var _material := ShaderMaterial.new()


func _ready() -> void:
	process_priority = CAMERA_HOST_PRIORITY + 1
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	_material.shader = SHADER
	_material.set_shader_parameter(&"color", color)
	_material.set_shader_parameter(&"half_width", line_pixels * 0.5)
	_material.set_shader_parameter(&"outline", outline_pixels)
	_material.set_shader_parameter(&"marker_reach", marker_pixels)


## Draws a short line at [param at] for one frame, so its material compiles now, while
## something such as SceneFlow's fade covers the screen, and not when the first route
## shows.
func warm_up(at: Vector3) -> void:
	draw_route(PackedVector3Array([at, at + Vector3.LEFT]), PackedVector3Array([at + Vector3.LEFT]))
	await get_tree().process_frame
	draw_route(PackedVector3Array(), PackedVector3Array())


## Draws the line from the bus at [param from], facing [param forward], through
## [param stops]. Points in space get a diamond.
func draw_stops(from: Vector3, stops: Array[RouteStop], forward: Vector3) -> void:
	var legs := PackedVector3Array()
	var planets: Array[Planet] = []
	var markers := PackedVector3Array()
	var at := _flat(from)
	var from_planet: Planet
	for stop: RouteStop in stops:
		var end := _flat(stop.planet.get_body_global_position() if stop.planet else stop.point)
		legs.append_array([at, end])
		planets.append_array([from_planet, stop.planet])
		if not stop.planet:
			markers.append(end)
		at = end
		from_planet = stop.planet
	draw_route(legs, markers, planets)
	_bus_at = _flat(from)
	_bus_forward = _flat(forward).normalized()


## Draws a line for each pair of points in [param legs] (start, end, start, end, ...) and
## a diamond at each of [param markers]. An end with a planet in [param planets], at the same
## index, stops at its border; a first leg not from a planet leaves the bus only after
## [method draw_stops].
func draw_route(
	legs: PackedVector3Array, markers: PackedVector3Array, planets: Array[Planet] = []
) -> void:
	_legs = legs
	_markers = markers
	_leg_planets = planets
	_bus_forward = Vector3.ZERO


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	var camera := get_viewport().get_camera_3d()
	if not camera or (_legs.size() < 2 and _markers.is_empty()):
		return
	_points.clear()
	_uvs.clear()
	_uv2s.clear()
	for i: int in range(0, _legs.size() - 1, 2):
		_draw_leg(camera, i)
	for marker: Vector3 in _markers:
		_diamond(camera, marker)
	if _points.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	for i: int in _points.size():
		_mesh.surface_set_uv(_uvs[i])
		_mesh.surface_set_uv2(_uv2s[i])
		_mesh.surface_add_vertex(_points[i])
	_mesh.surface_end()


# The leg starting at index i of _legs, clipped where it meets a planet's border or leaves
# the bus.
func _draw_leg(camera: Camera3D, i: int) -> void:
	var from := _flat(_legs[i])
	var to := _flat(_legs[i + 1])
	var start_planet := _leg_planets[i] if i < _leg_planets.size() else null
	var end_planet := _leg_planets[i + 1] if i + 1 < _leg_planets.size() else null
	var start := 0.0
	var fade := 0.0
	if start_planet:
		start = _border_t(camera, start_planet, from, to)
	elif i == 0 and _bus_forward != Vector3.ZERO:
		start = _bus_t(camera, from, to)
		fade = fade_pixels
	var end := 1.0 - _border_t(camera, end_planet, to, from) if end_planet else 1.0
	if end > start:
		_strip(camera, from.lerp(to, start), from.lerp(to, end), fade)


# How far from near to far the line first clears planet's border on screen, from 0 to 1.
func _border_t(camera: Camera3D, planet: Planet, near: Vector3, far: Vector3) -> float:
	var center := planet.get_body_global_position()
	var on_screen := camera.unproject_position(center)
	var edge := camera.unproject_position(center + camera.global_basis.x * planet.get_body_radius())
	var reach := on_screen.distance_to(edge) + Planet.BORDER_PIXELS
	return _clear_t(
		func(point: Vector3) -> bool:
			return camera.unproject_position(point).distance_to(on_screen) <= reach,
		near,
		far
	)


# How far from the bus toward to the line first clears the bus's footprint on the orbit
# plane, grown by the gap, from 0 to 1.
func _bus_t(camera: Camera3D, from: Vector3, to: Vector3) -> float:
	var gap := _pixels_to_world(camera, bus_gap_pixels, from)
	var right := _bus_forward.cross(Vector3.UP)
	return _clear_t(
		func(point: Vector3) -> bool:
			var offset := point - _bus_at
			return (
				absf(offset.dot(_bus_forward)) <= FrameshiftBus.RADIUS + gap
				and absf(offset.dot(right)) <= BUS_HALF_WIDTH + gap
			),
		from,
		to
	)


# The share of the way from near to far at which a point stops being inside, which holds at
# near: 1 when far is inside too.
func _clear_t(inside: Callable, near: Vector3, far: Vector3) -> float:
	if inside.call(far):
		return 1.0
	var low := 0.0
	var high := 1.0
	for i: int in 20:
		var middle := (low + high) * 0.5
		if inside.call(near.lerp(far, middle)):
			low = middle
		else:
			high = middle
	return high


# A strip from from to to facing the camera, as wide on screen all along, with UV.x the
# pixels along it on screen; fading in over its first fade_in pixels.
func _strip(camera: Camera3D, from: Vector3, to: Vector3, fade_in: float) -> void:
	var tangent := to - from
	if tangent.length_squared() < 1e-8:
		return
	var reach := line_pixels * 0.5 + outline_pixels
	var screen := camera.unproject_position(from)
	var along := 0.0
	var last_inner := Vector3.ZERO
	var last_outer := Vector3.ZERO
	var last_alpha := 0.0
	for i: int in SEGMENTS + 1:
		var point := from.lerp(to, float(i) / SEGMENTS)
		var on_screen := camera.unproject_position(point)
		along += on_screen.distance_to(screen)
		screen = on_screen
		var side := tangent.cross(camera.global_position - point).normalized()
		side *= _pixels_to_world(camera, reach, point)
		var alpha := clampf(along / fade_in, 0.0, 1.0) if fade_in > 0.0 else 1.0
		var inner := point - side
		var outer := point + side
		if i > 0:
			_vertex(last_inner, Vector2(0.0, -1.0), last_alpha)
			_vertex(last_outer, Vector2(0.0, 1.0), last_alpha)
			_vertex(outer, Vector2(0.0, 1.0), alpha)
			_vertex(last_inner, Vector2(0.0, -1.0), last_alpha)
			_vertex(outer, Vector2(0.0, 1.0), alpha)
			_vertex(inner, Vector2(0.0, -1.0), alpha)
		last_inner = inner
		last_outer = outer
		last_alpha = alpha


# A square facing the camera round point, the shader cutting the diamond and its outline
# from it.
func _diamond(camera: Camera3D, point: Vector3) -> void:
	var at := _flat(point)
	var size := marker_pixels + outline_pixels + 1.0
	var scale := _pixels_to_world(camera, size, at)
	var right := camera.global_basis.x * scale
	var up := camera.global_basis.y * scale
	var corners: Array[Vector3] = [
		at - right - up, at + right - up, at + right + up, at - right + up
	]
	var uvs: Array[Vector2] = [
		Vector2(-size, -size), Vector2(size, -size), Vector2(size, size), Vector2(-size, size)
	]
	for index: int in [0, 1, 2, 0, 2, 3]:
		_vertex(corners[index], uvs[index], 1.0, 1.0)


func _vertex(point: Vector3, uv: Vector2, alpha: float, marker := 0.0) -> void:
	_points.append(point)
	_uvs.append(uv)
	_uv2s.append(Vector2(alpha, marker))


# How wide pixels are in world units at point, seen through the camera.
func _pixels_to_world(camera: Camera3D, pixels: float, point: Vector3) -> float:
	var depth := -(camera.global_transform.affine_inverse() * point).z
	var height := get_viewport().get_visible_rect().size.y
	return pixels * 2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5) / height


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
