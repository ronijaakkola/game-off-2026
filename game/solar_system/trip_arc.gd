class_name TripArc
extends MeshInstance3D
## Where a passenger wants to go: an arc from the planet they wait at to their destination,
## rising off the orbit plane like a hop, so it never reads as part of the bus's route,
## which lies flat on the plane. A trip seen end on would rise straight at the camera and
## look like a straight line, so the more it points along the view, the more the arc also
## bows sideways on the orbit plane, to the side its rise already bends it toward on
## screen. That side is picked when the trip shows and kept, so the arc never flips over
## while the planets orbit. It is a line of rounded dashes in the passenger's race colour,
## with a thin dark outline so it reads over the star and the orbits, as wide on
## screen at any zoom. It leaves from the origin's edge on screen and ends at a ring round
## the destination, so it never crosses either planet. Shown, it grows out from the origin,
## and as it arrives the ring closes in. The dashes then flow toward the destination, and
## the ring sends out a pulse now and then. Under Reduce motion it fades in whole and holds
## still. It follows both planets as they orbit, and the camera after it has moved each
## frame. It draws in global space.

const SHADER := preload("res://game/solar_system/trip_arc.gdshader")
## The process priority Phantom Camera's host sets on itself to move the camera.
const CAMERA_HOST_PRIORITY := 300
## Straight pieces in the arc, and in each ring.
const ARC_SEGMENTS := 64
const RING_SEGMENTS := 48
## The share of the arc, from its start, over which it fades in out of the origin.
const START_FADE := 0.12
## The share of the growth, at its end, over which the ring closes in.
const RING_CLOSE := 0.3

## The camera the arc faces and is sized for.
@export var camera: Camera3D
## The line's width and its outline's, on screen, in pixels at the base window height.
@export var line_pixels := 4.0
@export var outline_pixels := 1.5
## Each dash, and the gap between two, in pixels along the line.
@export var dash_pixels := 10.0
@export var gap_pixels := 7.0
## How fast the dashes flow toward the destination, in pixels a second.
@export var flow_speed := 26.0
## How high the arc rises at its middle, as a share of the distance it spans.
@export_range(0.0, 1.0, 0.01) var lift := 0.3
## How far the arc bows sideways at its middle, as a share of the distance it spans, when
## the trip points straight along the view; less as it turns across it.
@export_range(0.0, 1.0, 0.01) var bow := 0.2
## The gap between the origin's edge on screen and where the arc starts, in pixels.
@export var start_gap_pixels := 4.0
## Seconds to grow from the origin to the destination, and to fade in or out.
@export var grow_seconds := 0.5
@export var fade_seconds := 0.15
## The ring round the destination: the gap from the planet's edge and the line's width, in
## pixels.
@export var ring_gap_pixels := 6.0
@export var ring_pixels := 3.0
## How far past the ring a pulse spreads before it is gone, in pixels, and how often one
## goes out, in seconds.
@export var pulse_pixels := 18.0
@export var pulse_seconds := 1.6

## Multiplies the arc's opacity: the parent fades it with the planets' names.
var opacity := 1.0

var _from: Planet
var _to: Planet
var _color := Color.WHITE
var _showing := false
# 0 hidden, 1 shown: the fade in and out.
var _alpha := 0.0
# Seconds since the arc started growing.
var _grow_time := 0.0
var _scroll := 0.0
# 0 to 1 through the current pulse.
var _pulse := 0.0
# 1 to bow to the right of travel, -1 to the left, 0 until the next draw picks.
var _bow_side := 0.0
var _mesh := ImmediateMesh.new()
var _arc_material := _make_material(true)
var _ring_material := _make_material(false)


func _ready() -> void:
	process_priority = CAMERA_HOST_PRIORITY + 1
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	visible = false
	_arc_material.set_shader_parameter(&"dash_length", dash_pixels)
	_arc_material.set_shader_parameter(&"gap", gap_pixels)


## Shows [param passenger]'s trip, from the planet they wait at to their destination, or
## hides the arc when [param passenger] is null.
func show_passenger(passenger: Passenger) -> void:
	if passenger and passenger.origin and passenger.destination:
		show_trip(passenger.origin, passenger.destination, Race.SKIN_COLORS[passenger.race])
	else:
		hide_trip()


## Shows the arc from [param from] to [param to] in [param color]. The same trip again, even
## while it fades out, carries on without growing again.
func show_trip(from: Planet, to: Planet, color := Color.WHITE) -> void:
	_color = color
	if from != _from or to != _to:
		_from = from
		_to = to
		_grow_time = 0.0
		_pulse = 0.0
		_bow_side = 0.0
	_showing = true


## Fades the arc out.
func hide_trip() -> void:
	_showing = false


## The planet the arc shows the way to, or null while it is hidden or fading out.
func get_destination() -> Planet:
	return _to if _showing else null


func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, 1.0 if _showing else 0.0, delta / fade_seconds)
	_mesh.clear_surfaces()
	visible = _alpha > 0.0 and opacity > 0.0 and _from and _to and camera
	if not visible:
		return
	var still := Settings.reduce_motion
	_grow_time += delta
	var grown := 1.0 if still else _ease_out(_grow_time / grow_seconds)
	var ring := clampf((grown - (1.0 - RING_CLOSE)) / RING_CLOSE, 0.0, 1.0)
	if not still:
		_scroll = fmod(_scroll + flow_speed * delta, dash_pixels + gap_pixels)
		if ring >= 1.0:
			_pulse = fmod(_pulse + delta / pulse_seconds, 1.0)
	_arc_material.set_shader_parameter(&"color", _color)
	_ring_material.set_shader_parameter(&"color", _color)
	_arc_material.set_shader_parameter(&"scroll", _scroll)
	_draw_arc(grown)
	if ring > 0.0:
		_draw_rings(ring, still)


# The arc from where it leaves the origin's edge on screen, grown of the way to where it
# meets the destination's ring: a strip facing the camera, with UV.x the pixels along it on
# screen, so the dashes keep their length. Nothing while the two overlap on screen.
func _draw_arc(grown: float) -> void:
	var from := _from.get_body_global_position()
	var to := _to.get_body_global_position()
	var bulge := _bulge(from, to)
	var start := _edge_t(from, to, bulge, _from, start_gap_pixels, 0.0)
	var end := _edge_t(from, to, bulge, _to, ring_gap_pixels + ring_pixels * 0.5, 1.0)
	if grown <= 0.0 or end <= start:
		return
	var points := PackedVector3Array()
	for i: int in ARC_SEGMENTS + 1:
		var t := lerpf(start, end, grown * i / ARC_SEGMENTS)
		points.append(_point(from, to, bulge, t))
	var half := line_pixels * 0.5 + outline_pixels
	_set_widths(_arc_material, line_pixels * 0.5)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _arc_material)
	var along := 0.0
	var screen := camera.unproject_position(points[0])
	var last_inner := Vector3.ZERO
	var last_outer := Vector3.ZERO
	var last_along := 0.0
	var last_alpha := 0.0
	for i: int in points.size():
		var point := points[i]
		var on_screen := camera.unproject_position(point)
		along += on_screen.distance_to(screen)
		screen = on_screen
		var tangent := points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
		var side := _side(point, tangent) * _pixels_to_world(half, point)
		var alpha := _alpha * opacity * smoothstep(0.0, START_FADE, grown * i / ARC_SEGMENTS)
		var inner := point - side
		var outer := point + side
		if i > 0:
			_vertex(last_inner, Vector2(last_along, -1.0), last_alpha)
			_vertex(last_outer, Vector2(last_along, 1.0), last_alpha)
			_vertex(outer, Vector2(along, 1.0), alpha)
			_vertex(last_inner, Vector2(last_along, -1.0), last_alpha)
			_vertex(outer, Vector2(along, 1.0), alpha)
			_vertex(inner, Vector2(along, -1.0), alpha)
		last_inner = inner
		last_outer = outer
		last_along = along
		last_alpha = alpha
	_mesh.surface_end()


# Rings facing the camera round the destination: a steady one, closing in from farther out
# as appear goes from 0 to 1, and once it has, a pulse spreading out from it and fading.
func _draw_rings(appear: float, still: bool) -> void:
	var center := _to.get_body_global_position()
	var half := ring_pixels * 0.5 + outline_pixels
	_set_widths(_ring_material, ring_pixels * 0.5)
	var out := ring_gap_pixels + half
	var alpha := _alpha * opacity
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _ring_material)
	_ring(center, out + (1.0 - appear) * pulse_pixels, half, alpha * appear)
	if not still and appear >= 1.0:
		var fade := 1.0 - _pulse
		_ring(center, out + _pulse * pulse_pixels, half, alpha * fade * fade * 0.8)
	_mesh.surface_end()


# A ring round the destination facing the camera, its middle [param out_pixels] past the
# planet's edge on screen and [param half_pixels] to either side of it.
func _ring(center: Vector3, out_pixels: float, half_pixels: float, alpha: float) -> void:
	var radius := _to.get_body_radius() + _pixels_to_world(out_pixels, center)
	var half := _pixels_to_world(half_pixels, center)
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	for i: int in RING_SEGMENTS:
		var a := TAU * i / RING_SEGMENTS
		var b := TAU * (i + 1) / RING_SEGMENTS
		var dir_a := right * cos(a) + up * sin(a)
		var dir_b := right * cos(b) + up * sin(b)
		_vertex(center + dir_a * (radius - half), Vector2(0.0, -1.0), alpha)
		_vertex(center + dir_a * (radius + half), Vector2(0.0, 1.0), alpha)
		_vertex(center + dir_b * (radius + half), Vector2(0.0, 1.0), alpha)
		_vertex(center + dir_a * (radius - half), Vector2(0.0, -1.0), alpha)
		_vertex(center + dir_b * (radius + half), Vector2(0.0, 1.0), alpha)
		_vertex(center + dir_b * (radius - half), Vector2(0.0, -1.0), alpha)


# How far the middle of the arc from from to to sits off the straight line between them:
# up off the orbit plane, and sideways on it as much as the trip points along the view,
# which is where rising alone would look straight on screen.
func _bulge(from: Vector3, to: Vector3) -> Vector3:
	var chord := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var span := chord.length()
	if span < 1e-6:
		return Vector3.ZERO
	var along := chord / span
	var view := -camera.global_basis.z
	view.y = 0.0
	var end_on := absf(along.dot(view.normalized())) if view.length_squared() > 1e-6 else 0.0
	var right := along.cross(Vector3.UP)
	if _bow_side == 0.0:
		_bow_side = _side_with_rise(from, to, right)
	var rise := Vector3.UP * span * lift
	return rise + right * _bow_side * span * bow * end_on


# 1 when right, a direction on the orbit plane, bends the arc from from to to the same
# way on screen as rising off the plane does, so the two add up; else -1.
func _side_with_rise(from: Vector3, to: Vector3, right: Vector3) -> float:
	var middle := from.lerp(to, 0.5)
	var on_screen := camera.unproject_position(middle)
	var chord := camera.unproject_position(to) - camera.unproject_position(from)
	var across := Vector2(-chord.y, chord.x)
	var rise := camera.unproject_position(middle + Vector3.UP) - on_screen
	var side := camera.unproject_position(middle + right) - on_screen
	return 1.0 if across.dot(rise) * across.dot(side) >= 0.0 else -1.0


# The point t of the way along the arc: a parabola over the straight line from from to to,
# bulge off it at the middle.
func _point(from: Vector3, to: Vector3, bulge: Vector3, t: float) -> Vector3:
	return from.lerp(to, t) + bulge * (4.0 * t * (1.0 - t))


# Where the arc crosses gap_pixels past planet's edge on screen, searched for between
# inside, the end of the arc in the planet, and the middle. The middle when even that is
# no farther out, as when the two planets overlap on screen.
func _edge_t(
	from: Vector3, to: Vector3, bulge: Vector3, planet: Planet, gap_pixels: float, inside: float
) -> float:
	var center := planet.get_body_global_position()
	var on_screen := camera.unproject_position(center)
	var edge := camera.unproject_position(center + camera.global_basis.x * planet.get_body_radius())
	var reach := on_screen.distance_to(edge) + gap_pixels
	var outside := 0.5
	if camera.unproject_position(_point(from, to, bulge, outside)).distance_to(on_screen) <= reach:
		return outside
	for i: int in 20:
		var middle := (inside + outside) * 0.5
		var at := camera.unproject_position(_point(from, to, bulge, middle))
		if at.distance_to(on_screen) <= reach:
			inside = middle
		else:
			outside = middle
	return outside


func _vertex(point: Vector3, uv: Vector2, alpha: float) -> void:
	_mesh.surface_set_uv(uv)
	_mesh.surface_set_uv2(Vector2(alpha, 0.0))
	_mesh.surface_add_vertex(point)


func _set_widths(material: ShaderMaterial, half_line: float) -> void:
	material.set_shader_parameter(&"half_width", half_line)
	material.set_shader_parameter(&"outline", outline_pixels)


# Across the line at point, facing the camera: square to both the line and the view.
func _side(point: Vector3, tangent: Vector3) -> Vector3:
	var side := tangent.cross(camera.global_position - point)
	return side.normalized() if side.length_squared() > 1e-12 else camera.global_basis.x


# How wide pixels are in world units at point, seen through the camera.
func _pixels_to_world(pixels: float, point: Vector3) -> float:
	var depth := -(camera.global_transform.affine_inverse() * point).z
	var height := get_viewport().get_visible_rect().size.y
	return pixels * 2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5) / height


func _make_material(dashed: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	# After the route line and the orbits, which are see-through too.
	material.render_priority = 1
	material.set_shader_parameter(&"dashed", dashed)
	return material


static func _ease_out(t: float) -> float:
	var left := 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - left * left * left
