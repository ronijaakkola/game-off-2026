class_name ShaderValues
## Sets a shader parameter only when its value changes, for a script that shows a value
## every frame. Each [method ShaderMaterial.set_shader_parameter] has Godot pack and send
## the material's every uniform to the graphics card again that frame, whether or not the
## value is new, and on the web each such send is a slow call out of the game. A value that
## holds still most frames, such as where the star is, then costs nothing.


## Sets [param parameter] of [param material] to [param value], unless it holds it already.
static func show(material: ShaderMaterial, parameter: StringName, value: Variant) -> void:
	var held: Variant = material.get_shader_parameter(parameter)
	if typeof(held) != typeof(value) or held != value:
		material.set_shader_parameter(parameter, value)
