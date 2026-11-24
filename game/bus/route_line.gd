class_name RouteLine
extends MeshInstance3D
## PROTOTYPE: the bus's route as a screen-space line with a dark outline, styles picked by
## `style=N` in the user args.

const SHADER := preload("res://game/bus/route_line.gdshader")
const CAMERA_HOST_PRIORITY := 300
const SEGMENTS := 12
## The gap between the bus's footprint and where the line starts, in pixels, and half the
## bus's width on the orbit plane.
const BUS_GAP_PIXELS := 4.0
const BUS_HALF_WIDTH := 0.2

@export var color := Color(1.0, 0.6, 0.22, 0.9)

var _style := 0
var _line_pixels := 2.5
var _reach := 4.0
var _flow_speed := 0.0
var _period := 14.0
var _marker_pixels := 6.0
var _legs := PackedVector3Array()
# The planet each point in _legs is on the edge of, or null.
var _leg_planets: Array[Planet] = []
var _markers := PackedVector3Array()
var _scroll := 0.0
# PROTOTYPE: how the line leaves the bus, from `bus=N` in the user args: 0 from its middle,
# 1 a gap past its footprint, 2 that and a fade in.
var _bus_style := 0
# Where the bus is and which way it faces on the orbit plane, as of the last draw_stops().
var _bus_at := Vector3.ZERO
var _bus_forward := Vector3.FORWARD
var _mesh := ImmediateMesh.new()
var _material := ShaderMaterial.new()


func _ready() -> void:
	process_priority = CAMERA_HOST_PRIORITY + 1
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	_material.shader = SHADER
	_material.set_shader_parameter(&"color", color)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("bus="):
			_bus_style = int(arg.trim_prefix("bus="))
		if arg.begins_with("style="):
			_style = int(arg.trim_prefix("style="))
	_configure()


func _configure() -> void:
	var p := {}
	match _style:
		0:  # thin solid
			_line_pixels = 2.5
			p = {style = 0, outline = 1.25}
		1:  # short flowing dashes, thinner than the trip arc
			_line_pixels = 2.5
			_flow_speed = 14.0
			p = {style = 1, outline = 1.25, dash_length = 7.0, gap = 6.0}
		2:  # flowing dots
			_line_pixels = 3.5
			_flow_speed = 12.0
			p = {style = 2, outline = 1.25, dash_length = 3.5, gap = 6.0}
		3:  # chevrons
			_line_pixels = 1.8
			_flow_speed = 12.0
			p = {style = 3, outline = 1.0, dash_length = 2.0, gap = 12.0, chevron = 4.0}
			_reach = 7.0
		4:  # faint track with flowing dots on it
			_line_pixels = 3.5
			_flow_speed = 12.0
			p = {style = 4, outline = 1.0, dash_length = 3.5, gap = 10.0, track_alpha = 0.55}
		5:  # thin solid, hollow diamonds
			_line_pixels = 2.0
			p = {style = 0, outline = 1.25, marker_hollow = true}
		6:  # thin solid with a soft glow, no dark outline
			_line_pixels = 2.0
			p = {style = 0, outline = 4.0, glow = true, outline_color = Color(1.0, 0.6, 0.22, 0.35)}
	p.half_width = _line_pixels * 0.5
	if _style != 3:
		_reach = _line_pixels * 0.5 + float(p.outline)
	p.reach = _reach
	_period = float(p.get("dash_length", 0.0)) + float(p.get("gap", 0.0))
	p.marker_radius = _marker_pixels
	for key: String in p:
		_material.set_shader_parameter(key, p[key])


func draw_stops(from: Vector3, stops: Array[RouteStop], forward := Vector3.FORWARD) -> void:
	_bus_at = _flat(from)
	_bus_forward = _flat(forward).normalized()
	var legs := PackedVector3Array()
	var markers := PackedVector3Array()
	var leg_planets: Array[Planet] = []
	var at := _flat(from)
	var from_planet: Planet
	for stop: RouteStop in stops:
		var end := _flat(stop.point)
		if stop.planet:
			end = _flat(stop.planet.get_body_global_position())
		var start := _surface_point(from_planet, end) if from_planet else at
		leg_planets.append_array([from_planet, stop.planet])
		if stop.planet:
			legs.append_array([start, _surface_point(stop.planet, start)])
		else:
			legs.append_array([start, end])
			markers.append(end)
		at = end
		from_planet = stop.planet
	draw_route(legs, markers)
	_leg_planets = leg_planets


func draw_route(legs: PackedVector3Array, markers: PackedVector3Array) -> void:
	_legs = legs
	_markers = markers
	_leg_planets = []


func _process(delta: float) -> void:
	_mesh.clear_surfaces()
	var camera := get_viewport().get_camera_3d()
	if not camera or (_legs.size() < 2 and _markers.is_empty()):
		return
	if _period > 0.0 and not Settings.reduce_motion:
		_scroll = fmod(_scroll + _flow_speed * delta, _period)
	_material.set_shader_parameter(&"scroll", _scroll)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	var along := 0.0
	for i: int in range(0, _legs.size() - 1, 2):
		var from := _legs[i]
		var to := _legs[i + 1]
		var fade := 0.0
		if i == 0 and _bus_style > 0 and (_leg_planets.is_empty() or not _leg_planets[0]):
			var bus_t := _bus_edge_t(camera, from, to)
			if bus_t >= 1.0:
				continue
			from = from.lerp(to, bus_t)
			fade = 10.0 if _bus_style == 2 else 0.0
		if i + 1 < _leg_planets.size():
			# Each end on a planet stops at the border's outer edge as seen on screen, so the
			# line never runs over the planet's disc.
			var start_planet := _leg_planets[i]
			var end_planet := _leg_planets[i + 1]
			var start_t := _edge_t(camera, start_planet, from, to) if start_planet else 0.0
			var end_t := 1.0 - _edge_t(camera, end_planet, to, from) if end_planet else 1.0
			if end_t <= start_t:
				continue
			var clipped_from := from.lerp(to, start_t)
			to = from.lerp(to, end_t)
			from = clipped_from
		along = _leg(camera, from, to, along, fade)
	for marker: Vector3 in _markers:
		_diamond(camera, marker)
	_mesh.surface_end()


# How far from near to far the line leaves planet's border on screen, from 0 to 1: the
# share of the way at which it is first the border's reach past the planet's edge.
func _edge_t(camera: Camera3D, planet: Planet, near: Vector3, far: Vector3) -> float:
	var center := planet.get_body_global_position()
	var on_screen := camera.unproject_position(center)
	var edge := camera.unproject_position(center + camera.global_basis.x * planet.get_body_radius())
	var reach := on_screen.distance_to(edge) + Planet.border_visible_pixels()
	var inside := 0.0
	var outside := 1.0
	if camera.unproject_position(far).distance_to(on_screen) <= reach:
		return 1.0
	for i: int in 20:
		var middle := (inside + outside) * 0.5
		if camera.unproject_position(near.lerp(far, middle)).distance_to(on_screen) <= reach:
			inside = middle
		else:
			outside = middle
	return outside


# How far from the bus at from toward to the line leaves its footprint on the orbit
# plane, grown by a few pixels, from 0 to 1.
func _bus_edge_t(camera: Camera3D, from: Vector3, to: Vector3) -> float:
	var pad := _pixels_to_world(camera, BUS_GAP_PIXELS, from)
	var forward := _bus_forward
	var right := forward.cross(Vector3.UP)
	var inside := 0.0
	var outside := 1.0
	for i: int in 20:
		var middle := (inside + outside) * 0.5
		var offset := from.lerp(to, middle) - _bus_at
		var length := absf(offset.dot(forward)) - (FrameshiftBus.RADIUS + pad)
		var width := absf(offset.dot(right)) - (BUS_HALF_WIDTH + pad)
		if length <= 0.0 and width <= 0.0:
			inside = middle
		else:
			outside = middle
	return outside


func _leg(camera: Camera3D, from: Vector3, to: Vector3, along: float, fade_pixels := 0.0) -> float:
	if from.distance_squared_to(to) < 1e-6:
		return along
	var tangent := to - from
	var screen := camera.unproject_position(from)
	var last_inner := Vector3.ZERO
	var last_outer := Vector3.ZERO
	var last_along := 0.0
	var last_alpha := 1.0
	var start_along := along
	for i: int in SEGMENTS + 1:
		var point := from.lerp(to, float(i) / SEGMENTS)
		var on_screen := camera.unproject_position(point)
		along += on_screen.distance_to(screen)
		screen = on_screen
		var side := tangent.cross(camera.global_position - point).normalized()
		side *= _pixels_to_world(camera, _reach, point)
		var inner := point - side
		var outer := point + side
		var alpha := 1.0
		if fade_pixels > 0.0:
			alpha = clampf((along - start_along) / fade_pixels, 0.0, 1.0)
		if i > 0:
			_vertex(last_inner, Vector2(last_along, -1.0), 0.0, last_alpha)
			_vertex(last_outer, Vector2(last_along, 1.0), 0.0, last_alpha)
			_vertex(outer, Vector2(along, 1.0), 0.0, alpha)
			_vertex(last_inner, Vector2(last_along, -1.0), 0.0, last_alpha)
			_vertex(outer, Vector2(along, 1.0), 0.0, alpha)
			_vertex(inner, Vector2(along, -1.0), 0.0, alpha)
		last_inner = inner
		last_outer = outer
		last_along = along
		last_alpha = alpha
	return along


func _diamond(camera: Camera3D, point: Vector3) -> void:
	var size := _marker_pixels + 3.0
	var scale := _pixels_to_world(camera, size, point)
	var right := camera.global_basis.x * scale
	var up := camera.global_basis.y * scale
	var corners := [
		[point - right - up, Vector2(-size, -size)],
		[point + right - up, Vector2(size, -size)],
		[point + right + up, Vector2(size, size)],
		[point - right + up, Vector2(-size, size)],
	]
	for index: int in [0, 1, 2, 0, 2, 3]:
		_vertex(corners[index][0], corners[index][1], 1.0)


func _vertex(point: Vector3, uv: Vector2, marker := 0.0, alpha := 1.0) -> void:
	_mesh.surface_set_uv(uv)
	_mesh.surface_set_uv2(Vector2(alpha, marker))
	_mesh.surface_add_vertex(point)


func _pixels_to_world(camera: Camera3D, pixels: float, point: Vector3) -> float:
	var depth := -(camera.global_transform.affine_inverse() * point).z
	var height := get_viewport().get_visible_rect().size.y
	return pixels * 2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5) / height


func _surface_point(planet: Planet, toward: Vector3) -> Vector3:
	var center := _flat(planet.get_body_global_position())
	var flat := _flat(toward - center)
	var direction := flat.normalized() if flat.length_squared() > 1e-6 else Vector3.BACK
	return center + direction * planet.get_body_radius()


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
