class_name AlienEyeStyle
extends Resource
## How an alien's eyes are drawn: colours, outline, iris, pupil shape and shine. Sizes are
## fractions of the eye's radius.

@export var white_color := Color(0.97, 0.96, 1.0)
@export var iris_color := Color(0.95, 0.6, 0.2)
@export var pupil_color := Color(0.1, 0.08, 0.2)
@export var outline_color := Color(0.1, 0.08, 0.2)
## 0 for no outline.
@export_range(0.0, 0.4) var outline_width := 0.14
## 0 for no iris.
@export_range(0.0, 1.0) var iris_size := 0.0
## 0 for no pupil.
@export_range(0.0, 1.0) var pupil_size := 0.48
## Squashes the pupil: (0.3, 1.0) makes a slit.
@export var pupil_stretch := Vector2.ONE
@export_range(0.0, 0.5) var shine_size := 0.13
## Where the shine sits from the pupil's centre.
@export var shine_offset := Vector2(-0.2, 0.2)
## A second, smaller shine opposite the first. 0 for none.
@export_range(0.0, 0.3) var second_shine_size := 0.0
## How far the pupil moves from the middle at the most.
@export_range(0.0, 1.0) var look_range := 0.38


## Sets this style on an eye material made from `alien_eye.gdshader`.
func apply(material: ShaderMaterial) -> void:
	material.set_shader_parameter(&"white_color", white_color)
	material.set_shader_parameter(&"iris_color", iris_color)
	material.set_shader_parameter(&"pupil_color", pupil_color)
	material.set_shader_parameter(&"outline_color", outline_color)
	material.set_shader_parameter(&"outline_width", outline_width)
	material.set_shader_parameter(&"iris_size", iris_size)
	material.set_shader_parameter(&"pupil_size", pupil_size)
	material.set_shader_parameter(&"pupil_stretch", pupil_stretch)
	material.set_shader_parameter(&"shine_size", shine_size)
	material.set_shader_parameter(&"shine_offset", shine_offset)
	material.set_shader_parameter(&"second_shine_size", second_shine_size)
	material.set_shader_parameter(&"look_range", look_range)
