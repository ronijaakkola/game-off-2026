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


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
