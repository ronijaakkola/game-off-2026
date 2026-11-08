class_name RouteLine
extends MeshInstance3D
## The bus's route, drawn as flat ribbons on the orbit plane, with a small diamond at each
## marked point. The diamond under the pointer is white. It draws in global space.

## The ribbon's width.
@export_range(0.01, 1.0, 0.01) var width := 0.1
## How far a diamond reaches from its point.
@export_range(0.01, 1.0, 0.01) var marker_size := 0.22
## Matches the border of the planets on the route.
@export var color := Color(1.0, 0.6, 0.22, 0.9)
## The diamond under the pointer, like a planet's border there.
@export var hover_color := Color.WHITE

var _mesh := ImmediateMesh.new()
var _material := _make_material(color)
var _hover_material := _make_material(hover_color)


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	_material.albedo_color = color
	_hover_material.albedo_color = hover_color


## Draws the line from [param from] through [param stops]. It runs to a planet's surface
## rather than to where the bus docks, so the planet reads as part of the route, and
## leaves it from the side facing the next stop. Points in space get a diamond, white for
## [param hovered].
func draw_stops(from: Vector3, stops: Array[RouteStop], hovered: RouteStop) -> void:
	var legs := PackedVector3Array()
	var markers := PackedVector3Array()
	var hovered_index := -1
	var at := _flat(from)
	var from_planet: Planet
	for stop: RouteStop in stops:
		var end := _flat(stop.point)
		if stop.planet:
			end = _flat(stop.planet.get_body_global_position())
		var start := _surface_point(from_planet, end) if from_planet else at
		if stop.planet:
			legs.append_array([start, _surface_point(stop.planet, start)])
		else:
			legs.append_array([start, end])
			if stop == hovered:
				hovered_index = markers.size()
			markers.append(end)
		at = end
		from_planet = stop.planet
	draw_route(legs, markers, hovered_index)


## Draws a ribbon for each pair of points in [param legs] (start, end, start, end, ...) and
## a diamond at each of [param markers], the one at [param hovered] in [member hover_color].
func draw_route(legs: PackedVector3Array, markers: PackedVector3Array, hovered := -1) -> void:
	_mesh.clear_surfaces()
	if legs.size() < 2 and markers.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	for i: int in range(0, legs.size() - 1, 2):
		var from := _flat(legs[i])
		var to := _flat(legs[i + 1])
		var along := to - from
		if along.length_squared() < 1e-6:
			continue
		var side := along.cross(Vector3.UP).normalized() * width * 0.5
		_quad(from - side, from + side, to + side, to - side)
	for i: int in markers.size():
		if i != hovered:
			_diamond(markers[i])
	_mesh.surface_end()
	# Its own surface, drawn after the rest so it sits on top of the ribbons.
	if hovered >= 0 and hovered < markers.size():
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _hover_material)
		_diamond(markers[hovered])
		_mesh.surface_end()


func _diamond(point: Vector3) -> void:
	var at := _flat(point)
	var x := Vector3(marker_size, 0.0, 0.0)
	var z := Vector3(0.0, 0.0, marker_size)
	_quad(at - x, at - z, at + x, at + z)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point: Vector3 in [a, b, c, a, c, d]:
		_mesh.surface_add_vertex(point)


static func _make_material(albedo: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = albedo
	return material


# The point on planet's surface, on the orbit plane, that faces toward.
func _surface_point(planet: Planet, toward: Vector3) -> Vector3:
	var center := _flat(planet.get_body_global_position())
	var flat := _flat(toward - center)
	var direction := flat.normalized() if flat.length_squared() > 1e-6 else Vector3.BACK
	return center + direction * planet.get_body_radius()


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
