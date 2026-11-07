class_name ThrusterTrail
extends MeshInstance3D
## A flat ribbon left behind the bus's thrusters, level with the orbit plane. The bus moves
## its head every frame; each point fades out and narrows over [member lifetime] seconds.
## It draws in global space.

## Seconds a point of the trail takes to fade out.
@export_range(0.1, 10.0, 0.1) var lifetime := 2.5
## The trail's width where it leaves the thrusters.
@export_range(0.01, 1.0, 0.01) var width := 0.2
## How far the head moves before the trail keeps a new point.
@export_range(0.01, 1.0, 0.01) var spacing := 0.05
## The thrusters' glow, a little see-through.
@export var color := Color(0.6, 0.95, 1.0, 0.7)

var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
# Oldest first. Each point's age in seconds, and how hard the thrusters burned there, 0 to 1.
var _points := PackedVector3Array()
var _ages := PackedFloat32Array()
var _strengths := PackedFloat32Array()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = color
	# Draws once while SceneFlow's fade covers the screen, so the material compiles now
	# and not on the first flight.
	_draw_strip(
		PackedVector3Array([Vector3.ZERO, Vector3.FORWARD]),
		PackedFloat32Array([0.0, 0.0]),
		PackedFloat32Array([1.0, 1.0])
	)
	await get_tree().process_frame
	_mesh.clear_surfaces()


## Ages the trail by [param delta] and moves its head to [param at], where the thrusters
## burn at [param strength]: 0 leaves no trail, 1 the full one.
func advance(at: Vector3, strength: float, delta: float) -> void:
	for i: int in _ages.size():
		_ages[i] += delta
	while not _ages.is_empty() and _ages[0] >= lifetime:
		_points.remove_at(0)
		_ages.remove_at(0)
		_strengths.remove_at(0)
	# Keeps one point after the burn stops, so the trail ends where it did.
	var burning := strength > 0.0 or (not _strengths.is_empty() and _strengths[-1] > 0.0)
	if burning and (_points.is_empty() or _points[-1].distance_to(at) >= spacing):
		_points.append(at)
		_ages.append(0.0)
		_strengths.append(strength)
	var points := _points.duplicate()
	var ages := _ages.duplicate()
	var strengths := _strengths.duplicate()
	if not points.is_empty() and points[-1].distance_to(at) > 1e-4:
		points.append(at)
		ages.append(0.0)
		strengths.append(strength)
	_draw_strip(points, ages, strengths)


## Whether any of the trail is left to draw.
func is_empty() -> bool:
	return _mesh.get_surface_count() == 0


func _draw_strip(
	points: PackedVector3Array, ages: PackedFloat32Array, strengths: PackedFloat32Array
) -> void:
	_mesh.clear_surfaces()
	if points.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _material)
	for i: int in points.size():
		var along := points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
		var faded := clampf(ages[i] / lifetime, 0.0, 1.0)
		var half := width * 0.5 * strengths[i] * lerpf(1.0, 0.3, faded)
		var side := along.cross(Vector3.UP).normalized() * half
		_mesh.surface_set_color(Color(1.0, 1.0, 1.0, strengths[i] * (1.0 - faded)))
		_mesh.surface_add_vertex(points[i] - side)
		_mesh.surface_set_color(Color(1.0, 1.0, 1.0, strengths[i] * (1.0 - faded)))
		_mesh.surface_add_vertex(points[i] + side)
	_mesh.surface_end()
