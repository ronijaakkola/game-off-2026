class_name HopWindowArc
extends MeshInstance3D
## Where on a moon's orbit the hop location of a [WindowHopGoal] is open: a band along the
## stretch of the orbit inside the star's hot zone, in the hop zone's aqua, so the player
## watches the moon run toward it. It turns with the moon's planet to keep facing the star.
## Faint while the window is closed and bright while it is open; it fades in and out with
## the quest. The [FlybyZone] it belongs to shows it ([method show_window]).
## It stays visible and only fades, so the scene's first draw compiles its shader.

## How wide the band is, in units.
const WIDTH := 0.22
const SEGMENTS := 32
const FADE_SECONDS := 0.4
## How much of it shows while the window is closed.
const CLOSED_OPACITY := 0.5
## How fast it brightens as the window opens, and dims, per second.
const OPEN_EASE := 2.5

var _shown := 0.0
var _open := 0.0
# What the mesh was built for.
var _radius := 0.0
var _half := 0.0


func _ready() -> void:
	_build(1.0, 0.5)


## Shows the window of [param goal] as it is now, or fades out with none, [param delta]
## seconds on.
func show_window(goal: WindowHopGoal, delta: float) -> void:
	var orbits := goal.planet.get_parent() as Planet if goal else null
	_shown = move_toward(_shown, 1.0 if orbits else 0.0, delta / FADE_SECONDS)
	var material := material_override as ShaderMaterial
	if orbits:
		var center := orbits.get_body_global_position()
		var radius := RouteStop.flat(goal.get_spot() - center).length()
		var half := goal.get_window_half_angle()
		if not is_equal_approx(radius, _radius) or not is_equal_approx(half, _half):
			_build(radius, half)
		var to_star := goal.planet.star_system.global_position - center
		global_position = center
		global_rotation.y = atan2(-to_star.z, to_star.x)
		_open = move_toward(_open, 1.0 if goal.is_open() else 0.0, OPEN_EASE * delta)
	ShaderValues.show(material, &"opacity", _shown * lerpf(CLOSED_OPACITY, 1.0, _open))


# Builds the band [param radius] from the centre, [param half] radians to either side of
# the X axis.
func _build(radius: float, half: float) -> void:
	_radius = radius
	_half = half
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i: int in SEGMENTS + 1:
		var along := float(i) / SEGMENTS
		var angle := lerpf(-half, half, along)
		var direction := Vector3(cos(angle), 0.0, -sin(angle))
		vertices.append_array(
			[direction * (radius - WIDTH / 2.0), direction * (radius + WIDTH / 2.0)]
		)
		uvs.append_array([Vector2(0.0, along), Vector2(1.0, along)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var arc := ArrayMesh.new()
	arc.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	mesh = arc
	var lengths := 2.0 * half * radius / WIDTH
	ShaderValues.show(material_override as ShaderMaterial, &"lengths", lengths)
