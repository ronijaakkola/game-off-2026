extends "res://styles/style_base.gd"
## The sharp-lines style with its lines as geometry: every mesh under [member lined], and
## the base's building, gets ribbons along its creases. The sphere keeps the hull outline.

const LINE_MATERIAL := preload("res://styles/sharp_lines/crease_lines.tres")

## The node whose MeshInstance3D children get crease lines.
@onready var lined: Node3D = %Town
## The base's hard-edged model, lined like the town.
@onready var building: MeshInstance3D = %Cube


func _ready() -> void:
	_add_lines(building)
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
