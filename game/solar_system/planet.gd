@tool
class_name Planet
extends Node3D
## A planet or moon on a circular orbit around this node's origin, drawn with its orbit
## line and optional flat rings. Put it at the centre it orbits: a planet at the star, a
## moon as a child of its planet (at the planet's origin), which then keeps it around
## the planet's body.
## It builds its meshes in code as internal nodes, so the scene saves only its exports.
## The editor shows each body at its [member start_angle]; it moves only when the game runs.

const SEGMENTS := 128

static var _sphere: SphereMesh
static var _outline_material: StandardMaterial3D

## The body's radius.
@export_range(0.05, 10.0, 0.01, "or_greater") var radius := 1.0:
	set(value):
		radius = value
		_rebuild()
## The orbit's radius, from this node's origin to the body's centre.
@export_range(0.0, 100.0, 0.1, "or_greater") var orbit_radius := 5.0:
	set(value):
		orbit_radius = value
		_rebuild()
## Seconds per orbit. 0 stays still; negative orbits the other way.
@export var orbit_period := 30.0
## Where on its orbit the body starts, in degrees.
@export_range(0.0, 360.0, 0.1) var start_angle := 0.0:
	set(value):
		start_angle = value
		_rebuild()
## Seconds per turn around its own axis. 0 doesn't turn.
@export var spin_period := 10.0
## How far the axis leans, in degrees. Tilts the rings with it.
@export_range(-90.0, 90.0, 0.1) var tilt := 0.0:
	set(value):
		tilt = value
		_rebuild()
## The surface, usually a ShaderMaterial on planet.gdshader.
@export var surface_material: Material:
	set(value):
		surface_material = value
		_rebuild()

@export_group("Orbit line")
@export var show_orbit := true:
	set(value):
		show_orbit = value
		_rebuild()
@export_range(0.005, 1.0, 0.005) var orbit_width := 0.05:
	set(value):
		orbit_width = value
		_rebuild()
## Unshaded and translucent reads best. Share one between planets.
@export var orbit_material: Material:
	set(value):
		orbit_material = value
		_rebuild()

@export_group("Rings")
## The rings' material, usually a ShaderMaterial on planet_rings.gdshader. None hides them.
@export var ring_material: Material:
	set(value):
		ring_material = value
		_rebuild()
## The inner and outer edge of the rings, in body radii.
@export var ring_inner := 1.4:
	set(value):
		ring_inner = value
		_rebuild()
@export var ring_outer := 2.3:
	set(value):
		ring_outer = value
		_rebuild()

## Shows a white border round the body, as when the pointer is over it.
var highlighted := false:
	set(value):
		highlighted = value
		_outline.visible = value
## How far the border reaches past the body's edge.
var outline_width := 0.05:
	set(value):
		outline_width = value
		_outline.scale = Vector3.ONE * (get_body_radius() + value) / _get_sphere().radius

var _time := 0.0
# Internal nodes: the scene doesn't own them, so the editor never saves them.
var _pivot := Node3D.new()
var _orbit_line := MeshInstance3D.new()
var _body := Node3D.new()
var _tilt := Node3D.new()
var _surface := MeshInstance3D.new()
var _rings := MeshInstance3D.new()
var _outline := MeshInstance3D.new()


func _init() -> void:
	add_child(_pivot, false, INTERNAL_MODE_FRONT)
	_pivot.add_child(_orbit_line)
	_pivot.add_child(_body)
	_body.add_child(_tilt)
	_tilt.add_child(_surface)
	_tilt.add_child(_rings)
	_body.add_child(_outline)
	_surface.mesh = _get_sphere()
	_outline.mesh = _get_sphere()
	_outline.material_override = _get_outline_material()
	_outline.visible = false
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orbit_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	_place_body()
	if spin_period != 0.0:
		_surface.rotation.y = TAU * _time / spin_period


## Moves the centre of the orbit, relative to this node. A planet calls it on its moons.
func set_orbit_center(center: Vector3) -> void:
	_pivot.position = center


## Where the body is now, relative to this node.
func get_body_position() -> Vector3:
	return _pivot.position + _body.position


## The body's radius as drawn. The sphere mesh's own radius is 0.5, so it is half of
## [member radius].
func get_body_radius() -> float:
	return radius * _get_sphere().radius


## Where the body is now, in global space.
func get_body_global_position() -> Vector3:
	return to_global(get_body_position())


## A flat ring in the XZ plane, facing up, from [param inner] to [param outer]. UV.x runs
## 0 at the inner edge to 1 at the outer one.
static func make_annulus(inner: float, outer: float, segments := SEGMENTS) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i: int in segments + 1:
		var angle := TAU * i / segments
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var along := float(i) / segments
		vertices.append_array([direction * inner, direction * outer])
		normals.append_array([Vector3.UP, Vector3.UP])
		uvs.append_array([Vector2(0.0, along), Vector2(1.0, along)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	return mesh


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_surface.scale = Vector3.ONE * radius
	outline_width = outline_width
	_surface.material_override = surface_material
	_tilt.rotation.z = deg_to_rad(tilt)
	_orbit_line.visible = show_orbit and orbit_radius > 0.0
	if _orbit_line.visible:
		var half := orbit_width * 0.5
		_orbit_line.mesh = make_annulus(orbit_radius - half, orbit_radius + half)
		_orbit_line.material_override = orbit_material
	_rings.visible = ring_material != null
	if _rings.visible:
		_rings.mesh = make_annulus(radius * ring_inner, radius * ring_outer)
		_rings.material_override = ring_material
	_place_body()


func _place_body() -> void:
	var angle := deg_to_rad(start_angle)
	if orbit_period != 0.0:
		angle += TAU * _time / orbit_period
	# Counter-clockwise seen from above, as the planets go.
	_body.position = Vector3(cos(angle), 0.0, -sin(angle)) * orbit_radius
	for child: Node in get_children():
		var moon := child as Planet
		if moon:
			moon.set_orbit_center(get_body_position())


static func _get_sphere() -> SphereMesh:
	if not _sphere:
		_sphere = SphereMesh.new()
		_sphere.radial_segments = 64
		_sphere.rings = 32
	return _sphere


# A shell drawn from behind, so only its rim past the body shows.
static func _get_outline_material() -> StandardMaterial3D:
	if not _outline_material:
		_outline_material = StandardMaterial3D.new()
		_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline_material.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline_material.albedo_color = Color.WHITE
	return _outline_material
