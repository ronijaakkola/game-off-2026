extends "res://styles/style_base.gd"
## The sharp-lines style with its lines as geometry: every mesh under [member lined]
## gets ribbons along its creases. Smooth meshes outside it keep the hull outline.

const LINE_MATERIAL := preload("res://styles/sharp_lines/crease_lines.tres")

## The node whose MeshInstance3D children get crease lines.
@onready var lined: Node3D = %Town


func _ready() -> void:
	for child in lined.get_children():
		var instance := child as MeshInstance3D
		if instance and instance.mesh:
			_add_lines(instance)


func _add_lines(instance: MeshInstance3D) -> void:
	var lines := MeshInstance3D.new()
	lines.mesh = CreaseLines.build_ribbons(CreaseLines.find_creases(instance.mesh))
	lines.material_override = LINE_MATERIAL
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.add_child(lines)
