@tool
class_name Planet
extends Node3D
## A planet or moon on a circular orbit around this node's origin, drawn with its orbit
## line and optional flat rings. Put it at the centre it orbits: a planet at the star, a
## moon as a child of its planet (at the planet's origin), which then keeps it around
## the planet's body.
## It builds its meshes in code as internal nodes, so the scene saves only its exports.
## The editor shows each body at its [member start_angle]; it moves only when the game runs.
## It can sit in a scaled world, as on the tutorial's zoomed map: its sizes in global space
## grow with the scale, but its orbit line keeps its width.

enum Border { NONE, HOVER, ROUTE }

const SEGMENTS := 128
## The name's colour: an off-white with the sky's lilac, a little see-through.
const LABEL_COLOR := Color(0.93, 0.92, 1.0, 0.85)
## A thin outline in the sky's navy, so the name still reads over orbit lines and rings.
const LABEL_OUTLINE_COLOR := Color(0.08, 0.07, 0.18, 0.7)
const LABEL_FONT_SIZE := 32
const LABEL_OUTLINE_SIZE := 8
const BORDER_COLORS: Dictionary[Border, Color] = {
	Border.HOVER: Color.WHITE,
	Border.ROUTE: Color(1.0, 0.6, 0.22),
}

static var _sphere: SphereMesh

## The name shown under the body. Empty shows none.
@export var display_name := "":
	set(value):
		display_name = value
		_label.text = value
		_label.visible = value != "" and label_opacity > 0.0
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
## The one colour that stands for this body in the UI, such as a passenger card's
## destination icon. Pick the colour the body reads as from the camera.
@export var icon_color := Color.WHITE
## Whether the bus can buy fuel here.
@export var sells_fuel := true
## Credits for one unit of fuel bought here. The bus's tank holds 100.
@export_range(0.0, 10.0, 0.01, "or_greater") var fuel_price := 0.1
## Whether it has a lab, where the player can research upgrades from every research tree.
@export var has_lab := false

@export_group("Orbit line")
@export var show_orbit := true:
	set(value):
		show_orbit = value
		_rebuild()
## The line's width in global space, whatever the scale of the world the planet sits in.
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
## The rings' one colour in the UI, as [member icon_color] is the body's.
@export var icon_ring_color := Color.WHITE

## The border round the body: none, white under the pointer, or orange on the bus's route.
var border := Border.NONE:
	set(value):
		border = value
		_show_border()
## How opaque the border is, from 0 (hidden) to 1, for fading it.
var border_opacity := 1.0:
	set(value):
		border_opacity = clampf(value, 0.0, 1.0)
		_show_border()
## How opaque the name is, from 0 (hidden) to 1, for fading it.
var label_opacity := 1.0:
	set(value):
		label_opacity = clampf(value, 0.0, 1.0)
		_label.modulate.a = LABEL_COLOR.a * label_opacity
		_label.outline_modulate.a = LABEL_OUTLINE_COLOR.a * label_opacity
		_label.visible = display_name != "" and label_opacity > 0.0
## How far the border reaches past the body's edge.
var outline_width := 0.05:
	set(value):
		outline_width = value
		var local := _get_local_radius() + value / get_world_scale()
		_outline.scale = Vector3.ONE * local / _get_sphere().radius
## Where the name hangs from, in global space, from the body's centre. The solar system
## sets it each frame to just past the body's lower edge as the camera sees it.
var label_offset := Vector3.ZERO:
	set(value):
		label_offset = value
		if _label.is_inside_tree():
			_label.global_position = _body.global_position + value
## How big the name is: its font's pixel size in world units at one unit from the camera,
## since the name keeps its size on screen at any distance.
var label_pixel_size := 0.001:
	set(value):
		label_pixel_size = value
		# The label is scaled with the world it sits in; this undoes it.
		_label.pixel_size = value / get_world_scale()

## How opaque the orbit line is, from 0 (hidden) to 1, for fading it in.
var orbit_opacity := 1.0:
	set(value):
		orbit_opacity = clampf(value, 0.0, 1.0)
		_show_orbit_line()

## How fast the body moves along its orbit, from 0 (held still) to 1 (its
## [member orbit_period]). Its spin keeps going. The solar system sets it on every planet.
var orbit_speed := 1.0
## How far the body has gone along its orbit, in seconds at full orbit speed. Its place on
## the orbit comes from it alone, however the speed changed on the way, so a save game keeps
## it to put the planet back. Set before the planet is ready, it starts there.
var orbit_time := 0.0

var _time := 0.0
# How fast the orbit's centre moves, in global space: a moon's planet's body velocity.
var _center_velocity := Vector3.ZERO
# Internal nodes: the scene doesn't own them, so the editor never saves them.
var _pivot := Node3D.new()
var _orbit_line := MeshInstance3D.new()
var _body := Node3D.new()
var _tilt := Node3D.new()
var _surface := MeshInstance3D.new()
var _rings := MeshInstance3D.new()
var _outline := MeshInstance3D.new()
var _label := Label3D.new()
# The world scale the orbit line was last built for, so it keeps its width.
var _line_scale := 1.0
# This planet's own copy of the orbit material while the line is faded, so the fade
# changes it alone. Null until it first fades.
var _faded_orbit_material: StandardMaterial3D
# This planet's own border material, so its colour and opacity change on it alone. Always
# see-through, so a fade never switches it to another shader.
var _border_material := _make_border_material()


func _init() -> void:
	add_child(_pivot, false, INTERNAL_MODE_FRONT)
	_pivot.add_child(_orbit_line)
	_pivot.add_child(_body)
	_body.add_child(_tilt)
	_tilt.add_child(_surface)
	_tilt.add_child(_rings)
	_body.add_child(_outline)
	_body.add_child(_label)
	_surface.mesh = _get_sphere()
	_outline.mesh = _get_sphere()
	_outline.visible = false
	_outline.material_override = _border_material
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orbit_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_init_label()


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	orbit_time += delta * orbit_speed
	if not is_equal_approx(get_world_scale(), _line_scale):
		_build_orbit_line()
	_place_body()
	if spin_period != 0.0:
		_surface.rotation.y = TAU * _time / spin_period


## Moves the centre of the orbit, relative to this node, and sets how fast it moves, in
## global space. A planet calls it on its moons.
func set_orbit_center(center: Vector3, velocity := Vector3.ZERO) -> void:
	_pivot.position = center
	_center_velocity = velocity


## Where the body is now, relative to this node.
func get_body_position() -> Vector3:
	return _pivot.position + _body.position


## The body's radius as drawn, in global space: [member radius] times the scale of the
## world it sits in.
func get_body_radius() -> float:
	return _get_local_radius() * get_world_scale()


## How much bigger the planet is drawn than its own units say: the scale of the world it
## sits in, 1 unless the map is zoomed.
func get_world_scale() -> float:
	return global_basis.get_scale().x if is_inside_tree() else 1.0


## Where the body is on its own orbit, from the orbit's centre, as [member orbit_time]
## puts it. Right before the planet is ready, too.
func get_orbit_point() -> Vector3:
	var angle := deg_to_rad(start_angle)
	if orbit_period != 0.0:
		angle += TAU * orbit_time / orbit_period
	# Counter-clockwise seen from above, as the planets go.
	return Vector3(cos(angle), 0.0, -sin(angle)) * orbit_radius


## How far the planet reaches from the body's centre, in global space: its rings' outer
## edge when it has rings, else its body's radius.
func get_extent() -> float:
	if has_rings():
		return maxf(get_body_radius(), radius * ring_outer * get_world_scale())
	return get_body_radius()


## The node at the body's centre, which moves along the orbit, for a camera to follow. Read
## it only; the planet places it every frame.
func get_body() -> Node3D:
	return _body


## Whether the body has rings: it does when it has a [member ring_material].
func has_rings() -> bool:
	return ring_material != null


## Where the body is now, in global space.
func get_body_global_position() -> Vector3:
	return to_global(get_body_position())


## How fast and which way the body moves now, in global space, per second: along its orbit
## at [member orbit_speed], plus its orbit centre's motion, which a moon's planet sets.
func get_body_velocity() -> Vector3:
	var velocity := Vector3.ZERO
	if orbit_period != 0.0:
		var angle := deg_to_rad(start_angle) + TAU * orbit_time / orbit_period
		var along := Vector3(-sin(angle), 0.0, -cos(angle))
		velocity = global_basis * along * orbit_radius * TAU / orbit_period * orbit_speed
	return velocity + _center_velocity


## The planet in [param planets] whose body is nearest [param point], or null when there
## are none.
static func nearest_to(point: Vector3, planets: Array[Planet]) -> Planet:
	var nearest: Planet
	var nearest_distance := INF
	for planet: Planet in planets:
		var distance := point.distance_to(planet.get_body_global_position())
		if distance < nearest_distance:
			nearest = planet
			nearest_distance = distance
	return nearest


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
	_build_orbit_line()
	_rings.visible = ring_material != null
	if _rings.visible:
		_rings.mesh = make_annulus(radius * ring_inner, radius * ring_outer)
		_rings.material_override = ring_material
	_place_body()


func _place_body() -> void:
	_body.position = get_orbit_point()
	for child: Node in get_children():
		var moon := child as Planet
		if moon:
			moon.set_orbit_center(get_body_position(), get_body_velocity())


# The orbit line's mesh, as wide in global space as orbit_width at the world's scale now.
func _build_orbit_line() -> void:
	_line_scale = get_world_scale()
	if show_orbit and orbit_radius > 0.0:
		var half := orbit_width * 0.5 / _line_scale
		_orbit_line.mesh = make_annulus(orbit_radius - half, orbit_radius + half)
	_show_orbit_line()


# Shows the orbit line at orbit_opacity, on a copy of the orbit material while faded.
func _show_orbit_line() -> void:
	_orbit_line.visible = show_orbit and orbit_radius > 0.0 and orbit_opacity > 0.0
	var base := orbit_material as StandardMaterial3D
	if orbit_opacity >= 1.0 or not base:
		_orbit_line.material_override = orbit_material
		return
	if not _faded_orbit_material:
		_faded_orbit_material = base.duplicate() as StandardMaterial3D
	_faded_orbit_material.albedo_color.a = base.albedo_color.a * orbit_opacity
	_orbit_line.material_override = _faded_orbit_material


func _get_local_radius() -> float:
	return radius * _get_sphere().radius


# Faces the camera at a fixed size on screen, hanging down from its position. It draws
# after the orbit lines, so they never cross it, but the bus still passes in front.
func _init_label() -> void:
	_label.visible = false
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.shaded = false
	_label.double_sided = false
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.font_size = LABEL_FONT_SIZE
	_label.pixel_size = label_pixel_size
	_label.outline_size = LABEL_OUTLINE_SIZE
	_label.modulate = LABEL_COLOR
	_label.outline_modulate = LABEL_OUTLINE_COLOR
	_label.render_priority = 2
	_label.outline_render_priority = 1
	_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _get_sphere() -> SphereMesh:
	if not _sphere:
		_sphere = SphereMesh.new()
		_sphere.radius = 1.0
		_sphere.height = 2.0
		_sphere.radial_segments = 64
		_sphere.rings = 32
	return _sphere


func _show_border() -> void:
	_outline.visible = border != Border.NONE and border_opacity > 0.0
	if _outline.visible:
		var color := BORDER_COLORS[border]
		color.a = border_opacity
		_border_material.albedo_color = color


# A shell drawn from behind, so only its rim past the body shows.
static func _make_border_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
