extends MeshInstance3D
## A temporary white ring round the bus, flat on the orbit plane, that fills clockwise as
## the frameshift drive charges. It draws in global space.

const SEGMENTS := 64

@export_range(0.05, 3.0, 0.01) var radius := 0.6
@export_range(0.01, 0.5, 0.005) var width := 0.06

var _mesh := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	mesh = _mesh
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color.WHITE
	material_override = material


## Shows the ring at [param center], filled to [param progress] (0 to 1). 0 hides it.
func show_progress(center: Vector3, progress: float) -> void:
	_mesh.clear_surfaces()
	global_transform = Transform3D(Basis.IDENTITY, Vector3(center.x, 0.0, center.z))
	var steps := ceili(SEGMENTS * clampf(progress, 0.0, 1.0))
	if steps == 0:
		return
	var inner := radius - width * 0.5
	var outer := radius + width * 0.5
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in steps + 1:
		# From the top of the screen (away from the camera), clockwise seen from above.
		var angle := TAU * progress * i / steps
		var direction := Vector3(sin(angle), 0.0, -cos(angle))
		_mesh.surface_add_vertex(direction * inner)
		_mesh.surface_add_vertex(direction * outer)
	_mesh.surface_end()
