class_name PassengerFigure
extends Node3D
## The small, soft human figure a passenger is out of the bus, in a star jump, arms and
## legs spread: the [KickedPassenger] thrown out of the door, and the [CastawayFigure]
## out of their capsule. All of it is one colour, lit as the planets are ([method paint]).

const SHADER := preload("res://shared/two_tone.gdshader")


## Paints the whole figure in [param color], lit from [param light_source] (global space).
func paint(color: Color, light_source: Vector3) -> void:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"color", color)
	material.set_shader_parameter(&"light_source", light_source)
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = material
